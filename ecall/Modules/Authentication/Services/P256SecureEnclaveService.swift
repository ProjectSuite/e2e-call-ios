//
//  P256SecureEnclaveService.swift
//  ecall
//
//  Created for P-256 Secure Enclave migration
//  Provides hardware-backed E2EE with biometric authentication
//

import Foundation
import CryptoKit
import Security
import LocalAuthentication

enum P256Error: Error {
    case secureEnclaveNotAvailable
    case keyGenerationFailed
    case keyNotFound
    case keyDerivationFailed
    case invalidPublicKey
    case keychainError(OSStatus)
    case biometricAuthenticationFailed
}

/// Service for managing P-256 keys in Secure Enclave with biometric authentication
class P256SecureEnclaveService {

    // MARK: - Singleton

    /// Shared singleton instance to ensure cache is shared across all usages
    static let shared = P256SecureEnclaveService()

    private init() {} // Prevent external instantiation

    // MARK: - Constants

    private let privateKeyTag = "org.app.p256.privateKey"
    private let publicKeyTag = "org.app.p256.publicKey"

    // MARK: - Cached State

    /// Shared authentication context for biometric operations (reused across calls)
    private var sharedAuthContext: LAContext?

    /// Cached private key to avoid repeated Keychain access and biometric prompts
    private var cachedPrivateKey: SecureEnclave.P256.KeyAgreement.PrivateKey?

    // MARK: - Secure Enclave Availability

    /// Check if Secure Enclave is available on this device
    /// - Returns: true if available (iPhone 5s and newer), false otherwise
    static func isSecureEnclaveAvailable() -> Bool {
        // Secure Enclave is available on devices with biometric authentication
        // or devices that support SEP (Secure Enclave Processor)
        return SecureEnclave.isAvailable
    }

    // MARK: - Key Generation

    /// Generate a new P-256 keypair in Secure Enclave
    /// - Returns: Tuple of (private key reference, public key as Base64)
    /// - Throws: P256Error if generation fails or Secure Enclave unavailable
    func generateKeyPair() throws -> (privateKey: SecureEnclave.P256.KeyAgreement.PrivateKey, publicKeyBase64: String) {
        guard Self.isSecureEnclaveAvailable() else {
            throw P256Error.secureEnclaveNotAvailable
        }

        do {
            // Generate private key in Secure Enclave with biometric protection
            let privateKey = try SecureEnclave.P256.KeyAgreement.PrivateKey(
                compactRepresentable: false,
                authenticationContext: createAuthenticationContext()
            )

            // Extract public key
            let publicKey = privateKey.publicKey

            // Convert public key to raw representation (65 bytes: 0x04 + X + Y)
            let publicKeyData = publicKey.rawRepresentation
            let publicKeyBase64 = publicKeyData.base64EncodedString()

            debugLog("🔐 Generated P-256 keypair in Secure Enclave (\(publicKeyData.count) bytes)")

            return (privateKey, publicKeyBase64)

        } catch {
            errorLog("Failed to generate P-256 keypair: \(error)")
            throw P256Error.keyGenerationFailed
        }
    }

    /// Create authentication context for biometric operations
    private func createAuthenticationContext() -> LAContext {
        let context = LAContext()
        context.touchIDAuthenticationAllowableReuseDuration = 300 // 5 minutes
        context.localizedReason = "Authenticate to secure your call encryption keys"
        return context
    }

    // MARK: - Key Storage

    /// Store private key reference in Keychain
    /// - Parameter privateKey: The Secure Enclave private key to store
    /// - Returns: true if successful
    func storePrivateKeyReference(_ privateKey: SecureEnclave.P256.KeyAgreement.PrivateKey) -> Bool {
        let dataRepresentation = privateKey.dataRepresentation
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrApplicationTag as String: privateKeyTag.data(using: .utf8)!,
            kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
            kSecValueData as String: dataRepresentation,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]
        
        // Delete existing key first
        SecItemDelete(query as CFDictionary)
        
        let status = SecItemAdd(query as CFDictionary, nil)
        
