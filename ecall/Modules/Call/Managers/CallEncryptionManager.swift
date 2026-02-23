import Foundation
import Security
import CryptoKit
import WebRTC

class CallEncryptionManager: NSObject, ObservableObject {
    static let shared = CallEncryptionManager()
    private var cryptoDelegate: CustomAudioCrypto?
    /// Toggle this to turn on "use a bad key" so the other side can't decrypt
    var simulateWrongKey = false

    // Thread-safe queue for key access (video decryption runs on background thread)
    private let keyQueue = DispatchQueue(label: "com.ecall.encryption.keyQueue", attributes: .concurrent)

    private override init() {
        self.cryptoDelegate = nil
        super.init()
    }

    // The AES key for the current call session.
    // On the caller side, this is generated per call.
    // On the callee side, this is derived by decrypting the invitation.
    var sessionAESKey: Data?
    var originalAESKey: Data?

    // Backup key to bridge gaps during key rotation (used for video/data path)
    private var backupSessionAESKey: Data?
    private var backupKeyUpdateTime: Date?
    // Keep backup keys longer to tolerate network jitter / out-of-order packets
    private static let backupKeyRetentionInterval: TimeInterval = 120.0

    // Future key for early-arriving packets encrypted with new key before scheduled application time
    private var futureSessionAESKey: Data?
    private var futureKeySetTime: Date?
    private static let futureKeyRetentionInterval: TimeInterval = 60.0

    // Emergency key redistribution state
    private var lastKeyRequestTime: Date?
    private var isWaitingForKey = false
    private let keyRequestCooldown: TimeInterval = 3.0  // seconds between requests
    private let keyResponseTimeout: TimeInterval = 10.0  // seconds timeout for response

    enum KeyRequestReason: String {
        case mediaDecryptFailed = "media_decrypt_failed"
        case audioDecryptFailed = "audio_decrypt_failed"
    }

    // Dedupe key requests across media pipelines (audio/video)
    // Note: audio decrypt callbacks may come in bursts; we keep a short interval to avoid duplicate requests.
    private var lastKeyRequestSignatureTime: Date?
    private var lastKeyRequestSignature: String?
    private let keyRequestDedupeInterval: TimeInterval = 1.0

    func setUpAesKey(_ aesKey: Data, file: String = #file, line: Int = #line) {
        // Thread-safe key update: use barrier to ensure atomic write
        // This prevents race condition with video decoder reading keys on background thread
        keyQueue.sync(flags: .barrier) {
            // Before applying new key, retain previous one as backup for gap handling
            if let current = sessionAESKey {
                // Safety check: ensure we're not backing up the same key we're about to set
                if current == aesKey {
                    debugLog("⚠️ [Crypto] Warning: Current key matches new key - skipping backup (this may indicate a bug)")
                } else {
                    backupSessionAESKey = current
                    backupKeyUpdateTime = Date()
                }
            }

            // Ensure sessionAESKey reflects the new key for both video/audio paths
            sessionAESKey = aesKey
        }

        // ➡️ Setup for video
        // 1) Derive deterministic IV from key using SHA256 (first 16 bytes)
        //    CRITICAL: All participants must use the SAME IV for CTR mode decryption to work
        //    Using random IV would cause decryption failures during key rotation
        let keyHash = SHA256.hash(data: aesKey)
        let ivData = Data(keyHash.prefix(kCCBlockSizeAES128))

        // 2) Initialize your CTREncryptionManager
        let manager = CRTEncryptionManager.shared()
        let ok = manager.setup(withKey: aesKey, iv: ivData)
        if !ok {
            errorLog("❌ Failed to set up encryption manager")
        }

        // ➡️ Setup for audio
        if let existingCrypto = self.cryptoDelegate {
            // Update existing crypto instance with new key (preserves backup key for gap handling)
            existingCrypto.updateKey(SymmetricKey(data: aesKey))
        } else {
            // Create new crypto instance for first-time setup
            let audioCrypto = CustomAudioCrypto(key: SymmetricKey(data: aesKey))
            self.cryptoDelegate = audioCrypto                 // <— store it
            RTCAudioCryptoManager.shared().delegate = audioCrypto
            debugLog("🛡️ Installed AudioCrypto in CallEncryptionManager →", CallEncryptionManager.shared.cryptoDelegate as Any)
        }
    }

