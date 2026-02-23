import Foundation
import CryptoKit
import WebRTC

@objcMembers
class CustomAudioCrypto: NSObject, RTCAudioCrypto {
    private var key: SymmetricKey
    private var backupKey: SymmetricKey?
    private var keyUpdateTime: Date?
    // Future key for early-arriving packets encrypted with new key before scheduled application time
    private var futureKey: SymmetricKey?
    private var futureKeySetTime: Date?
    private static let marker: UInt8 = 0xFF
    private static let backupKeyRetentionInterval: TimeInterval = 30.0 // Keep backup key for 30 seconds after key update (handles network delay, clock skew, and key rotation gaps)
    private static let futureKeyRetentionInterval: TimeInterval = 60.0 // Keep future key for 60 seconds

    init(key: SymmetricKey) {
        self.key = key
        self.backupKey = nil
        self.keyUpdateTime = nil
        super.init()
    }
    
    /// Update encryption key, keeping the old key as backup
    func updateKey(_ newKey: SymmetricKey) {
        // Always save current key as backup before updating (even if nil, to handle edge cases)
        backupKey = key  // Save current key as backup
        key = newKey     // Update to new key
        keyUpdateTime = Date()  // Track when key was updated

        // Clear future key when key is applied (it becomes the current key)
        futureKey = nil
        futureKeySetTime = nil

        // Log backup key status for debugging
        if backupKey == nil {
            debugLog("⚠️ [Crypto] Warning: backupKey is nil after updateKey - this may cause issues during key rotation gap")
        }
    }

    /// Set future key for early-arriving packets (before scheduled key rotation time)
    func setFutureKey(_ newFutureKey: SymmetricKey) {
        futureKey = newFutureKey
        futureKeySetTime = Date()
        debugLog("🔮 [Crypto] Future audio key set for key rotation")
    }

    /// Clear future key if retention period has passed
    private func clearExpiredFutureKeyIfNeeded() {
        guard let setTime = futureKeySetTime else { return }
        let elapsed = Date().timeIntervalSince(setTime)
        if elapsed > Self.futureKeyRetentionInterval {
            futureKey = nil
            futureKeySetTime = nil
            debugLog("🔄 [Crypto] Future key cleared after retention period")
        }
    }
    
    /// Clear backup key if retention period has passed
    private func clearExpiredBackupKeyIfNeeded() {
        guard let updateTime = keyUpdateTime else { return }
        let elapsed = Date().timeIntervalSince(updateTime)
        if elapsed > Self.backupKeyRetentionInterval {
            backupKey = nil
            keyUpdateTime = nil
            debugLog("🔄 [Crypto] Backup key cleared after retention period")
        }
    }

    /// Encrypt outgoing PCM → [MARKER | IV | ciphertext | TAG]
    /// Returns empty Data to drop frame if encryption fails (CRITICAL: never send plaintext)
    func encryptData(_ plain: Data) -> Data {
        do {
            let sealed = try AES.GCM.seal(plain, using: key)
            guard let combined = sealed.combined else {
                let msg = "❌ [CRITICAL] Encryption failed: seal.combined was nil - dropping frame (\(plain.count)B) to prevent plaintext leak"
                errorLog(msg)
                CryptoLogger.shared.add(msg)
                return Data() // Drop frame instead of sending plaintext
            }

            // Prepend our one-byte marker
            var out = Data([Self.marker])
            out.append(combined)

            // debugLog("🔒 [Crypto] encryptData: plain=\(plain.count)B → payload=\(out.count)B (IV=\(ivHex) TAG=\(tagHex))")
            return out
        } catch {
            let msg = "❌ [CRITICAL] Encryption error: \(error) - dropping frame (\(plain.count)B) to prevent plaintext leak"
            errorLog(msg)
            CryptoLogger.shared.add(msg)
            return Data() // Drop frame instead of sending plaintext
        }
    }