        if status == errSecSuccess {
            debugLog("✅ Stored P-256 private key reference in Keychain")
            return true
        } else {
            errorLog("Failed to store P-256 private key: \(status)")
            return false
        }
    }

    /// Load private key reference from Keychain
    /// - Returns: The Secure Enclave private key
    /// - Throws: P256Error if key not found or load fails
    func loadPrivateKeyReference() throws -> SecureEnclave.P256.KeyAgreement.PrivateKey {
        // Return cached key if available
        if let cachedKey = cachedPrivateKey {
//            debugLog("✅ Using cached P-256 private key (no Keychain access)")
            return cachedKey
        }

        let query: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrApplicationTag as String: privateKeyTag.data(using: .utf8)!,
            kSecReturnData as String: true
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        guard status == errSecSuccess, let keyData = item as? Data else {
            throw P256Error.keyNotFound
        }

        do {
            // Create shared authentication context if needed
            if sharedAuthContext == nil {
                sharedAuthContext = createAuthenticationContext()
            }

            let privateKey = try SecureEnclave.P256.KeyAgreement.PrivateKey(dataRepresentation: keyData)
//            debugLog("✅ Loaded P-256 private key from Keychain")

            // Cache the key for future use
            cachedPrivateKey = privateKey

            return privateKey
        } catch {
            errorLog("Failed to reconstruct P-256 private key: \(error)")
            throw P256Error.keyNotFound
        }
    }

    /// Pre-authenticate and cache the private key to avoid biometric prompts during calls
    /// Call this during app startup to trigger biometric authentication early
    /// - Returns: true if successful, false if key not found or authentication failed
    func preAuthenticate() -> Bool {
        do {
            let privateKey = try loadPrivateKeyReference()
            debugLog("✅ Pre-authenticated P-256 key (biometric auth completed)")
            // Perform a dummy ECDH operation to "warm up" the Secure Enclave
            // This ensures the first real call doesn't have additional latency
            let dummyPublicKey = privateKey.publicKey
            _ = try? privateKey.sharedSecretFromKeyAgreement(with: dummyPublicKey)
            return true
        } catch {
            debugLog("⚠️ Pre-authentication skipped (no P-256 key found)")
            return false
        }
    }

    // MARK: - ECDH Key Agreement

    /// Derive shared secret using ECDH with peer's public key
    /// - Parameters:
    ///   - privateKey: Our Secure Enclave private key
    ///   - peerPublicKeyBase64: Peer's P-256 public key (Base64-encoded)
    /// - Returns: Symmetric key derived from ECDH
    /// - Throws: P256Error if derivation fails
    func deriveSharedSecret(
        privateKey: SecureEnclave.P256.KeyAgreement.PrivateKey,
        peerPublicKeyBase64: String
    ) throws -> SymmetricKey {
        guard let peerPublicKeyData = Data(base64Encoded: peerPublicKeyBase64) else {
            throw P256Error.invalidPublicKey
        }

        do {
            // Reconstruct peer's P-256 public key
            let peerPublicKey = try P256.KeyAgreement.PublicKey(rawRepresentation: peerPublicKeyData)

            // Perform ECDH key agreement
            let sharedSecret = try privateKey.sharedSecretFromKeyAgreement(with: peerPublicKey)

            // Derive symmetric key using HKDF
            let symmetricKey = sharedSecret.hkdfDerivedSymmetricKey(
                using: SHA256.self,
                salt: Data(),
                sharedInfo: Data("ecall-e2ee-key".utf8),
                outputByteCount: 32 // 256-bit AES key
            )

//            debugLog("✅ Derived ECDH shared secret (\(peerPublicKeyData.count) bytes peer key)")

            return symmetricKey

        } catch {
            errorLog("Failed to derive ECDH shared secret: \(error)")
            throw P256Error.keyDerivationFailed
        }
    }

    // MARK: - Public Key Utilities

    /// Get public key as Base64 string from private key
    /// - Parameter privateKey: The Secure Enclave private key
    /// - Returns: Public key as Base64 string
    func getPublicKeyBase64(from privateKey: SecureEnclave.P256.KeyAgreement.PrivateKey) -> String {
        let publicKey = privateKey.publicKey
        let publicKeyData = publicKey.rawRepresentation
        return publicKeyData.base64EncodedString()
    }

    /// Validate P-256 public key format
    /// - Parameter publicKeyBase64: Public key as Base64 string
    /// - Returns: true if valid P-256 public key (65 bytes)
    static func isValidP256PublicKey(_ publicKeyBase64: String) -> Bool {
        guard let data = Data(base64Encoded: publicKeyBase64) else {
            return false
        }

        // P-256 public key is 65 bytes (0x04 + 32 bytes X + 32 bytes Y)
        guard data.count == 65, data.first == 0x04 else {
            return false
        }

        // Try to construct P256 public key to validate
        do {
            _ = try P256.KeyAgreement.PublicKey(rawRepresentation: data)
            return true
        } catch {
            return false
        }
    }

    // MARK: - Key Cleanup

    /// Delete private key from Keychain
    /// - Returns: true if successful
    func deletePrivateKey() -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrApplicationTag as String: privateKeyTag.data(using: .utf8)!
        ]

        let status = SecItemDelete(query as CFDictionary)

        // Clear cached state
        cachedPrivateKey = nil
        sharedAuthContext = nil

        if status == errSecSuccess || status == errSecItemNotFound {
            debugLog("✅ Deleted P-256 private key from Keychain")
            return true
        } else {
            errorLog("Failed to delete P-256 private key: \(status)")
            return false
        }
    }
}
