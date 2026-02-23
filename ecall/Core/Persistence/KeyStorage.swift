import Foundation
import Security
import CommonCrypto

// MARK: - KeyStorageCrypto

private enum KeyStorageCrypto {
    /// Generates a SHA-256 hash for the given public key.
    static func generateHash(for publicKey: String) -> String {
        let data = Data(publicKey.utf8)
        var hash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        data.withUnsafeBytes {
            _ = CC_SHA256($0.baseAddress, CC_LONG(data.count), &hash)
        }
        return hash.map { String(format: "%02x", $0) }.joined()
    }

    static func createSecKeyPublic(from keyString: String) -> SecKey? {
        guard let keyData = Data(base64Encoded: keyString) else { return nil }

        let options: [String: Any] = [
            kSecAttrKeyType as String: kSecAttrKeyTypeRSA,
            kSecAttrKeyClass as String: kSecAttrKeyClassPublic,
            kSecAttrKeySizeInBits as String: 2048
        ]

        return SecKeyCreateWithData(keyData as CFData, options as CFDictionary, nil)
    }

    static func createSecKeyPrivate(from keyString: String) -> SecKey? {
        guard let keyData = Data(base64Encoded: keyString) else { return nil }

        let options: [String: Any] = [
            kSecAttrKeyType as String: kSecAttrKeyTypeRSA,
            kSecAttrKeyClass as String: kSecAttrKeyClassPrivate,
            kSecAttrKeySizeInBits as String: 2048
        ]

        return SecKeyCreateWithData(keyData as CFData, options as CFDictionary, nil)
    }
}

final class KeyStorage {
    static let shared = KeyStorage()

    private init() {}

    // MARK: - Key Constants
    private let apnsTokenCode     = "org.app.apnsToken"
    private let voipTokenCode     = "org.app.voipToken"
    private let userIdCode        = "org.app.userId"
    private let emailCode         = "org.app.email"
    private let phoneNumberCode   = "org.app.phoneNumber"
    private let displayNameCode   = "org.app.displayName"
    private let publicKeyCode     = "org.app.publicKey"
    private let publicKeyHashCode = "org.app.publicKeyHash"
    private let privateKeyCode    = "org.app.privateKey"
    private let accessTokenCode   = "org.app.accessToken"
    private let refreshTokenCode   = "org.app.refreshToken"
    private let deviceIdCode      = "org.app.deviceId"
    private let deviceNameCode    = "org.app.deviceName"
    private let systemNameCode    = "org.app.systemName"
    private let systemVersionCode = "org.app.systemVersion"
    private let identifierCode    = "org.app.identifier"
    private let appleLoginFlagCode = "org.app.appleLoginFlag"
    private let turnCredentialsCode = "org.app.turnCredentials"

    // MARK: - Private Helpers
    
    /// Default accessibility setting for all Keychain items
    private let defaultAccessibility: CFString = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly

    /// Generic method to store a String value in Keychain
    private func storeString(_ value: String, account: String, accessibility: CFString? = nil) -> Bool {
        let data = Data(value.utf8)
        return storeData(data, account: account, accessibility: accessibility)
    }
    