    // MARK: - Call Invitation (RSA Key Exchange)

    /// Called on the caller side when starting a call.
    /// - Parameter calleePublicKey: The callee’s RSA public key (previously exchanged).
    /// - Returns: The encrypted AES key to send via signaling.
    func prepareCallInvitation(with calleePublicKey: SecKey) -> Data? {
        // Generate a fresh AES key.
        if sessionAESKey == nil {
            guard let aesKey = generateAESKey() else {
                debugLog("Failed to generate AES key.")
                return nil
            }
            originalAESKey = aesKey
            sessionAESKey = aesKey
            setUpAesKey(aesKey)
        }

        // Encrypt the AES key using the callee’s RSA public key.
        guard let encryptedAESKey = encryptAESKey(aesKey: sessionAESKey ?? Data(), with: calleePublicKey) else {
            debugLog("Failed to encrypt AES key.")
            return nil
        }
        // Send `encryptedAESKey` along with the call invitation over a secure channel.
        // debugLog("Call invitation prepared. AES key: \(String(describing: sessionAESKey?.base64EncodedString()))")
        return encryptedAESKey
    }

    /// Called on the callee side upon receiving a call invitation.
    /// - Parameter encryptedAESKey: The AES key encrypted with the callee’s RSA public key.
    /// - Parameter calleeRSAPrivateKey: The callee’s RSA private key.
    /// - Returns: The decrypted AES key to use for the call session.
    func processCallInvitation(encryptedAESKey: Data, calleeRSAPrivateKey: SecKey?) -> Data? {
        // Decrypt the AES key using the callee’s RSA private key.
        guard let rsaPrivateKey = calleeRSAPrivateKey,
              let aesKey = decryptAESKey(encryptedAESKey: encryptedAESKey, with: rsaPrivateKey) else {
            debugLog("Failed to decrypt AES key on callee side.")
            return nil
        }

        // 2) optionally corrupt it
        let usedKey: Data = simulateWrongKey
            ? Data(repeating: 0x00, count: aesKey.count)     // <<< bad key: all zeroes
            : aesKey

        originalAESKey = usedKey
        sessionAESKey = usedKey
        setUpAesKey(usedKey)

        return aesKey
    }

    // MARK: - Call Media Data Encryption/Decryption

    /// Encrypt call data (audio/video packets) using the session AES key.
    /// Thread-safe: reads key atomically to handle concurrent key rotation.
    func encryptCallMediaData(_ data: Data) -> Data? {
        // Read key atomically (video encoder may run on background thread)
        let aesKey = keyQueue.sync { sessionAESKey }

        guard let aesKey = aesKey else {
            debugLog("encryptCallMediaData: No AES key established for this session.")
            return nil
        }
        return encryptCallData(data, using: aesKey)
    }

    /// Decrypt call data using the session AES key.
    /// Thread-safe: reads all keys atomically to handle concurrent key rotation.
    func decryptCallMediaData(_ encryptedData: Data) -> Data? {
        // Read all keys atomically to avoid race condition with key rotation
        // Video decoder runs on background thread while key rotation happens on main thread
        let (currentKey, backupKey, futureKey) = keyQueue.sync {
            return (sessionAESKey, backupSessionAESKey, futureSessionAESKey)
        }

        guard let aesKey = currentKey else {
            debugLog("decryptCallMediaData: No AES key established for this session.")
            return nil
        }

        return decryptCallDataThreadSafe(encryptedData, currentKey: aesKey, backupKey: backupKey, futureKey: futureKey)
    }

    // MARK: - Private Helper Methods

    /// Generate a random 256-bit AES key.
    private func generateAESKey() -> Data? {
        let key = SymmetricKey(size: .bits256)
        return key.withUnsafeBytes { Data($0) }
    }

