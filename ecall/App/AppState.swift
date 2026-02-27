import Foundation
import CommonCrypto
import UIKit

/// Central application state, implemented as a singleton.
@MainActor
final class AppState: ObservableObject {
    /// Shared singleton instance
    static let shared = AppState()

    // MARK: - Published Properties
    @Published var isRegistered: Bool = false
    @Published var userID: String = ""
    @Published var publicKey: String = ""
    @Published var email: String = ""
    @Published var phoneNumber: String = ""
    @Published var displayName: String = ""
    @Published var deletedAt: Date? = nil
    /// Pending route determined by notification/deeplink during cold start
    @Published var pendingRoute: PendingRoute?

    private let authService = AuthService()

    // Prevent external instantiation
    private init() {
        loadCredentials()
        ensureInitialKeys()
        ensureInitialDeviceInfo()

        // Pre-authenticate P-256 key to avoid biometric prompt delay during first call
        preAuthenticateP256Key()

        fetchCurrentUserInfo()
        fetchCredentials()
        setupNotificationListeners()
    }

    /// Generate and persist initial keys once at app start if missing
    /// Uses P-256 Secure Enclave if available, falls back to RSA for older devices
    private func ensureInitialKeys() {
        let existingPub = KeyStorage.shared.readPublicKey() ?? ""
        let hasPrivateKey = hasExistingPrivateKey()

        // Both public and private keys must exist to use existing keys
        if !existingPub.isEmpty && hasPrivateKey {
            // Valid key pair exists - use it
            self.publicKey = existingPub
            debugLog("✅ Using existing key pair (public: \(existingPub.count) chars)")
            return
        }

        // Handle orphaned keys (only one exists)
        if !existingPub.isEmpty || hasPrivateKey {
            debugLog("⚠️ Orphaned keys detected - cleaning up and regenerating")
            // Delete orphaned keys
            if hasPrivateKey {
                deletePrivateKeys()
            }
            // Public key will be overwritten, no need to delete
        }

        // Generate new keys
        if P256SecureEnclaveService.isSecureEnclaveAvailable() {
            let p256Service = P256SecureEnclaveService.shared
            do {
                // Generate P-256 keypair in Secure Enclave
                let (privateKey, publicKeyBase64) = try p256Service.generateKeyPair()

                // Store private key reference in Keychain
                _ = p256Service.storePrivateKeyReference(privateKey)

                // Store public key for API registration
                KeyStorage.shared.savePublicKeyString(publicKeyBase64)
                KeyStorage.shared.savePublicKeyHashString(KeyStorage.shared.generateHash(for: publicKeyBase64))

                self.publicKey = publicKeyBase64

                debugLog("🔐 Generated P-256 keypair in Secure Enclave (\(publicKeyBase64.count) chars)")

            } catch {
                errorLog("Failed to generate P-256 keys: \(error), falling back to RSA")
                generateRSAKeyPairFallback()
            }
        } else {
            // Fallback to RSA for devices without Secure Enclave (iPhone 5 or older, simulator)
            debugLog("⚠️ Secure Enclave not available, using RSA-2048 fallback")
            generateRSAKeyPairFallback()
        }
    }

    /// Fallback to RSA key generation for devices without Secure Enclave
    private func generateRSAKeyPairFallback() {
        let rsa = RSAKeyService()
        if let pair = rsa.generateRSAKeyPair() {
            KeyStorage.shared.savePublicKeyString(pair.publicKey)
            KeyStorage.shared.savePrivateKeyString(pair.privateKey)
            KeyStorage.shared.savePublicKeyHashString(KeyStorage.shared.generateHash(for: pair.publicKey))
            self.publicKey = pair.publicKey
            debugLog("🔐 Generated RSA-2048 keypair at startup (fallback)")
        } else {
            errorLog("Failed to generate RSA keys")
        }
    }

    /// Check if we have an existing private key (P-256 or RSA)
    /// Returns true if either P-256 Secure Enclave key or RSA private key exists
    private func hasExistingPrivateKey() -> Bool {
        // First check if we have a P-256 key in Secure Enclave
        if P256SecureEnclaveService.isSecureEnclaveAvailable() {
            let p256Service = P256SecureEnclaveService.shared
            do {
                _ = try p256Service.loadPrivateKeyReference()
                debugLog("✅ Found existing P-256 private key in Secure Enclave")
                return true
            } catch {
                // P-256 key doesn't exist, continue checking RSA
            }
        }

        // Check if we have an RSA private key
        if let rsaPrivateKey = KeyStorage.shared.readPrivateKeyString(),
           !rsaPrivateKey.isEmpty {
            debugLog("✅ Found existing RSA private key in Keychain")
            return true
        }

        debugLog("⚠️ No existing private key found (neither P-256 nor RSA)")
        return false
    }

    /// Delete all private keys (P-256 and RSA)
    /// Used to clean up orphaned keys before regenerating
    private func deletePrivateKeys() {
        // Delete P-256 key from Secure Enclave (if exists)
        if P256SecureEnclaveService.isSecureEnclaveAvailable() {
            let p256Service = P256SecureEnclaveService.shared
            if p256Service.deletePrivateKey() {
                debugLog("🗑️ Deleted orphaned P-256 private key from Secure Enclave")
            }
        }

        // Delete RSA private key from Keychain (if exists)
        if KeyStorage.shared.readPrivateKeyString() != nil {
            KeyStorage.shared.savePrivateKeyString("")  // Clear RSA key
            debugLog("🗑️ Deleted orphaned RSA private key from Keychain")
        }
    }

