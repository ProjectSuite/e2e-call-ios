import Foundation

class VoipService {
    static let shared = VoipService()
    private init() {}

    // Registers voip/apns tokens with backend (and public key if changed)
    func registerDeviceTokens(voipToken: String?, apnsToken: String?) {
        let url = APIEndpoint.registerDevice.fullURL

        var bodyDict: [String: String] = [:]
        if let voipToken, !voipToken.isEmpty {
            bodyDict["voipToken"] = voipToken
        }
        if let apnsToken, !apnsToken.isEmpty {
            bodyDict["apnsToken"] = apnsToken
        }

        // IMPORTANT: Also send public key to ensure backend has latest key
        // This is critical for P-256 migration where keys may be regenerated
        if let publicKey = KeyStorage.shared.readPublicKey(), !publicKey.isEmpty {
            bodyDict["publicKey"] = publicKey
        }
        if let publicKeyHash = KeyStorage.shared.readPublicKeyHash(), !publicKeyHash.isEmpty {
            bodyDict["publicKeyHash"] = publicKeyHash
        }

        guard !bodyDict.isEmpty,
              let bodyData = try? JSONSerialization.data(withJSONObject: bodyDict, options: []) else {
            let serializationError = NSError(domain: "Serialization", code: -1, userInfo: nil)
            debugLog("Error encoding JSON: \(serializationError)")
            return
        }

        APIClient.shared.request(url,
                                 method: .post,
                                 body: bodyData,
                                 auth: true) { (result: Result<VoipRegisterResponse, APIError>) in
            switch result {
            case .success:
                debugLog("Device tokens registered successfully.")
            case .failure(let error):
                errorLog(error.content)
            }
        }
    }

    // Backward compatible single-voip entry point.
    func registerVoIPToken(_ voipToken: String) {
        registerDeviceTokens(voipToken: voipToken, apnsToken: KeyStorage.shared.readApnsToken())
    }
}