    /// Encrypt an existing AES key using the provided RSA public key (for rejoin flow).
    /// - Parameter aesKey: The AES key to encrypt.
    /// - Parameter publicKey: The RSA public key to encrypt with.
    /// - Returns: The encrypted AES key data, or nil if encryption fails.
    func encryptAESKeyForRejoin(aesKey: Data, with publicKey: SecKey) -> Data? {
        return encryptAESKey(aesKey: aesKey, with: publicKey)
    }

    /// Encrypt the AES key using the provided RSA public key.
    private func encryptAESKey(aesKey: Data, with publicKey: SecKey) -> Data? {
        let algorithm: SecKeyAlgorithm = .rsaEncryptionOAEPSHA256
        guard SecKeyIsAlgorithmSupported(publicKey, .encrypt, algorithm) else {
            debugLog("RSA algorithm not supported for encryption.")
            return nil
        }
        var error: Unmanaged<CFError>?
        guard let encryptedData = SecKeyCreateEncryptedData(publicKey,
                                                            algorithm,
                                                            aesKey as CFData,
                                                            &error) as Data? else {
            if let error = error {
                errorLog("\(error.takeRetainedValue() as Error)")
            } else {
                errorLog("Unknown error")
            }
            return nil
        }
        return encryptedData
    }

    /// Decrypt the encrypted AES key using the provided RSA private key.
    private func decryptAESKey(encryptedAESKey: Data, with privateKey: SecKey) -> Data? {
        let algorithm: SecKeyAlgorithm = .rsaEncryptionOAEPSHA256
        guard SecKeyIsAlgorithmSupported(privateKey, .decrypt, algorithm) else {
            debugLog("RSA algorithm not supported for decryption.")
            return nil
        }
        var error: Unmanaged<CFError>?
        guard let decryptedData = SecKeyCreateDecryptedData(privateKey,
                                                            algorithm,
                                                            encryptedAESKey as CFData,
                                                            &error) as Data? else {
            if let error = error {
                errorLog("\(error.takeRetainedValue() as Error)")
            } else {
                errorLog("Unknown error")
            }
            return nil
        }
        return decryptedData
    }

    /// Encrypt data using AES-GCM with the given key.
    private func encryptCallData(_ data: Data, using keyData: Data) -> Data? {
        let symmetricKey = SymmetricKey(data: keyData)
        do {
            let sealedBox = try AES.GCM.seal(data, using: symmetricKey)
            return sealedBox.combined
        } catch {
            errorLog("\(error)")
            return nil
        }
    }

    /// Set future key for key rotation (before scheduled application time)
    /// This allows decryption of packets encrypted with new key before scheduled time
    /// Thread-safe: uses barrier to ensure atomic write
    func setFutureSessionKey(_ futureKey: Data) {
        keyQueue.sync(flags: .barrier) {
            futureSessionAESKey = futureKey
            futureKeySetTime = Date()
        }

        // Also set future key for audio crypto to handle early-arriving audio packets
        if let audioCrypto = self.cryptoDelegate {
            audioCrypto.setFutureKey(SymmetricKey(data: futureKey))
        }
    }

    /// Clear backup session key if retention period has passed
    private func clearExpiredBackupSessionKeyIfNeeded() {
        guard let updateTime = backupKeyUpdateTime else { return }
        let elapsed = Date().timeIntervalSince(updateTime)
        if elapsed > Self.backupKeyRetentionInterval {
            backupSessionAESKey = nil
            backupKeyUpdateTime = nil
            debugLog("🔄 [Crypto] Backup session key cleared after retention period")
        }
    }

    /// Clear future session key if retention period has passed
    private func clearExpiredFutureSessionKeyIfNeeded() {
        guard let setTime = futureKeySetTime else { return }
        let elapsed = Date().timeIntervalSince(setTime)
        if elapsed > Self.futureKeyRetentionInterval {
            futureSessionAESKey = nil
            futureKeySetTime = nil
            debugLog("🔄 [Crypto] Future session key cleared after retention period")
        }
    }
    