    /// Pre-authenticate P-256 key to trigger biometric prompt early (avoids delay during first call)
    /// This should be called after ensureInitialKeys() during app startup
    private func preAuthenticateP256Key() {
        guard P256SecureEnclaveService.isSecureEnclaveAvailable() else {
            debugLog("⚠️ Secure Enclave not available, skipping pre-authentication")
            return
        }

        guard !publicKey.isEmpty else {
            debugLog("⚠️ No public key found, skipping pre-authentication")
            return
        }

        // Only pre-authenticate for P-256 keys (short keys ~88 chars)
        guard publicKey.count < 150 else {
            debugLog("⚠️ RSA key detected, skipping P-256 pre-authentication")
            return
        }

        // Pre-authenticate in background to avoid blocking app startup
        DispatchQueue.global(qos: .userInitiated).async {
            let p256Service = P256SecureEnclaveService.shared
            if p256Service.preAuthenticate() {
                debugLog("🔓 P-256 key pre-authenticated successfully")
            } else {
                debugLog("⚠️ P-256 key pre-authentication failed")
            }
        }
    }

    /// Capture and persist device information once at app start so login payload is complete
    private func ensureInitialDeviceInfo() {
        let storedName = KeyStorage.shared.readDeviceName() ?? ""
        let storedSysName = KeyStorage.shared.readSystemName() ?? ""
        let storedSysVersion = KeyStorage.shared.readSystemVersion() ?? ""
        let storedIdentifier = KeyStorage.shared.readIdentifier() ?? ""
        guard storedName.isEmpty || storedSysName.isEmpty || storedSysVersion.isEmpty || storedIdentifier.isEmpty else {
            return
        }
        let device = UIDevice.current
        let deviceName = device.name
        let systemName = device.systemName
        let systemVersion = device.systemVersion
        let identifier = DeviceInfo.getCurrentCommercialName()
        KeyStorage.shared.storeDeviceInfo(
            deviceName: deviceName,
            systemName: systemName,
            systemVersion: systemVersion,
            identifier: identifier
        )
        debugLog("📲 Stored device info: name=\(deviceName), sys=\(systemName) \(systemVersion), id=\(identifier)")
    }

    // MARK: - Routing
    enum PendingRoute: Equatable {
        case settings
        case contacts
        case contactsFriendRequests
    }

    // MARK: - Credential Handling
    func loadCredentials() {
        if let uname = KeyStorage.shared.readDisplayName() {
            displayName = uname
        }
        if let mail = KeyStorage.shared.readEmail() {
            email = mail
        }
        if let phone = KeyStorage.shared.readPhoneNumber() {
            phoneNumber = phone
        }
        if let pubKey = KeyStorage.shared.readPublicKey() {
            publicKey = pubKey
        }
        if let uid = KeyStorage.shared.readUserId() {
            userID = uid
        }

        isRegistered = !userID.isEmpty && !publicKey.isEmpty
    }

    private func fetchCredentials() {
        if !isRegistered {return}
        CredentialsService.shared.fetchCredentials()
    }

    func fetchCurrentUserInfo() { // reload new user info
        if !isRegistered {return}

        UserService.shared.fetchCurrenrUser { response in
            if let user = response {
                Task { @MainActor in
                    self.updateDisplayName(user.displayName)
                    self.updateEmail(user.email)
                    self.updatePhoneNumber(user.phoneNumber)
                    self.deletedAt = user.deletedAt
                }
            }
        }
    }

    // MARK: Notifications
    private func setupNotificationListeners() {
        // Listen for profile change notifications
        NotificationCenter.default.addObserver(
            forName: .profileDidChange,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            debugLog("📱 App received profile change notification: \(notification.userInfo ?? [:])")
            Task { @MainActor in self?.fetchCurrentUserInfo() }
        }
    }

    // MARK: - Logout Flow
    /// Public logout entrypoint
    func logout(remotely: Bool = true) {
        if remotely {
            performRemoteLogout()
        } else {
            completeLogout()
        }
    }

    /// Call remote logout endpoint
    private func performRemoteLogout() {
        authService.logout { [weak self] result in
            Task { @MainActor in
                switch result {
                case .success:
                    debugLog("Remote logout successful")
                    self?.completeLogout()
                case .failure(let error):
                    errorLog(error.content)
                    self?.completeLogout()
                }
            }
        }
    }

    /// Complete local logout and reset state
    private func completeLogout() {
        StompSignalingManager.shared.onLogout()
        _ = KeyStorage.shared.removeUserInfos()

        // Clear all keys (both public and private) to ensure clean slate
        // This prevents orphaned key detection during key regeneration
        deletePrivateKeys()
        self.publicKey = ""

        self.isRegistered = false
        self.email = ""
        self.displayName = ""
        self.userID = ""
        self.deletedAt = nil

        // Clear app lock settings on logout
        AppLockManager.shared.clearAppLockSettings()

        // Generate fresh keys (will not trigger orphaned key detection)
        ensureInitialKeys()
    }

    // MARK: - Misc
    func updateDisplayName(_ displayName: String) {
        self.displayName = displayName
        KeyStorage.shared.saveDisplayName(displayName)
    }

    func updateEmail(_ email: String) {
        self.email = email
        KeyStorage.shared.saveEmail(email)
    }

    func updatePhoneNumber(_ phoneNumber: String) {
        self.phoneNumber = phoneNumber
        KeyStorage.shared.savePhoneNumber(phoneNumber)
    }

    private func generateHash(for publicKey: String) -> String {
        let data = Data(publicKey.utf8)
        var hash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        data.withUnsafeBytes {
            _ = CC_SHA256($0.baseAddress, CC_LONG(data.count), &hash)
        }
        return hash.map { String(format: "%02x", $0) }.joined()
    }
}
