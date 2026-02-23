# Calls (Dev)

## Scope

This folder documents call flows and security for:

- 1-1 calls (audio/video)
- Group calls (audio/video)
- Join / Rejoin
- Key Rotation & Emergency Recovery (see `../security/key-rotation.md`)

It intentionally excludes Janus/WebRTC transport internals.

## Security Highlights

- Media encryption: AES-256-GCM
- Key agreement (preferred): P-256 (secp256r1) via Secure Enclave
- Fallback/legacy: RSA-2048 (RSA-OAEP-SHA256)
- Forward secrecy: periodic key rotation (host-based)
- Recovery: emergency key redistribution when decrypt fails (`request_aes_key` / `send_aes_key`)
- Transport security: SSL public-key pinning enforced (staging/production)

Canonical security docs:
- `../security/ssl-pinning.md`
- `../security/key-rotation.md`

## Call Docs (folder-based)

- 1-1 calls: `./one-to-one/one-to-one.md`
- Group calls: `./group-call.md`
- Join & Rejoin: `./join-rejoin.md`
- Call E2EE details: `./e2ee.md`

## Diagrams

- 1-1 flow: `./one-to-one/diagrams/one-to-one-flow.md`
- Group call flow: `./diagrams/group-call-flow.md`
- Join/Rejoin flow: `./diagrams/join-rejoin-flow.md`
- Key rotation overview: `./diagrams/key-rotation-overview.md`
- Emergency key redistribution: `./diagrams/emergency-key-redistribution.md`

## API Endpoints (code-aligned)

All call endpoints are under `/app/api/...`:

- Start: `/app/api/call/start`
- Join: `/app/api/call/{id}/join`
- Rejoin: `/app/api/call/{id}/rejoin`
- Request rejoin: `/app/api/call/{id}/request-rejoin`
- Invite: `/app/api/call/{id}/invite`
- End: `/app/api/call/end`
- Participants: `/app/api/call/{id}/participants`

(See `APIEndpoint.path` in codebase.)
