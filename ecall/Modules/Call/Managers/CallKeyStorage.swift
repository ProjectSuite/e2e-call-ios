import Foundation
import Security

class CallKeyStorage {
    static let shared = CallKeyStorage()

    private init() {}

    private let keyPrefix = "org.app.encryptedAESKey."

    // MARK: - Store encryptedAESKey for a callId

    /// Store encryptedAESKey (Base64 string) for a specific callId
    func storeEncryptedAESKey(_ encryptedAESKey: String, for callId: UInt64) -> Bool {
        let account = "\(keyPrefix)\(callId)"
        guard let data = encryptedAESKey.data(using: .utf8) else {
            errorLog("Failed to convert encryptedAESKey to Data")
            return false
        }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]

        // Remove any existing item
        SecItemDelete(query as CFDictionary)

        // Add new item
        let status = SecItemAdd(query as CFDictionary, nil)
        let success = status == errSecSuccess

        if success {
            debugLog("✅ Stored encryptedAESKey for callId: \(callId)")
        } else {
            errorLog("❌ Failed to store encryptedAESKey for callId: \(callId), status: \(status)")
        }

        return success
    }

    // MARK: - Retrieve encryptedAESKey for a callId

    /// Retrieve encryptedAESKey (Base64 string) for a specific callId
    func getEncryptedAESKey(for callId: UInt64) -> String? {
        let account = "\(keyPrefix)\(callId)"
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: account,
            kSecReturnData as String: kCFBooleanTrue as Any,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        if status == errSecSuccess, let data = item as? Data {
            let encryptedAESKey = String(data: data, encoding: .utf8)
            debugLog("✅ Retrieved encryptedAESKey for callId: \(callId)")
            return encryptedAESKey
        } else if status == errSecItemNotFound {
            debugLog("⚠️ No encryptedAESKey found for callId: \(callId)")
        } else {
            errorLog("❌ Failed to retrieve encryptedAESKey for callId: \(callId), status: \(status)")
        }

        return nil
    }

    // MARK: - Remove encryptedAESKey for a callId

    /// Remove stored encryptedAESKey for a specific callId
    /// - Returns: true if an item was actually deleted, false if not found or failed
    func removeEncryptedAESKey(for callId: UInt64) -> Bool {
        let account = "\(keyPrefix)\(callId)"
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: account
        ]

        let status = SecItemDelete(query as CFDictionary)
        if status == errSecSuccess {
            debugLog("✅ Removed encryptedAESKey for callId: \(callId)")
            return true
        } else if status == errSecItemNotFound {
            //            debugLog("⚠️ No encryptedAESKey existed for callId: \(callId)")
            return false
        } else {
            errorLog("❌ Failed to remove encryptedAESKey for callId: \(callId), status: \(status)")
            return false
        }
    }

    // MARK: - Bulk operations
    /// List all stored callIds that have encryptedAESKey saved
    func listAllStoredCallIds() -> [UInt64] {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecReturnAttributes as String: kCFBooleanTrue as Any,
            kSecMatchLimit as String: kSecMatchLimitAll
        ]
        var resultRef: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &resultRef)
        guard status == errSecSuccess, let items = resultRef as? [[String: Any]] else {
            return []
        }
        var callIds: [UInt64] = []
        for item in items {
            if let account = item[kSecAttrAccount as String] as? String,
               account.hasPrefix(keyPrefix),
               let idStr = account.replacingOccurrences(of: keyPrefix, with: "") as String?,
               let id = UInt64(idStr) {
                callIds.append(id)
            }
        }
        return callIds
    }

    /// Remove all stored encryptedAESKeys saved by this storage (by prefix)
    /// - Returns: number of entries actually deleted
    func removeAllEncryptedAESKeys() -> Int {
        let ids = listAllStoredCallIds()
        var removed = 0
        for id in ids {
            if removeEncryptedAESKey(for: id) { removed += 1 }
        }
        debugLog("🧹 Removed \(removed)/\(ids.count) encryptedAESKey entries")
        return removed
    }
}
