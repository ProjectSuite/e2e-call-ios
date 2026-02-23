# Token Refresh & Session Management

## Goal

Maintain a secure and seamless session using a two-token system:

- **Access token**: short-lived, used in `Authorization: Bearer ...`
- **Refresh token**: long-lived, used only to obtain new tokens

## Canonical Code

- Refresh orchestration (thread-safe): `ecall/Core/Networking/TokenRefreshManager.swift`
- 401 handling + retry: `ecall/Core/Networking/APIClient.swift`
- Storage: `ecall/Core/Persistence/KeyStorage.swift`
- Endpoint paths: `ecall/Core/Networking/APIEndpoint.swift`

## Endpoint

- Refresh endpoint: `POST /app/api/refresh-token`
- Request body:

```json
{ "refreshToken": "..." }
```

## Thread Safety (Single Refresh In-Flight)

`TokenRefreshManager` uses a Swift `actor` (`TokenRefreshState`) to ensure:

- only one refresh call is in progress at a time (`isRefreshing`)
- concurrent refresh requests wait in a queue (`refreshQueue`)

Behavior:

1. First request sets `isRefreshing=true` and performs the refresh call.
2. Subsequent requests while refreshing are queued.
3. When refresh completes, all queued continuations are resumed with the same result.

## Refresh Flow

### Trigger points

#### A) Reactive refresh (on 401)

In `APIClient`, when an authenticated request returns `401`:

- Parse structured error code:
  - `ErrAccessTokenExpired` → refresh
  - `ErrRefreshTokenExpired` → logout
  - `ErrDeviceNotRegistered` → logout

If `ErrAccessTokenExpired`:

- `TokenRefreshManager.shared.refreshAccessToken()`
- On success → retry the original request **once**
- On failure → logout

See also: `./api-client.md`.

#### B) Proactive refresh (app lifecycle)

The app refreshes tokens proactively when returning to foreground (implemented in `RootView.swift` in the current codebase).

## Failure Handling

### Missing refresh token

If no refresh token exists in Keychain:

- refresh fails with `.unauthorized`
- app logs out via `AppState.shared.logout(remotely: false)`

### Refresh request fails

If refresh fails (network/server/invalid token):

- `TokenRefreshManager` finishes and releases queued waiters
- caller (`APIClient`) logs out if needed

## Logout Conditions

The app forces logout when:

- server returns `401` with `ErrRefreshTokenExpired`
- server returns `401` with `ErrDeviceNotRegistered`
- refresh retry still fails with `401`
- refresh token is missing locally

## Related Docs

- API client 401 behavior: `./api-client.md`
- SSL pinning: `../security/ssl-pinning.md`
