# API Client (Networking)

## Goal

Provide a single, consistent HTTP client for the app with:

- request signing headers
- SSL pinning
- retry/backoff for transient failures
- deterministic handling of `401` using backend error codes

## Canonical Code

- Client: `ecall/Core/Networking/APIClient.swift`
- Token refresh: `ecall/Core/Networking/TokenRefreshManager.swift`
- URL paths: `ecall/Core/Networking/APIEndpoint.swift` (see `path` values)

## SSL Pinning

`APIClient` uses a `URLSession` configured with `SSLPinningManager.shared` as delegate.

See: `../security/ssl-pinning.md`.

## Request Signing Headers

Every request applies a signature header set (in addition to Bearer auth when `auth=true`).

Implementation: `APIClient.applySecurityHeaders(to:)`.

Headers:

- `X-Api-Id`: from `AppEnvironment.current.appApiId`
- `X-Signature`: HMAC-SHA256 over `(appApiId + method + path + body + timestamp)`
- `X-Nonce`: unix timestamp

Notes:

- `path` is **URL path only** (`request.url?.path`), not full URL.
- `body` is the UTF-8 string of `httpBody` if present.

## Timeouts

`URLSessionConfiguration.default`:

- `timeoutIntervalForRequest`: 30s
- `timeoutIntervalForResource`: 60s
- `waitsForConnectivity`: true

## Retry / Backoff

Retries are applied for transient errors:

### Retryable HTTP status codes

`408`, `429`, `500`, `502`, `503`, `504`

### Retryable network errors

- `NSURLErrorTimedOut`
- `NSURLErrorCannotFindHost`
- `NSURLErrorCannotConnectToHost`
- `NSURLErrorNetworkConnectionLost`
- `NSURLErrorNotConnectedToInternet`
- `NSURLErrorDNSLookupFailed`

### Backoff strategy

- max attempts: 3
- delay: exponential (`1s`, `2s`, `4s` …) capped at `10s`

## 401 Handling (Refresh vs Logout)

When `auth=true`, `APIClient` treats 401 as a **state machine** based on the backend error code.

### Error codes (code-aligned)

- `ErrAccessTokenExpired` → refresh then retry once
- `ErrRefreshTokenExpired` → logout
- `ErrDeviceNotRegistered` → logout

### Behavior

1. On 401 (first time) and `ErrAccessTokenExpired`:
   - call `TokenRefreshManager.shared.refreshAccessToken()`
   - if refresh succeeds → retry the original request once
   - if refresh fails → logout

2. On 401 (first time) and `ErrRefreshTokenExpired` or `ErrDeviceNotRegistered`:
   - logout

3. On 401 after retry:
   - logout

See canonical refresh doc: `./token-refresh.md`.

## API Endpoints (selected)

Paths are defined in `APIEndpoint.path` and all app endpoints are under `/app/api/...`.

Examples:

- Refresh token: `/app/api/refresh-token`
- Logout: `/app/api/logout`
- Calls start: `/app/api/call/start`
