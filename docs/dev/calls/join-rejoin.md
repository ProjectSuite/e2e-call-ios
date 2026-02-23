# Join & Rejoin

## What this covers

- Joining an active call (initial join)
- Rejoin flow (reconnect after app restart / disconnect)

## API Endpoints (code-aligned)

- Join: `POST /app/api/call/{id}/join`
- Request rejoin: `POST /app/api/call/{id}/request-rejoin`
- Rejoin: `POST /app/api/call/{id}/rejoin`
- Participants: `GET /app/api/call/{id}/participants`

## Canonical Code

- Session manager: `ecall/Modules/Call/Managers/GroupCallSessionManager.swift`
- Signaling handler: `ecall/Modules/Call/Managers/CallSignalingHandler.swift`
  - `handleParticipantRequestRejoin(_:)`
  - `handleParticipantAcceptRejoin(_:)`
- Encryption: `ecall/Modules/Call/Managers/CallEncryptionManager.swift`

## Rejoin Flow (high-level)

1. User taps Rejoin.
2. Client sends `POST /app/api/call/{callId}/request-rejoin`.
3. Backend broadcasts `participant_request_rejoin` to active participants via STOMP.
4. An active participant:
   - fetches requester's public key
   - encrypts the current AES key for the requester
   - sends `participant_accept_rejoin` with `encryptedAESKey`
5. Rejoining device:
   - receives `participant_accept_rejoin`
   - decrypts AES key
   - calls `POST /app/api/call/{callId}/rejoin`

## Security notes

- AES key is encrypted using the requester's public key (P-256 preferred#59; RSA fallback).
- Private keys never leave the device.

## Diagram

- `./diagrams/join-rejoin-flow.md`
