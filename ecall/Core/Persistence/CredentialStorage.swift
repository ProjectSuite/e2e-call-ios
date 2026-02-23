import Foundation

class CredentialStorage {
    /// Save TURN credentials securely to Keychain.
    static func save(credentials: CredentialsResponse) {
        let encoder = JSONEncoder()
        do {
            let data = try encoder.encode(credentials)

            let success = KeyStorage.shared.storeTURNCredentials(data: data)
            if success {
                successLog("✅ TURN credentials saved securely to Keychain.")
            } else {
                errorLog("Failed to store TURN credentials in Keychain.")
            }
        } catch {
            errorLog("Failed to encode TURN credentials: \(error)")
        }
    }

    /// Load TURN credentials from Keychain.
    static func load() -> CredentialsResponse? {
        guard let data = KeyStorage.shared.readTURNCredentials() else {
            debugLog("No TURN credentials found in Keychain.")
            return nil
        }

        let decoder = JSONDecoder()
        do {
            return try decoder.decode(CredentialsResponse.self, from: data)
        } catch {
            errorLog("Failed to decode TURN credentials from Keychain: \(error)")
            return nil
        }
    }

    /// Clear TURN credentials from Keychain.
    static func clear() {
        _ = KeyStorage.shared.deleteTURNCredentials()
        debugLog("✅ TURN credentials cleared from Keychain.")
    }
}
