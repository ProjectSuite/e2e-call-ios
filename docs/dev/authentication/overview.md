# Authentication (Dev)

## Scope

This folder documents authentication and device registration flows for the iOS client:

- Email/Phone OTP login
- Apple login
- Token storage and refresh integration
- Device registration and public key upload

## Canonical Code

- API endpoints: `ecall/Core/Networking/APIEndpoint.swift` (paths under `/app/api/...`)
- Networking client: `ecall/Core/Networking/APIClient.swift`
- Token refresh: `ecall/Core/Networking/TokenRefreshManager.swift`
- Auth services:
  - `ecall/Modules/Authentication/Services/AuthService.swift`
  - (if present) `ecall/Modules/Authentication/ViewModels/AuthViewModel.swift`
- Key storage: `ecall/Core/Persistence/KeyStorage.swift`

## API Endpoints (code-aligned)

- Verify user: `POST /app/api/verify`
- Login: `POST /app/api/login`
- Verify login: `POST /app/api/verify-login`
- Resend OTP: `POST /app/api/resend-otp`
- Apple login: `POST /app/api/apple-login`
- Logout: `POST /app/api/logout`
- Refresh token: `POST /app/api/refresh-token`
- Register device: `POST /app/api/register_device`
- Public keys: `GET /app/api/user/publicKeys`
- Current user: `GET /app/api/user`
- Update user: `PUT /app/api/user`

## Security Notes

- Tokens are stored in Keychain.
- SSL public-key pinning is enforced in staging/production.
- The app uploads a public key per device; algorithm choice is client-side:
  - Preferred: P-256 (Secure Enclave)
  - Fallback/legacy: RSA-2048

Related canonical security docs:
- `../security/ssl-pinning.md`

Related canonical networking docs:
- `../networking/token-refresh.md`
- `../networking/api-client.md`

## Diagrams

- Authentication overview diagram: `./diagrams/authentication-flow.md`
- Token refresh diagram: `../networking/diagrams/token-refresh-flow.md`
