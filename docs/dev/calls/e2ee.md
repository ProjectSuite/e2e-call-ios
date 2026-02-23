# Call E2EE

## Goal

Provide end-to-end encryption for call media such that:

- The backend cannot decrypt media.
- Key agreement prefers P-256 (Secure Enclave) but supports RSA-2048 fallback for legacy.
- Media is encrypted using AES-256-GCM.

## Canonical Code

- Core crypto orchestration: `ecall/Modules/Call/Managers/CallEncryptionManager.swift`
- P-256 Secure Enclave: `ecall/Core/Security/P256SecureEnclaveService.swift`
- Emergency key redistribution + rotation signals: `ecall/Modules/Call/Managers/CallSignalingHandler.swift`

## Key Agreement / Key Exchange

### Preferred: P-256 (secp256r1) ECDH via Secure Enclave

For 1-1 calls:

- Caller derives shared secret using ECDH (Secure Enclave private key + peer public key).
- The derived shared secret is used as the AES session key (`sessionAESKey`).

Entry points:

- `prepareCallInvitationP256(calleePublicKeyBase64:) -> String?` (returns caller public key)
- `processCallInvitationP256(callerPublicKeyBase64:) -> Bool`

### Fallback/Legacy: RSA-2048 (RSA-OAEP-SHA256)

For legacy participants:

- AES session key is generated randomly.
- AES session key is encrypted with RSA public key using OAEP-SHA256.

Entry points:

- `prepareCallInvitation(with calleePublicKey: SecKey) -> Data?`
- `processCallInvitation(encryptedAESKey:calleeRSAPrivateKey:) -> Data?`

## Media Encryption

- Encryption primitive: `AES.GCM`
- Call encryption manager applies the key via:
  - `setUpAesKey(_:)`

### Key Application Side Effects

`setUpAesKey(_:)` configures:

- **Video** encryption manager (`CRTEncryptionManager`) with deterministic IV derived from key hash.
- **Audio** encryption via `RTCAudioCryptoManager.shared().delegate` (updates existing delegate on rotation).

## Key Rotation & Recovery

Key rotation and emergency key redistribution are documented separately:

- `../security/key-rotation.md`

## Related Diagrams

- 1-1 call flow: `./diagrams/1v1-call-flow.md`