    /// Generic method to store Data in Keychain
    private func storeData(_ data: Data, account: String, accessibility: CFString? = nil) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: accessibility ?? defaultAccessibility
        ]
        // Remove any existing item
        SecItemDelete(query as CFDictionary)
        // Try adding the new item
        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess
    }

    /// Generic method to read a String value from Keychain
    private func readString(account: String) -> String? {
        guard let data = readData(account: account) else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }
    
    /// Generic method to read Data from Keychain
    private func readData(account: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: account,
            kSecReturnData as String: kCFBooleanTrue as Any,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecSuccess, let data = item as? Data {
            return data
        }
        return nil
    }

    /// Generic method to delete a Keychain item
    private func deleteItem(account: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: account
        ]
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }
    
    // MARK: - Legacy Helper Methods (for backward compatibility)
    
    /// Stores a keychain item for a given account (legacy method - use storeString/storeData instead)
    private func storeItem(account: String, data: Data, accessible: CFString) -> Bool {
        return storeData(data, account: account, accessibility: accessible)
    }

    /// Reads a keychain item for a given account (legacy method - use readString/readData instead)
    private func readItem(account: String) -> String? {
        return readString(account: account)
    }

    // MARK: - Public Methods

    /// Store VoIP token in the Keychain.
    func storeVoipToken(voipToken: String) {
        let success = storeString(voipToken, account: voipTokenCode)
        debugLog(success ? "VoipToken stored successfully in Keychain." : "Failed to store VoipToken in Keychain.")
    }

    /// Store APNs token in the Keychain.
    func storeApnsToken(_ apnsToken: String) {
        let success = storeString(apnsToken, account: apnsTokenCode)
        debugLog(success ? "APNs token stored successfully in Keychain." : "Failed to store APNs token in Keychain.")
    }

    func storeDeviceInfo(deviceName: String, systemName: String, systemVersion: String, identifier: String) {
        let deviceNameSuccess = storeString(deviceName, account: deviceNameCode)
        let systemNameSuccess = storeString(systemName, account: systemNameCode)
        let systemVersionSuccess = storeString(systemVersion, account: systemVersionCode)
        let identifierSuccess = storeString(identifier, account: identifierCode)

        let success = deviceNameSuccess && systemNameSuccess && systemVersionSuccess && identifierSuccess
        debugLog(success ? "DeviceInfos stored successfully in Keychain." : "Failed to store DeviceInfos in Keychain.")
    }

    /// Store DisplayName and keys (public, private and public hash) in the Keychain.
    func storeUserIdentity(userId: String,
                           email: String,
                           phoneNumber: String,
                           displayName: String) -> Bool {
        let userIdSuccess = storeString(userId, account: userIdCode)
        let emailSuccess = storeString(email, account: emailCode)
        let phoneNumberSuccess = storeString(phoneNumber, account: phoneNumberCode)
        let displayNameSuccess = storeString(displayName, account: displayNameCode)

        return userIdSuccess && emailSuccess && phoneNumberSuccess && displayNameSuccess
    }

    func storeUserKeys(publicKey: String, privateKey: String) -> Bool {
        let publicKeySuccess = storeString(publicKey, account: publicKeyCode)
        let publicKeyHashSuccess = storeString(KeyStorageCrypto.generateHash(for: publicKey), account: publicKeyHashCode)
        let privateKeySuccess = storeString(privateKey, account: privateKeyCode)

        return publicKeySuccess && publicKeyHashSuccess && privateKeySuccess
    }

    func storeUserTokens(accessToken: String, refreshToken: String? = nil) -> Bool {
        let accessTokenSuccess = storeString(accessToken, account: accessTokenCode)

        var refreshTokenSuccess = true
        if let refreshToken = refreshToken, !refreshToken.isEmpty {
            refreshTokenSuccess = storeRefreshToken(refreshToken)
        }

        return accessTokenSuccess && refreshTokenSuccess
    }

    /// Store Display ID in the Keychain.
    func saveDeviceId(_ id: String) {
        let success = storeString(id, account: deviceIdCode)
        debugLog(success ? "✅ DeviceId stored successfully in Keychain." : "Failed to store DeviceId in Keychain.")
    }

    /// Store Display Name in the Keychain.
    func saveDisplayName(_ name: String) {
        let success = storeString(name, account: displayNameCode)
        debugLog(success ? "✅ DisplayName stored successfully in Keychain." : "Failed to store DisplayName in Keychain.")
    }

    func saveEmail(_ email: String) {
        let success = storeString(email, account: emailCode)
        debugLog(success ? "✅ Email stored successfully in Keychain." : "Failed to store Email in Keychain.")
    }

    func savePhoneNumber(_ phoneNumber: String) {
        let success = storeString(phoneNumber, account: phoneNumberCode)
        debugLog(success ? "✅ PhoneNumber stored successfully in Keychain." : "Failed to store PhoneNumber in Keychain.")
    }

    /// Read the public key from Keychain.
    func readPublicKey() -> String? {
        return readString(account: publicKeyCode)
    }

    /// Read the private key from Keychain as SecKey.
    func readPrivateKeyAsSecKey() -> SecKey? {
        guard let key = readString(account: privateKeyCode) else { return nil }
        return KeyStorageCrypto.createSecKeyPrivate(from: key)
    }

    func createSecKeyPublic(from keyString: String) -> SecKey? {
        return KeyStorageCrypto.createSecKeyPublic(from: keyString)
    }

    func generateHash(for publicKey: String) -> String {
        return KeyStorageCrypto.generateHash(for: publicKey)
    }

    /// Read the private key from Keychain as Base64 string.
    func readPrivateKeyString() -> String? {
        return readString(account: privateKeyCode)
    }

    /// Save public key string (Base64) to Keychain.
    func savePublicKeyString(_ key: String) {
        let success = storeString(key, account: publicKeyCode)
        debugLog(success ? "✅ publicKeyCode stored successfully in Keychain." : "Failed to store publicKeyCode in Keychain.")
    }

    /// Save private key string (Base64) to Keychain.
    func savePrivateKeyString(_ key: String) {
        let success = storeString(key, account: privateKeyCode)
        debugLog(success ? "✅ privateKeyCode stored successfully in Keychain." : "Failed to store privateKeyCode in Keychain.")
    }

    /// Read the public key hash from Keychain.
    func readPublicKeyHash() -> String? {
        return readString(account: publicKeyHashCode)
    }

    /// Save public key hash string
    func savePublicKeyHashString(_ hash: String) {
        let success = storeString(hash, account: publicKeyHashCode)
        debugLog(success ? "✅ publicKeyHashCode stored successfully in Keychain." : "Failed to store publicKeyHashCode in Keychain.")
    }

    func readUserId() -> String? {
        return readString(account: userIdCode)
    }

    func readDeviceId() -> String? {
        return readString(account: deviceIdCode)
    }

    func readEmail() -> String? {
        return readString(account: emailCode)
    }

    func readPhoneNumber() -> String? {
        return readString(account: phoneNumberCode)
    }

    func readDisplayName() -> String? {
        return readString(account: displayNameCode)
    }

    /// Read the VoIP token from Keychain.
    func readVoipToken() -> String? {
        return readString(account: voipTokenCode)
    }

    /// Read the APNs token from Keychain.
    func readApnsToken() -> String? {
        return readString(account: apnsTokenCode)
    }

    /// Read the access token from Keychain.
    func readAccessToken() -> String? {
        return readString(account: accessTokenCode)
    }
    
    /// Store the access token in Keychain.
    func storeAccessToken(_ token: String) {
        let success = storeString(token, account: accessTokenCode)
        debugLog(success ? "✅ AccessToken stored successfully in Keychain." : "Failed to store AccessToken in Keychain.")
    }
    
    /// Store the refresh token in Keychain.
    func storeRefreshToken(_ token: String) -> Bool {
        let success = storeString(token, account: refreshTokenCode)
        debugLog(success ? "✅ RefreshToken stored successfully in Keychain." : "Failed to store RefreshToken in Keychain.")
        return success
    }
    
    /// Read the refresh token from Keychain.
    func readRefreshToken() -> String? {
        return readString(account: refreshTokenCode)
    }

    func readDeviceName() -> String? {
        return readString(account: deviceNameCode)
    }

    func readSystemName() -> String? {
        return readString(account: systemNameCode)
    }

    func readSystemVersion() -> String? {
        return readString(account: systemVersionCode)
    }

    func readIdentifier() -> String? {
        return readString(account: identifierCode)
    }

    /// Store Apple login flag in the Keychain.
    func storeAppleLoginFlag(_ isConnected: Bool) {
        let flagValue = isConnected ? "true" : "false"
        let success = storeString(flagValue, account: appleLoginFlagCode)
        debugLog(success ? "Apple login flag stored successfully in Keychain." : "Failed to store Apple login flag in Keychain.")
    }

    /// Read Apple login flag from Keychain.
    func readAppleLoginFlag() -> Bool {
        guard let flagString = readString(account: appleLoginFlagCode) else {
            return false
        }
        return flagString == "true"
    }

    /// Remove display name and key items from Keychain.
    func removeUserInfos() -> Bool {
        let accounts = [userIdCode, deviceIdCode, emailCode, phoneNumberCode, displayNameCode, publicKeyCode, publicKeyHashCode, privateKeyCode, accessTokenCode, refreshTokenCode, appleLoginFlagCode]
        return accounts.allSatisfy { deleteItem(account: $0) }
    }

    // MARK: - TURN Credentials Storage (Secure)
    
    /// Store TURN credentials securely in Keychain
    func storeTURNCredentials(data: Data) -> Bool {
        let success = storeData(data, account: turnCredentialsCode)
        debugLog(success ? "✅ TURN credentials stored successfully in Keychain." : "Failed to store TURN credentials in Keychain.")
        return success
    }
    
    /// Read TURN credentials from Keychain
    func readTURNCredentials() -> Data? {
        return readData(account: turnCredentialsCode)
    }
    
    /// Delete TURN credentials from Keychain
    func deleteTURNCredentials() -> Bool {
        return deleteItem(account: turnCredentialsCode)
    }
}
