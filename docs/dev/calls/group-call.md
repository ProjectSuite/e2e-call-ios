# Group Calls (Audio/Video)

## What this covers

- Creating a group call
- Inviting participants
- Joining as a participant
- How E2EE keys are distributed and rotated

## Canonical Code

- Orchestration: `ecall/Modules/Call/Managers/GroupCallManager.swift`
- Session state: `ecall/Modules/Call/Managers/GroupCallSessionManager.swift`
- Signaling: `ecall/Modules/Call/Managers/StompSignalingManager.swift` + `CallSignalingHandler.swift`
- Encryption: `ecall/Modules/Call/Managers/CallEncryptionManager.swift`

## API Endpoints (code-aligned)

- Start call: `POST /app/api/call/start`
- Invite: `POST /app/api/call/{id}/invite`
- Join: `POST /app/api/call/{id}/join`
- Participants: `GET /app/api/call/{id}/participants`
- End: `POST /app/api/call/end`

## Flow (high-level)

1. Caller starts a call with multiple callee IDs.
2. App fetches public keys for all participants.
3. App creates call via `POST /app/api/call/start`.
4. Backend relays invitations via STOMP.
5. Each participant decrypts the session key and joins.

## Security highlights

- Session key distribution uses participant public keys:
  - Preferred: P-256 ECDH via Secure Enclave
  - Fallback: RSA-2048 RSA-OAEP-SHA256
- Key rotation is host-based and runs periodically.
- Emergency key redistribution exists for decrypt failures.

See canonical:
- Key rotation: `../../security/key-rotation.md`
- E2EE: `../e2ee/e2ee.md`

## Diagram

- `./diagrams/group-call-flow.md`
