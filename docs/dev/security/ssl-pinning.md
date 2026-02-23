# SSL Public Key Pinning

## Goal

Prevent MITM attacks by validating the server TLS certificate chain against **pinned public key hashes**.

This project implements **public-key pinning (SHA-256)** via `SSLPinningManager`.

## Canonical Code

- Pinning implementation: `ecall/Core/Security/SSLPinningManager.swift`
- REST API client uses pinning delegate: `ecall/Core/Networking/APIClient.swift`
- Janus WS client uses pinning delegate: `ecall/Modules/Call/Managers/JanusSocketClient.swift`
- STOMP client forwards challenges to pinning manager: `ecall/Modules/Call/Managers/STOMPClient.swift`

## Where Pinning is Applied

| Channel | How it is pinned | Notes |
|--------|-------------------|-------|
| **REST API** | `URLSession(delegate: SSLPinningManager.shared)` | Used by `APIClient` |
| **STOMP (WSS)** | `STOMPClient` implements `urlSession(_:didReceive:...)` and forwards to `SSLPinningManager` | Signaling channel |
| **Janus (WSS)** | `JanusSocketClient` uses `URLSession(delegate: SSLPinningManager.shared)` | Media signaling channel |

## Environment Behavior

Pinning behavior is environment-dependent:

- **Dev**: pinning disabled (`pinnedHashes` returns empty; challenge accepts trust).
- **Staging/Production**: pinning enforced using hardcoded SHA-256 public key hashes.

## Service-Specific Pins

`SSLPinningManager` maintains separate pin sets for:

- `api` (REST HTTPS)
- `socket` (STOMP WSS)
- `janus` (Janus WSS)

At runtime, it builds a mapping from **hostname → allowed hashes** by extracting hostnames from:

- `Endpoints.shared.baseURL`
- `Endpoints.shared.baseSocketURL`
- `Endpoints.shared.baseJanusSocketURL`

## Validation Strategy

- Extract hostname from `URLAuthenticationChallenge`.
- Fetch the expected pinned hashes for that hostname.
- Read certificate chain (`SecTrustCopyCertificateChain`) and iterate up to the first 3 certificates.
- For each cert:
  - Extract `SecKey` public key
  - Export as bytes (`SecKeyCopyExternalRepresentation`)
  - Compute SHA-256 and compare with pinned hash set

If no match is found, the request is cancelled.

## Operational Notes (Certificate Rotation)

- Pin values are hardcoded; certificate rotation requires updating the hash lists in `SSLPinningManager`.
- Multiple hashes per service are supported to allow safe rotation windows.

## Related Docs

- Networking API client behavior: `../networking/api-client.md`