    /// Thread-safe decrypt for video: takes all keys as parameters (already read atomically)
    /// This avoids race condition when video decoder on background thread reads keys while main thread updates them
    private func decryptCallDataThreadSafe(_ encryptedData: Data, currentKey: Data, backupKey: Data?, futureKey: Data?) -> Data? {
        // AES-GCM minimum size: 12 (nonce) + 16 (tag) = 28 bytes
        guard encryptedData.count >= 28 else {
            errorLog("❌ [Crypto] Data too small for AES-GCM: \(encryptedData.count)B (min 28B required)")
            return nil
        }

        // Try current key first
        let primaryKey = SymmetricKey(data: currentKey)
        do {
            let sealedBox = try AES.GCM.SealedBox(combined: encryptedData)
            let clear = try AES.GCM.open(sealedBox, using: primaryKey)
            return clear
        } catch let currentError {
            // Try backup key if available (for packets encrypted with previous key)
            if let backup = backupKey {
                do {
                    let sealedBox = try AES.GCM.SealedBox(combined: encryptedData)
                    let clear = try AES.GCM.open(sealedBox, using: SymmetricKey(data: backup))
                    debugLog("🔓 [Crypto] decryptCallData success with backup session key (current error: \(currentError))")
                    return clear
                } catch let backupError {
                    // Try future key if available (for packets encrypted with new key before scheduled time)
                    if let future = futureKey {
                        do {
                            let sealedBox = try AES.GCM.SealedBox(combined: encryptedData)
                            let clear = try AES.GCM.open(sealedBox, using: SymmetricKey(data: future))
                            debugLog("🔮 [Crypto] decryptCallData success with future session key (early packet from key rotation, current error: \(currentError), backup error: \(backupError))")
                            return clear
                        } catch let futureError {
                            // All three keys failed
                            errorLog("❌ [CRITICAL] decryptCallData failed with all keys: current=\(currentError), backup=\(backupError), future=\(futureError)")
                            // Request emergency key from host
                            requestKeyFromHostIfNeeded(reason: .mediaDecryptFailed)
                            return nil
                        }
                    } else {
                        // No future key available
                        errorLog("❌ [CRITICAL] decryptCallData failed with both keys: current=\(currentError), backup=\(backupError)")
                        // Request emergency key from host
                        requestKeyFromHostIfNeeded(reason: .mediaDecryptFailed)
                        return nil
                    }
                }
            } else {
                // No backup key, try future key directly
                if let future = futureKey {
                    do {
                        let sealedBox = try AES.GCM.SealedBox(combined: encryptedData)
                        let clear = try AES.GCM.open(sealedBox, using: SymmetricKey(data: future))
                        debugLog("🔮 [Crypto] decryptCallData success with future session key (early packet from key rotation, current error: \(currentError))")
                        return clear
                    } catch let futureError {
                        errorLog("❌ [CRITICAL] decryptCallData failed with both keys: current=\(currentError), future=\(futureError)")
                        // Request emergency key from host
                        requestKeyFromHostIfNeeded(reason: .mediaDecryptFailed)
                        return nil
                    }
                } else {
                    errorLog("\(currentError)")
                    // No backup or future keys available - try requesting from host
                    requestKeyFromHostIfNeeded()
                    return nil
                }
            }
        }
    }

    /// Decrypt data using AES-GCM with current key, then fallback to backup key, then future key if needed.
    /// Note: This method reads keys from instance variables - use decryptCallDataThreadSafe for thread-safe access
    private func decryptCallData(_ encryptedData: Data, using keyData: Data) -> Data? {
        return decryptCallDataThreadSafe(encryptedData, currentKey: keyData, backupKey: backupSessionAESKey, futureKey: futureSessionAESKey)
    }

    func randomAESKey() -> Data {
        let key = SymmetricKey(size: .bits256)
        return key.withUnsafeBytes { Data($0) }
    }

    func revertAESKey() {
        setUpAesKey(self.originalAESKey ?? randomAESKey())
    }
    
    /// Clean up encryption state when call ends
    /// This resets the crypto delegate to ensure fresh state for next call
    /// Clean up encryption state when call ends
    /// Thread-safe: uses barrier to ensure atomic write
    func cleanup() {
        self.cryptoDelegate = nil
        self.originalAESKey = nil
        RTCAudioCryptoManager.shared().delegate = nil

        // Thread-safe key cleanup
        keyQueue.sync(flags: .barrier) {
            self.sessionAESKey = nil
            self.backupSessionAESKey = nil
            self.backupKeyUpdateTime = nil
            self.futureSessionAESKey = nil
            self.futureKeySetTime = nil
        }

        debugLog("🧹 [Crypto] CallEncryptionManager cleaned up")
    }

