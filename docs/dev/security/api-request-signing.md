# API Request Signing

## Goal

To ensure the authenticity and integrity of every API request, the client must sign each request with a secret key. The server then verifies this signature before processing the request. This prevents tampering and replay attacks.

## Canonical Code

- **Implementation**: `ecall/Core/Networking/APIClient.swift` in the `applySecurityHeaders(to:)` method.

## Credentials

Two main credentials are required for signing:

- **`APP_API_ID`**: A unique identifier for the partner application.
- **`APP_API_HASH`**: A secret key (HMAC key) used for generating the signature.

These credentials are provided to partners through the partner website and are configured in the app's build settings.

## HTTP Headers

Three custom headers are added to every API request:

| Header | Description |
| :--- | :--- |
| `X-Api-Id` | The `APP_API_ID`. |
| `X-Nonce` | A Unix timestamp representing the time of the request. Used to prevent replay attacks. |
| `X-Signature` | The HMAC-SHA256 signature of the request payload. |

## Signature Generation Process

The signature is generated as follows:

1.  **Construct the Raw String**: A raw string is created by concatenating the following components in order:
    ```
    appApiId + httpMethod + urlPath + requestBody + timestamp
    ```
    - `httpMethod`: e.g., `GET`, `POST`.
    - `urlPath`: The path of the URL only (e.g., `/app/api/call/start`), not the full URL.
    - `requestBody`: The raw string of the HTTP body. If there is no body, this is an empty string.
    - `timestamp`: The value sent in the `X-Nonce` header.

2.  **Generate the HMAC Signature**: The raw string is then signed using HMAC-SHA256 with the `APP_API_HASH` as the secret key.

    ```swift
    let signature = rawString.hmacSHA256(key: appApiHash)
    ```

3.  **Set the Header**: The resulting signature is placed in the `X-Signature` header.

## Related Docs

- **[API Client Overview](../networking/api-client.md)**
- **[Configuration Variables](../networking/configuration.md)**
