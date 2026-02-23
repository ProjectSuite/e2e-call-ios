# Security Policy

## Supported Versions

We provide security updates for the following versions:

| Version | Supported          |
| ------- | ------------------ |
| 1.x.x   | :white_check_mark: |
| < 1.0   | :x:                |

## Reporting a Vulnerability

**IMPORTANT**: Please do **NOT** report security vulnerabilities publicly via GitHub Issues.

### How to Report

If you discover a security vulnerability, please report it privately:

1. **Email**: security@ecall.example.com
2. **Subject**: `[SECURITY] Brief description of vulnerability`
3. **Include**:
   - Description of the vulnerability
   - Steps to reproduce
   - Potential impact
   - Suggested fix (if any)
   - Your contact information

### What to Report

Please report:
- E2EE implementation flaws
- Key management vulnerabilities
- Authentication bypasses
- Data leakage
- Injection vulnerabilities
- Cryptographic weaknesses
- Any issue that could compromise user privacy or security

### Response Timeline

- **Initial Response**: Within 48 hours
- **Status Update**: Within 7 days
- **Resolution**: Depends on severity, typically 30-90 days

We will:
1. Acknowledge receipt of your report
2. Investigate the vulnerability
3. Work with you to address the issue
4. Release a fix and security advisory
5. Credit you (if desired) in the advisory

### Disclosure Policy

- We follow responsible disclosure practices
- Vulnerabilities will be disclosed after a fix is available
- We will coordinate with you on disclosure timing
- Public disclosure should wait until after the fix is released

## Security Best Practices

### For Contributors

When contributing code:

1. **Never commit secrets or credentials**
   - Use environment variables or configuration files
   - Add secrets to `.gitignore`
   - Use secure storage (Keychain) for sensitive data

2. **Follow E2EE guidelines**
   - Use approved cryptographic algorithms
   - Store keys securely in Keychain
   - Never log sensitive data
   - Validate all cryptographic operations

3. **Secure coding practices**
   - Validate all inputs
   - Handle errors securely
   - Use parameterized queries (if applicable)
   - Follow principle of least privilege

4. **Review security implications**
   - Consider impact on E2EE
   - Review key management changes
   - Test security-critical code thoroughly

### For Partners

When building custom applications:

1. **Protect API credentials**
   - Never commit `APP_API_ID` or `APP_API_HASH` to public repos
   - Use build settings or secure configuration files
   - Rotate credentials if compromised

2. **Secure distribution**
   - Use proper code signing
   - Enable certificate pinning in production
   - Follow App Store security guidelines

3. **Key management**
   - Never share private keys
   - Use secure key storage
   - Implement proper key rotation

## Security Features

### End-to-End Encryption

- **Key Exchange**: P-256 (secp256r1) ECDH via Secure Enclave (preferred), with RSA-2048 (RSA-OAEP-SHA256) supported as fallback/legacy
- **Media Encryption**: AES-256-GCM
- **Key Storage**: iOS Keychain with `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly` (Secure Enclave-backed private key for P-256)
- **No Server Access**: Server cannot decrypt media data

### Secure Storage

- Private keys stored in Keychain
- Access tokens stored securely
- No sensitive data in UserDefaults
- Proper key cleanup on logout

### Network Security

- HTTPS for all API calls
- Certificate pinning (recommended for production)
- Secure WebSocket connections (WSS)
- TURN/STUN server security

## Known Security Considerations

### Multi-Device Support

- Each device registers a public key for E2EE (P-256 preferred; RSA-2048 supported as fallback/legacy)
- AES keys encrypted per device
- Current limitation: Keys cannot be shared between devices

### Key Recovery

- Recovery keys encrypted with user password
- Keys stored locally, not on server
- No key escrow or backdoor access

### Call Rejoin

- AES keys shared securely via STOMP
- Encrypted with requester's RSA public key
- Only active participants can share keys

## Security Updates

We regularly:
- Update dependencies for security patches
- Review and audit code
- Monitor for security advisories
- Test for vulnerabilities
- Update security documentation

## Security Resources

- [Authentication Overview](../../dev/authentication/overview.md)
- [Call E2EE Security](../../dev/calls/e2ee.md)
- [SSL Pinning](../../dev/security/ssl-pinning.md)
- [Partner Security Guide](../partner-technical.md#security)

## Contact

For security-related questions (non-vulnerabilities):
- **Email**: security@ecall.example.com
- **Response Time**: Within 5 business days

Thank you for helping keep ECall iOS secure! 🔒

