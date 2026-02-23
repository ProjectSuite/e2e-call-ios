# Emergency Key Redistribution (Call)

## Scope

This document describes the **emergency key redistribution** mechanism used when a participant cannot decrypt media packets.

- Triggered by **media decrypt failures** (typically audio bursts).
- Requests the **current AES session key** from the key-rotation host.

Diagrams already exist in this folder; this doc focuses on the code-level flow.

## Canonical Code

- Detect decrypt failure + request logic:
  - Video: `ecall/Modules/Call/Managers/CallEncryptionManager.swift`
  - Audio: `ecall/Core/Security/CustomAudioCrypto.swift`
- Host + participant signaling handlers:
  - `ecall/Modules/Call/Managers/CallSignalingHandler.swift`
- Signal types:
  - `ecall/Modules/Call/Managers/SignalingDelegate.swift`

## Trigger Condition

Implemented in `CallEncryptionManager.decryptCallDataThreadSafe(...)`.

The decrypt path attempts:

1. `sessionAESKey` (current)
2. `backupSessionAESKey` (previous)
3. `futureSessionAESKey` (next)

If all fail, it logs a critical error and calls:

- `requestKeyFromHostIfNeeded(reason: .mediaDecryptFailed)`

## Request Flow (Participant → Host)

### Preconditions

The participant will not send a request when:

- It is the host (`GroupCallSessionManager.shared.isKeyRotationHost == true`).
- A request is already in-flight (`isWaitingForKey == true`).
- Cooldown not passed (3 seconds).
- Duplicate signature within 1 second (dedupe across audio/video pipelines).

### Rate limiting & dedupe

- Cooldown: `keyRequestCooldown = 3s`
- Timeout: `keyResponseTimeout = 10s`
- Dedupe window: `keyRequestDedupeInterval = 1s`

### Target selection

- Host is resolved from participants list: first participant where `isHostKey == true`.

### Signal

Participant sends:

- `SignalMessage(type: .request_aes_key, participantId: host.userId, participantDeviceId: host.deviceId, callId: currentCallId, senderId: myUserId, senderDeviceId: myDeviceId)`

Sent via:

- `StompSignalingManager.shared.send(signal)`

## Response Flow (Host → Participant)

### Host handling

In `CallSignalingHandler.handleRequestAESKey(...)`:

1. Verify the receiver is host (`isKeyRotationHost`).
2. Read current key: `CallEncryptionManager.shared.sessionAESKey`.
3. Fetch requester public key.
4. Encrypt current key for requester using `GroupCallManager.encryptGroupKeyForParticipant(...)`.
5. Send `SignalMessage(type: .send_aes_key, encryptedAESKey: ..., participantId: requesterId, participantDeviceId: requesterDeviceId, callId: currentCallId)`.

### Participant handling

In `CallSignalingHandler.handleSendAESKey(...)`:

1. Verify message targets current user/device.
2. Decrypt `encryptedAESKey` via `GroupCallManager.decryptKeyRotationMessage(...)`.
3. Apply immediately: `CallEncryptionManager.setUpAesKey(newKey)`.
4. Mark request complete: `markKeyRequestComplete()`.

## Security Notes

- The host sends the **current** session key, encrypted for the requester.
- Public key type is decided by the requester public key (P-256 preferred; RSA fallback).
- Private keys never leave the device.

## Related Docs

- Key rotation (call folder): `../key-rotation/key-rotation.md`
- Global security key rotation reference: `../../security/key-rotation.md`