    /// Decrypt incoming [MARKER | IV | ciphertext | TAG] → PCM
    /// Returns empty Data to drop frame if decryption fails (CRITICAL: never pass-through corrupted data)
    func decryptData(_ cipher: Data) -> Data {
        guard cipher.first == Self.marker else {
            let msg = "❌ [CRITICAL] decryptData: no marker found - dropping frame (\(cipher.count)B) to prevent processing unencrypted data"
            errorLog(msg)
            CryptoLogger.shared.add(msg)
            CallEncryptionManager.shared.requestKeyFromHostIfNeeded(reason: .audioDecryptFailed)
            return Data() // Drop frame instead of pass-through
        }

        let combined = cipher.dropFirst()

        // Try decrypting with current key first
        do {
            let box   = try AES.GCM.SealedBox(combined: combined)
            let clear = try AES.GCM.open(box, using: key)
            // Clear expired keys after successful decryption with current key
            clearExpiredBackupKeyIfNeeded()
            clearExpiredFutureKeyIfNeeded()
            let msg = "🔓 [Crypto] decryptData success with current key: clear=\(clear.count)B"
            CryptoLogger.shared.add(msg)
            return clear
        } catch let currentError {
            // Try backup key (for packets encrypted with previous key)
            if let backup = backupKey {
                do {
                    let box = try AES.GCM.SealedBox(combined: combined)
                    let clear = try AES.GCM.open(box, using: backup)
                    clearExpiredBackupKeyIfNeeded()
                    clearExpiredFutureKeyIfNeeded()
                    let msg = "🔓 [Crypto] decryptData success with backup key: clear=\(clear.count)B (current error: \(currentError))"
                    debugLog(msg)
                    CryptoLogger.shared.add(msg)
                    return clear
                } catch let backupError {
                    // Try future key (for early-arriving packets from key rotation)
                    if let future = futureKey {
                        do {
                            let box = try AES.GCM.SealedBox(combined: combined)
                            let clear = try AES.GCM.open(box, using: future)
                            clearExpiredBackupKeyIfNeeded()
                            clearExpiredFutureKeyIfNeeded()
                            let msg = "🔮 [Crypto] decryptData success with future key: clear=\(clear.count)B (early packet from key rotation)"
                            debugLog(msg)
                            CryptoLogger.shared.add(msg)
                            return clear
                        } catch let futureError {
                            // All three keys failed
                            clearExpiredBackupKeyIfNeeded()
                            clearExpiredFutureKeyIfNeeded()
                            let msg = "❌ [CRITICAL] decryptData error with all keys: current=\(currentError), backup=\(backupError), future=\(futureError) - dropping frame (\(cipher.count)B)"
                            errorLog(msg)
                            CryptoLogger.shared.add(msg)
                            CallEncryptionManager.shared.requestKeyFromHostIfNeeded(reason: .audioDecryptFailed)
                            return Data()
                        }
                    } else {
                        // No future key, both current and backup failed
                        clearExpiredBackupKeyIfNeeded()
                        let msg = "❌ [CRITICAL] decryptData error with both keys: current=\(currentError), backup=\(backupError) - dropping frame (\(cipher.count)B)"
                        errorLog(msg)
                        CryptoLogger.shared.add(msg)
                        CallEncryptionManager.shared.requestKeyFromHostIfNeeded(reason: .audioDecryptFailed)
                        return Data()
                    }
                }
            } else {
                // No backup key, try future key directly
                if let future = futureKey {
                    do {
                        let box = try AES.GCM.SealedBox(combined: combined)
                        let clear = try AES.GCM.open(box, using: future)
                        clearExpiredFutureKeyIfNeeded()
                        let msg = "🔮 [Crypto] decryptData success with future key: clear=\(clear.count)B (early packet from key rotation, current error: \(currentError))"
                        debugLog(msg)
                        CryptoLogger.shared.add(msg)
                        return clear
                    } catch let futureError {
                        clearExpiredFutureKeyIfNeeded()
                        let msg = "❌ [CRITICAL] decryptData error: current=\(currentError), future=\(futureError) - dropping frame (\(cipher.count)B) (no backup key)"
                        errorLog(msg)
                        CryptoLogger.shared.add(msg)
                        CallEncryptionManager.shared.requestKeyFromHostIfNeeded(reason: .audioDecryptFailed)
                        return Data()
                    }
                } else {
                    // No backup or future keys
                    let timeInfo: String
                    if let updateTime = keyUpdateTime {
                        timeInfo = "key updated \(String(format: "%.1f", Date().timeIntervalSince(updateTime)))s ago"
                    } else {
                        timeInfo = "no update time tracked"
                    }
                    clearExpiredBackupKeyIfNeeded()
                    let msg = "❌ [CRITICAL] decryptData error: \(currentError) - dropping frame (\(cipher.count)B) (no backup/future keys, \(timeInfo))"
                    errorLog(msg)
                    CryptoLogger.shared.add(msg)
                    CallEncryptionManager.shared.requestKeyFromHostIfNeeded(reason: .audioDecryptFailed)
                    return Data()
                }
            }
        }
    }
}