    // MARK: - P-256 ECDH Key Agreement (New)

    /// Prepare call invitation using P-256 ECDH for 1-to-1 calls
    /// - Parameter calleePublicKeyBase64: The callee's P-256 public key (Base64)
    /// - Returns: Our public key (Base64) to send to callee
    func prepareCallInvitationP256(calleePublicKeyBase64: String) -> String? {
        let p256Service = P256SecureEnclaveService.shared

        do {
            // Load our private key from Secure Enclave
            let privateKey = try p256Service.loadPrivateKeyReference()

            // Derive shared secret using ECDH
            let sharedSecret = try p256Service.deriveSharedSecret(
                privateKey: privateKey,
                peerPublicKeyBase64: calleePublicKeyBase64
            )

            // Convert symmetric key to Data for AES key
            let aesKey = sharedSecret.withUnsafeBytes { Data($0) }

            // Store as session key
            originalAESKey = aesKey
            sessionAESKey = aesKey
            setUpAesKey(aesKey)

            // Return our public key
            let ourPublicKey = p256Service.getPublicKeyBase64(from: privateKey)
            debugLog("🔐 P-256 call invitation prepared (ECDH)")

            return ourPublicKey

        } catch {
            errorLog("Failed to prepare P-256 call invitation: \(error)")
            return nil
        }
    }

    /// Process call invitation using P-256 ECDH for 1-to-1 calls
    /// - Parameter callerPublicKeyBase64: The caller's P-256 public key (Base64)
    /// - Returns: true if successful
    func processCallInvitationP256(callerPublicKeyBase64: String) -> Bool {
        let p256Service = P256SecureEnclaveService.shared

        do {
            // Load our private key from Secure Enclave
            let privateKey = try p256Service.loadPrivateKeyReference()

            // Derive shared secret using ECDH
            let sharedSecret = try p256Service.deriveSharedSecret(
                privateKey: privateKey,
                peerPublicKeyBase64: callerPublicKeyBase64
            )

            // Convert symmetric key to Data for AES key
            let aesKey = sharedSecret.withUnsafeBytes { Data($0) }

            // Optionally corrupt it for testing
            let usedKey: Data = simulateWrongKey
                ? Data(repeating: 0x00, count: aesKey.count)
                : aesKey

            // Store as session key
            originalAESKey = usedKey
            sessionAESKey = usedKey
            setUpAesKey(usedKey)

            debugLog("🔐 P-256 call invitation processed (ECDH)")

            return true

        } catch {
            errorLog("Failed to process P-256 call invitation: \(error)")
            return false
        }
    }

    // MARK: - P-256 Group Call Key Encryption

    /// Encrypt group AES key for a participant using P-256 ECDH
    /// - Parameters:
    ///   - groupKey: The group AES key to encrypt
    ///   - participantPublicKeyBase64: Participant's P-256 public key (Base64)
    /// - Returns: Encrypted group key data
    func encryptGroupKeyP256(groupKey: Data, participantPublicKeyBase64: String) -> Data? {
        let p256Service = P256SecureEnclaveService.shared

        do {
            // Load our private key from Secure Enclave
            let privateKey = try p256Service.loadPrivateKeyReference()

            // Derive pairwise shared secret with participant
            let sharedSecret = try p256Service.deriveSharedSecret(
                privateKey: privateKey,
                peerPublicKeyBase64: participantPublicKeyBase64
            )

            // Encrypt group key with pairwise shared secret
            let sealedBox = try AES.GCM.seal(groupKey, using: sharedSecret)
            let encryptedGroupKey = sealedBox.combined

            debugLog("🔐 Encrypted group key for participant (P-256)")

            return encryptedGroupKey

        } catch {
            errorLog("Failed to encrypt group key with P-256: \(error)")
            return nil
        }
    }

