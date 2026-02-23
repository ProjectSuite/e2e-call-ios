# Diagram: Device Registration & Key Upload

> Canonical doc: `../overview.md`

## Flow

This flow happens during the first successful login on a new device.

```mermaid
flowchart LR
    subgraph KEYGEN["Key Generation (Client-side)"]
        SE[Secure Enclave] --> |Generate| PRIVKEY["P-256 Private Key<br/>(never exportable)"]
        PRIVKEY --> |Derive| PUBKEY["P-256 Public Key"]
    end

    subgraph PAYLOAD["Auth Request Payload"]
        CLIENT_DATA["Device Info<br/>(deviceName, systemName, etc.)"]
        PUSH_TOKENS["Push Tokens<br/>(voipToken, apnsToken)"]
        PUBKEY --> UPLOAD_KEY["publicKey (Base64)"]
    end

    subgraph API["Backend API"]
        LOGIN_REQ["API: /app/api/login<br/>or /app/api/apple-login"]
        REGISTER_REQ["API: /app/api/register_device"]
    end

    CLIENT_DATA --> LOGIN_REQ
    PUSH_TOKENS --> LOGIN_REQ
    UPLOAD_KEY --> LOGIN_REQ

    LOGIN_REQ --> REGISTER_REQ
```

## Security Notes

- The client decides which key type to generate (P-256 is preferred).
- The private key never leaves the device's Secure Enclave.
- The backend stores the public key provided by the client for use in E2EE calls.
- The API endpoint for registering the device is `/app/api/register_device`.
