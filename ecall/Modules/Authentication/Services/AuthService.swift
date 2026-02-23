import Foundation
import GoogleSignIn

class AuthService {
    func login(email: String,
               phoneNumber: String,
               displayName: String,
               verified: Bool) async -> Result<AuthResponse, APIError> {
        guard let components = URLComponents(string: APIEndpoint.login.fullURLString) else {
            return .failure(.invalidURL)
        }

        var body: [String: Any] = [
            "email": email,
            "phoneNumber": phoneNumber,
            "displayName": displayName,
            "verified": verified
        ]

        // Add completeUser fields if provided
        body.merge(makeCompleteUserPayload()) { _, new in new }

        guard let httpBody = try? JSONSerialization.data(withJSONObject: body),
              let url = components.url else {
            return .failure(.invalidURL)
        }

        return await APIClient.shared.requestAsync(url, method: .post, body: httpBody)
    }

    func appleLogin(code: String,
                    appleIdToken: String?,
                    displayName: String) async -> Result<AuthResponse, APIError> {
        guard let components = URLComponents(string: APIEndpoint.appleLogin.fullURLString) else {
            return .failure(.invalidURL)
        }

        var body: [String: Any] = [
            "code": code,
            "displayName": displayName
        ]
        if let appleIdToken {
            body["appleIdToken"] = appleIdToken
        }

        // Add completeUser fields if provided
        body.merge(makeCompleteUserPayload()) { _, new in new }

        guard let httpBody = try? JSONSerialization.data(withJSONObject: body),
              let url = components.url else {
            return .failure(.invalidURL)
        }

        return await APIClient.shared.requestAsync(url, method: .post, body: httpBody)
    }

    func verifyUser(email: String,
                    phoneNumber: String,
                    code: String,
                    type: IdentityType) async -> Result<String, APIError> {
        guard let components = URLComponents(string: APIEndpoint.verifyUser.fullURLString) else {
            return .failure(.invalidURL)
        }

        var body: [String: String] = [:]
        body["code"] = code

        switch type {
        case .email:
            body["email"] = email
        case .phoneNumber:
            body["phoneNumber"] = phoneNumber
        case .apple:
            return .failure(.invalidData)
        }

        guard let httpBody = try? JSONSerialization.data(withJSONObject: body),
              let url = components.url else {
            return .failure(.invalidURL)
        }

        return await APIClient.shared.requestAsync(url, method: .post, body: httpBody)
    }

    func verifyLogin(email: String,
                     phoneNumber: String,
                     code: String,
                     type: IdentityType) async -> Result<VerifyResponse, APIError> {
        guard let components = URLComponents(string: APIEndpoint.verifyLogin.fullURLString) else {
            return .failure(.invalidURL)
        }

        var body: [String: String] = [:]
        body["code"] = code

        // Add completeUser fields if provided
        body.merge(makeCompleteUserPayload()) { _, new in new }

        switch type {
        case .email:
            body["email"] = email
        case .phoneNumber:
            body["phoneNumber"] = phoneNumber
        case .apple:
            return .failure(.invalidData)
        }

        guard let httpBody = try? JSONSerialization.data(withJSONObject: body),
              let url = components.url else {
            return .failure(.invalidURL)
        }

        return await APIClient.shared.requestAsync(url, method: .post, body: httpBody)
    }

    func resendOTP(email: String,
                   phoneNumber: String) async -> Result<String, APIError> {
        guard let components = URLComponents(string: APIEndpoint.resendOTP.fullURLString) else {
            return .failure(.invalidURL)
        }

        let body: [String: String] = [
            "email": email,
            "phoneNumber": phoneNumber
        ]

        guard let httpBody = try? JSONSerialization.data(withJSONObject: body),
              let url = components.url else {
            return .failure(.invalidURL)
        }

        return await APIClient.shared.requestAsync(url, method: .post, body: httpBody)
    }

    func logout(completion: @escaping (Result<String, APIError>) -> Void) {
        guard let components = URLComponents(string: APIEndpoint.logout.fullURLString) else {
            return
        }
        guard let url = components.url else {
            completion(.failure(.invalidURL))
            return
        }
        APIClient.shared.request(url, method: .post) { (result: Result<String, APIError>) in
            switch result {
            case .success(let response):
                completion(.success((response)))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    func terminateSession(deviceId: Int, completion: @escaping (Result<String, APIError>) -> Void) {
        guard let components = URLComponents(string: APIEndpoint.terminateSession(deviceId: "\(deviceId)").fullURLString) else {
            return
        }
        guard let url = components.url else {
            completion(.failure(.invalidURL))
            return
        }
        APIClient.shared.request(url, method: .post) { (result: Result<String, APIError>) in
            switch result {
            case .success(let response):
                completion(.success(response))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    func terminateOthers(completion: @escaping (Result<String, APIError>) -> Void) {
        guard let components = URLComponents(string: APIEndpoint.terminateOthers.fullURLString) else {
            return
        }
        guard let url = components.url else {
            completion(.failure(.invalidURL))
            return
        }
        APIClient.shared.request(url, method: .post) { (result: Result<String, APIError>) in
            switch result {
            case .success(let response):
                completion(.success(response))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    func googleSignOn(from viewController: UIViewController, completion: @escaping (Result<GIDGoogleUser, Error>) -> Void) {
        let config = GIDConfiguration(clientID: Endpoints.shared.googleClientID)
        GIDSignIn.sharedInstance.configuration = config

        GIDSignIn.sharedInstance.signIn(withPresenting: viewController) { result, error in
            if let error = error {
                completion(.failure(error))
                return
            }

            guard let user = result?.user else {
                let err = NSError(domain: "GoogleSignIn", code: -1, userInfo: [NSLocalizedDescriptionKey: KeyLocalized.user_not_found])
                completion(.failure(err))
                return
            }

            completion(.success(user))
        }
    }

    enum RegistrationError: Error, LocalizedError {
        case registrationFailed

        var content: String? {
            "Registration failed. Please try again."
        }
    }

    enum LoginError: Error, LocalizedError {
        case loginFailed

        var content: String? {
            "Login failed. Please try again."
        }
    }

    // MARK: - Private helpers

    /// Shared payload containing device information and cryptographic keys, reused across authentication APIs.
    private func makeCompleteUserPayload() -> [String: String] {
        [
            "publicKey": KeyStorage.shared.readPublicKey() ?? "",
            "voipToken": KeyStorage.shared.readVoipToken() ?? "",
            "apnsToken": KeyStorage.shared.readApnsToken() ?? "",
            "deviceName": KeyStorage.shared.readDeviceName() ?? "",
            "systemName": KeyStorage.shared.readSystemName() ?? "",
            "systemVersion": KeyStorage.shared.readSystemVersion() ?? "",
            "identifier": KeyStorage.shared.readIdentifier() ?? ""
        ]
    }
}
