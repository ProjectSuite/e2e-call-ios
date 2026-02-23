import Foundation
import CryptoKit
import CommonCrypto

struct KeyPackage: Codable {
    let publicKey: String
    let privateKey: String
}

class AESEncryption {
    static let shared = AESEncryption()
    
    // MARK: - Constants for PBKDF2
    private let pbkdf2Iterations: UInt32 = 100_000 // Recommended minimum: 100,000 iterations
    private let saltLength = 32 // 32 bytes (256 bits) salt
    private let keyLength = 32 // 32 bytes (256 bits) for AES-256
    
    // Version marker for encrypted data format
    // Format: [VERSION_MARKER: 1 byte][SALT: 32 bytes][SEALED_BOX: variable]
    private let versionMarker: UInt8 = 0x01 // Version 1 = PBKDF2, Version 0 = legacy SHA256

    // MARK: - Secure Key Derivation using PBKDF2
    
    /// Derive a symmetric key from password using PBKDF2 with salt and iterations
    private func deriveKey(from password: String, salt: Data) -> SymmetricKey? {
        guard salt.count == saltLength else {
            errorLog("Invalid salt length: expected \(saltLength), got \(salt.count)")
            return nil
        }
        
        let passwordData = Data(password.utf8)
        var derivedKey = [UInt8](repeating: 0, count: keyLength)
        
        let status = passwordData.withUnsafeBytes { passwordBytes -> Int32 in
            return salt.withUnsafeBytes { saltBytes -> Int32 in
                guard let passwordPtr = passwordBytes.baseAddress?.assumingMemoryBound(to: Int8.self),
                      let saltPtr = saltBytes.baseAddress?.assumingMemoryBound(to: UInt8.self) else {
                    return Int32(kCCParamError)
                }
                
                return CCKeyDerivationPBKDF(
                    CCPBKDFAlgorithm(kCCPBKDF2),
                    passwordPtr,
                    passwordData.count,
                    saltPtr,
                    salt.count,
                    CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256),
                    pbkdf2Iterations,
                    &derivedKey,
                    keyLength
                )
            }
        }
        
        guard status == kCCSuccess else {
            errorLog("PBKDF2 key derivation failed with status: \(status)")
            return nil
        }
        
        return SymmetricKey(data: Data(derivedKey))
    }
    
    /// Legacy key derivation (SHA256 only) - for backward compatibility
    private func deriveKeyLegacy(from password: String) -> SymmetricKey {
        let passwordData = Data(password.utf8)
        let hashedPassword = SHA256.hash(data: passwordData)
        return SymmetricKey(data: hashedPassword)
    }

    // MARK: - Encryption
    
    /// Encrypts the key package using AES-GCM with a symmetric key derived from the password via PBKDF2
    func encryptKeys(publicKey: String, privateKey: String, password: String) -> Data? {
        let keyPackage = KeyPackage(publicKey: publicKey, privateKey: privateKey)

        // Encode the package to JSON
        guard let plainData = try? JSONEncoder().encode(keyPackage) else {
            errorLog("Failed to encode key package to JSON")
            return nil
        }

        // Generate random salt for this encryption
        var salt = Data(count: saltLength)
        let saltResult = salt.withUnsafeMutableBytes { bytes in
            guard let baseAddress = bytes.baseAddress else {
                return errSecAllocate
            }
            return SecRandomCopyBytes(kSecRandomDefault, saltLength, baseAddress)
        }
        
        guard saltResult == errSecSuccess else {
            errorLog("Failed to generate random salt")
            return nil
        }

        // Derive symmetric key using PBKDF2
        guard let symmetricKey = deriveKey(from: password, salt: salt) else {
            errorLog("Failed to derive symmetric key using PBKDF2")
            return nil
        }

        do {
            let sealedBox = try AES.GCM.seal(plainData, using: symmetricKey)
            guard let combined = sealedBox.combined else {
                errorLog("Failed to get sealed box combined data")
                return nil
            }
            
            // Format: [VERSION_MARKER][SALT][SEALED_BOX]
            var encryptedData = Data([versionMarker])
            encryptedData.append(salt)
            encryptedData.append(combined)
            
            return encryptedData
        } catch {
            errorLog("Encryption error: \(error)")
            return nil
        }
    }

    // MARK: - Decryption
    
    /// Decrypts the data and returns the original key package.
    /// Supports both new PBKDF2 format and legacy SHA256 format for backward compatibility.
    func decryptKeys(encryptedData: Data, password: String) -> KeyPackage? {
        guard encryptedData.count > 1 else {
            errorLog("Invalid encrypted data: too short")
            return nil
        }
        
        let version = encryptedData[0]
        let dataWithoutVersion = encryptedData.dropFirst()
        
        if version == versionMarker {
            // New format: PBKDF2 with salt
            return decryptKeysPBKDF2(encryptedData: dataWithoutVersion, password: password)
        } else {
            // Legacy format: SHA256 only (backward compatibility)
            return decryptKeysLegacy(encryptedData: encryptedData, password: password)
        }
    }
    
    /// Decrypt using PBKDF2 format: [SALT: 32 bytes][SEALED_BOX: variable]
    private func decryptKeysPBKDF2(encryptedData: Data, password: String) -> KeyPackage? {
        guard encryptedData.count > saltLength else {
            errorLog("Invalid PBKDF2 encrypted data: too short for salt")
            return nil
        }
        
        // Extract salt and sealed box
        let salt = encryptedData.prefix(saltLength)
        let sealedBoxData = encryptedData.dropFirst(saltLength)
        
        // Derive symmetric key using PBKDF2
        guard let symmetricKey = deriveKey(from: password, salt: salt) else {
            errorLog("Failed to derive symmetric key using PBKDF2")
            return nil
        }
        
        do {
            let sealedBox = try AES.GCM.SealedBox(combined: sealedBoxData)
            let decryptedData = try AES.GCM.open(sealedBox, using: symmetricKey)
            let keyPackage = try JSONDecoder().decode(KeyPackage.self, from: decryptedData)
            return keyPackage
        } catch {
            errorLog("PBKDF2 decryption error: \(error)")
            return nil
        }
    }
    
    /// Decrypt using legacy SHA256 format (backward compatibility)
    private func decryptKeysLegacy(encryptedData: Data, password: String) -> KeyPackage? {
        debugLog("⚠️ Using legacy SHA256 decryption (consider re-encrypting with PBKDF2)")
        
        let symmetricKey = deriveKeyLegacy(from: password)
        
        do {
            let sealedBox = try AES.GCM.SealedBox(combined: encryptedData)
            let decryptedData = try AES.GCM.open(sealedBox, using: symmetricKey)
            let keyPackage = try JSONDecoder().decode(KeyPackage.self, from: decryptedData)
            return keyPackage
        } catch {
            errorLog("Legacy decryption error: \(error)")
            return nil
        }
    }
}
