# Configuration (Networking)

## Goal

This document is the canonical reference for networking-related configuration variables, which are read from the app's `Info.plist` at runtime (injected via Build Settings).

## Canonical Code

- `ecall/Core/Networking/Endpoints.swift` (reads variables)
- `ecall/Core/Networking/APIEndpoint.swift` (constructs URLs)
- `ecall/Core/Networking/APIClient.swift` (uses `APP_API_ID` / `APP_API_HASH`)

## Variables

### Environment

- **`ENVIRONMENT_NAME`**: `Dev`, `Staging`, or `Production`. Determines which set of URLs and keys to use.

### Infrastructure URLs

- **`API_BASE_URL`**: The base URL for the REST API (e.g., `https://api.example.com`).
- **`SOCKET_BASE_URL`**: The base URL for the STOMP WebSocket (e.g., `wss://api.example.com`).
- **`JANUS_SOCKET_URL`**: The full URL for the Janus WebSocket (e.g., `wss://api.example.com/janus`).

### Request Signing

- **`APP_API_ID`**: Used for the `X-Api-Id` request header.
- **`APP_API_HASH`**: The secret key used to generate the `X-Signature` HMAC header.

## Related Docs

- **Partner Configuration**: For a guide on how partners should set these variables, see `../../partner/partner-technical.md`.
- **API Client Behavior**: For details on how signing headers are used, see `./api-client.md`.
- **SSL Pinning**: For details on how these URLs are affected by SSL pinning, see `../security/ssl-pinning.md`.
