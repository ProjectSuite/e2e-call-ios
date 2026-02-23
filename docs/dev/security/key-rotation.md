# Key Rotation & Emergency Key Redistribution

## Goal

- Provide **forward secrecy** by rotating the group AES key periodically.
- Maintain call continuity with a **3-key decryption strategy**.
- Recover from media decrypt failures (commonly audio bursts) via **Emergency Key Redistribution**.

## Canonical Code

- Key storage + decrypt fallback + key request logic:
  - `ecall/Modules/Call/Managers/CallEncryptionManager.swift`
- Signaling handlers:
  - `ecall/Modules/Call/Managers/CallSignalingHandler.swift`
  - `ecall/Modules/Call/Managers/SignalingDelegate.swift` (signal types)
- Host orchestration:
  - `ecall/Modules/Call/Managers/GroupCallManager.swift`
  - `ecall/Modules/Call/Managers/GroupCallSessionManager.swift`

## Key Model (Three-key System)

The encryption layer maintains three keys to tolerate jitter/out-of-order packets during rotation:

| Key | Purpose | Retention |
|-----|---------|----------|
| `sessionAESKey` | Current key | Until next rotation |
| `backupSessionAESKey` | Previous key (late packets) | 120s |
| `futureSessionAESKey` | Next key (early packets) | 60s |

### Audio Path (CustomAudioCrypto)

The audio encryption layer (`CustomAudioCrypto`) mirrors the three-key system:

| Key | Purpose | Retention |
|-----|---------|-----------|
| `key` | Current key | Until next rotation |
| `backupKey` | Previous key (late packets) | 30s |
| `futureKey` | Next key (early packets) | 60s |

**Sync mechanism:** `CallEncryptionManager.setFutureSessionKey()` and `setUpAesKey()` automatically sync keys to `CustomAudioCrypto`.

**Canonical code:** `ecall/Core/Security/CustomAudioCrypto.swift`

### Thread Safety

- Keys are read/written via a concurrent queue with barrier writes (`keyQueue`).
- Video decode runs on background threads; rotation happens on main thread.
- Audio decrypt runs on WebRTC callback thread.

## Scheduled Rotation (Host)

High-level:

1. Host generates a new random AES key.
2. Host encrypts the new key for each participant based on that participant public key:
   - **Preferred**: P-256 (secp256r1) ECDH via Secure Enclave → AES-GCM wrap
   - **Fallback/legacy**: RSA-2048 RSA-OAEP-SHA256
3. Host sends `.key_rotation` via STOMP with:
   - `encryptedAESKey`
   - `keyRotationTimestamp`
4. Participants decrypt the new key and schedule application at the timestamp.

API endpoints involved in call lifecycle (code-aligned):
- Start call: `/app/api/call/start`
- Join: `/app/api/call/{id}/join`

## Decrypt Fallback Strategy (Current → Backup → Future)

For each incoming encrypted packet, `CallEncryptionManager.decryptCallMediaData(...)` reads all keys atomically and calls `decryptCallDataThreadSafe(...)`:

1. Try `sessionAESKey`
2. If fail, try `backupSessionAESKey`
3. If fail, try `futureSessionAESKey`

If all fail → triggers Emergency Key Redistribution.

## Emergency Key Redistribution (Decrypt Media Fail)

### Trigger

Triggered when AES-GCM open fails with **current**, **backup**, and **future** keys.

Implementation point:
- `CallEncryptionManager.decryptCallDataThreadSafe(...)` → `requestKeyFromHostIfNeeded(reason: .mediaDecryptFailed)`

### Reasons + Dedupe

`CallEncryptionManager.KeyRequestReason`:
- `mediaDecryptFailed`
- `audioDecryptFailed`

To avoid spamming the host when audio/video pipelines fail together:
- Dedupe window: 1s (`keyRequestDedupeInterval`)

### Rate Limiting

- Cooldown: 3s (`keyRequestCooldown`)
- Timeout waiting for response: 10s (`keyResponseTimeout`)
- If current device is host (`isKeyRotationHost`) → do not request.

### Signals (Code-aligned)

Participant → Host:
- `type: .request_aes_key`
- Contains:
  - `participantId` / `participantDeviceId` (target host)
  - `senderId` / `senderDeviceId` (requester)
  - `callId`

Host → Participant:
- `type: .send_aes_key`
- Contains:
  - `participantId` / `participantDeviceId` (target requester)
  - `encryptedAESKey`
  - `callId`

### Host Behavior

Handled in `CallSignalingHandler.handleRequestAESKey(...)`:

1. Ensure current user is key-rotation host.
2. Fetch requester public key.
3. Encrypt **current** `sessionAESKey` for requester.
4. Send `.send_aes_key`.

### Participant Behavior

Handled in `CallSignalingHandler.handleSendAESKey(...)`:

1. Verify message is for current user/device.
2. Decrypt `encryptedAESKey`.
3. Apply immediately: `CallEncryptionManager.setUpAesKey(newKey)`.
4. Mark request complete: `markKeyRequestComplete()`.

## Related Diagrams

- Security diagrams will be migrated to: `docs/dev/security/diagrams/*`.

## Related Docs

- Calls E2EE: `../calls/e2ee.md`
- Calls signaling: `../calls/signaling.md`
