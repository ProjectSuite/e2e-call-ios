import Foundation

struct PublicKeyResponse: Codable {
    var publicKey: String
}

struct PublicKeysResponse: Codable {
    var publicKeys: [String: String]
}

struct UserInfo: Codable, Hashable {
    var id: UInt64
    var deviceId: UInt64
    var displayName: String
    var email: String
    var phoneNumber: String
}

struct UserInfoResponse: Codable {
    var user: UserInfo
}

class UserService {
    static let shared = UserService()

    func fetchCurrenrUser(completion: @escaping (UserInfo?) -> Void) {
        guard let components = URLComponents(string: APIEndpoint.currentUser.fullURLString) else {
            completion(nil)
            return
        }
        guard let url = components.url else {
            completion(nil)
            return
        }
        APIClient.shared.request(url, method: .get) { (result: Result<UserInfoResponse, APIError>) in
            switch result {
            case .success(let response):
                completion(response.user)
            case .failure:
                completion(nil)
            }
        }
    }

    func fetchPublicKeys(
        userIds: [UInt64],
        completion: @escaping (Result<[String: String], Error>) -> Void
    ) {
        // 1) Build URL
        guard let url = URL(string: APIEndpoint.publicKeys.fullURLString) else {
            completion(.failure(URLError(.badURL)))
            return
        }

        // 2) Create POST request with JSON body
        let body = ["userIds": userIds]
        let httpBody = try? JSONSerialization.data(withJSONObject: body)

        // 3) Fire request
        APIClient.shared.request(url, method: .post, body: httpBody) { (result: Result<PublicKeysResponse, APIError>) in
            switch result {
            case .success(let response):
                completion(.success(response.publicKeys))
            case .failure(let apiError):
                completion(.failure(apiError))
            }
        }
    }

    func updateUser(displayName: String, email: String? = nil, phoneNumber: String? = nil, completion: @escaping (UserInfo?, APIError?) -> Void) {
        let url = APIEndpoint.updateUser.fullURL

        var bodyDict: [String: String] = [:]

        bodyDict["displayName"] = displayName
        bodyDict["voipToken"] = KeyStorage.shared.readVoipToken() ?? ""
        bodyDict["apnsToken"] = KeyStorage.shared.readApnsToken() ?? ""

        if let data = email {
            bodyDict["email"] = data
        }

        if let data = phoneNumber {
            bodyDict["phoneNumber"] = data
        }

        guard let bodyData = try? JSONSerialization.data(withJSONObject: bodyDict, options: []) else {
            let serializationError = NSError(domain: "Serialization", code: -1, userInfo: nil)
            debugLog("Error encoding JSON: \(serializationError)")
            completion(nil, .invalidData)
            return
        }

        APIClient.shared.request(url,
                                 method: .patch,
                                 body: bodyData,
                                 auth: true) { (result: Result<UserInfoResponse, APIError>) in
            switch result {
            case .success(let response):
                completion(response.user, nil)
                debugLog("Update user info successfully.")
            case .failure(let error):
                errorLog(error.content)
                completion(nil, error)
            }
        }
    }

    // MARK: - Delete Account

    func deleteAccount() async -> Result<EmptyResponse, APIError> {
        let url = APIEndpoint.deleteAccount.fullURL
        return await APIClient.shared.requestAsync(url, method: .delete)
    }

    func cancelDeleteAccount() async -> Result<EmptyResponse, APIError> {
        let url = APIEndpoint.cancelDeleteAccount.fullURL
        return await APIClient.shared.requestAsync(url, method: .post)
    }
}