    /// Decrypt group AES key using P-256 ECDH
    /// - Parameters:
    ///   - encryptedGroupKey: The encrypted group key
    ///   - initiatorPublicKeyBase64: Initiator's P-256 public key (Base64)
    /// - Returns: Decrypted group key data
    func decryptGroupKeyP256(encryptedGroupKey: Data, initiatorPublicKeyBase64: String) -> Data? {
        let p256Service = P256SecureEnclaveService.shared

        do {
            // Load our private key from Secure Enclave
            let privateKey = try p256Service.loadPrivateKeyReference()

            // Derive pairwise shared secret with initiator
            let sharedSecret = try p256Service.deriveSharedSecret(
                privateKey: privateKey,
                peerPublicKeyBase64: initiatorPublicKeyBase64
            )

            // Decrypt group key with pairwise shared secret
            let sealedBox = try AES.GCM.SealedBox(combined: encryptedGroupKey)
            let groupKey = try AES.GCM.open(sealedBox, using: sharedSecret)

//            debugLog("🔐 Decrypted group key from initiator (P-256)")

            return groupKey

        } catch {
            errorLog("Failed to decrypt group key with P-256: \(error)")
            return nil
        }
    }

    // MARK: - Emergency Key Redistribution

    /// Request key from host when all decrypt attempts fail
    /// Called from decryptCallDataThreadSafe when current, backup, and future keys all fail
    func requestKeyFromHostIfNeeded(reason: KeyRequestReason? = nil) {
        // Is host not request new key
        if GroupCallSessionManager.shared.isKeyRotationHost {
            debugLog("🔓 [Key Request] You is host key, skipping request")
            return
        }

        // Short-interval dedupe across pipelines (audio/video)
        // If audio+video fail around the same time, only request once.
        if let signature = reason?.rawValue {
            if let lastSig = lastKeyRequestSignature,
               let lastTime = lastKeyRequestSignatureTime,
               lastSig == signature,
               Date().timeIntervalSince(lastTime) < keyRequestDedupeInterval {
                debugLog("⏳ [Key Request] Duplicate signature within dedupe interval - skipping request")
                return
            }
            lastKeyRequestSignature = signature
            lastKeyRequestSignatureTime = Date()
        }
        
        // Rate limiting: Only request if cooldown passed
        if let lastRequest = lastKeyRequestTime,
           Date().timeIntervalSince(lastRequest) < keyRequestCooldown {
            debugLog("⏳ [Key Request] On cooldown - skipping request")
            return
        }
        
        // Don't request if already waiting
        if isWaitingForKey {
            debugLog("⏳ [Key Request] Already waiting for key response")
            return
        }

        // Find key rotation host (participant with isHostKey = true)
        guard let host = GroupCallSessionManager.shared.participants.first(where: { $0.isHostKey }) else {
            debugLog("⚠️ [Key Request] No key rotation host found (no participant with isHostKey=true)")
            return
        }
        
        guard let currentUserId = UInt64(KeyStorage.shared.readUserId() ?? "") else {
            debugLog("⚠️ [Key Request] Cannot get current user ID")
            return
        }

        guard let currentDeviceId = UInt64(KeyStorage.shared.readDeviceId() ?? "") else {
            debugLog("⚠️ [Key Request] Cannot get current device ID")
            return
        }

        debugLog("🔑 [Key Request] Requesting emergency key from host (userId: \(host.userId))")

        // Send request signal - use positional arguments
        let signal = SignalMessage(
            type: .request_aes_key,
            participantId: host.userId,
            participantDeviceId: host.deviceId,
            callId: GroupCallSessionManager.shared.currentCallId,
            senderId: currentUserId,
            senderDeviceId: currentDeviceId
        )

        StompSignalingManager.shared.send(signal)

        // Update state
        lastKeyRequestTime = Date()
        isWaitingForKey = true

        // Timeout after 10 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + keyResponseTimeout) { [weak self] in
            guard let self = self else { return }
            if self.isWaitingForKey {
                self.isWaitingForKey = false
                debugLog("⏰ [Key Request] Response timeout - can request again")
            }
        }
    }

    /// Mark key request as complete (called when receiving send_aes_key response)
    func markKeyRequestComplete() {
        isWaitingForKey = false
        debugLog("✅ [Key Request] Request completed successfully")
    }
}
