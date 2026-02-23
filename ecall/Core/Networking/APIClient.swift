import Foundation
import SwiftUI

// MARK: - API Error Definitions

enum APIError: Error {
    case invalidData
    case invalidURL
    case noData
    case decodingError(Error)
    case statusCode(Int)
    case userNotFound
    case serverError
    case unauthorized
    case service(APIServiceError) // structured error from backend
}

// MARK: - API Error Codes
enum APIErrorCode: String {
    case accessTokenExpired = "ErrAccessTokenExpired"      // Access token expired - need refresh
    case expireRefreshToken = "ErrRefreshTokenExpired"     // Refresh token expired - logout
    case terminateSession = "ErrDeviceNotRegistered"         // Session terminated - logout
    case unknown                                           // Unknown error code - Default
    
    init(fromRawValue: String) {
        self = APIErrorCode.init(rawValue: fromRawValue) ?? .unknown
    }
}

// Structured error payloads
struct APIServiceError: Decodable {
    let code: String
    let status: Int
    let title: String
    let detail: String
    
    var errorCode: APIErrorCode {
        return APIErrorCode(fromRawValue: code)
    }
}

struct APIErrorEnvelope: Decodable {
    let error: APIServiceError
}

extension APIError: LocalizedError {
    var content: String {
        switch self {
        case .invalidData:
            return KeyLocalized.invalid_data
        case .invalidURL:
            return KeyLocalized.invalid_url
        case .noData:
            return KeyLocalized.no_data
        case .decodingError(let error):
            let key = KeyLocalized.decoding_error
            return "\(key): \(error.localizedDescription)"
        case .userNotFound:
            return KeyLocalized.user_not_found
        case .serverError:
            return KeyLocalized.server_error
        case .statusCode(let code):
            let key = KeyLocalized.status_code
            return "\(key): \(code)"
        case .unauthorized:
            return KeyLocalized.unauthorized
        case .service(let svc):
            // Try localized by code -> fallback to API message
            return LanguageManager.shared.localizedAPIError(code: svc.code, defaultMessage: svc.title)
        }
    }
}

// MARK: - API Client

enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case delete = "DELETE"
    case patch = "PATCH"
}

class APIClient {
    static let shared = APIClient()
    private let environment = AppEnvironment.current
    
    // MARK: - Retry Configuration
    private let maxRetryAttempts = 3  // Maximum number of retry attempts
    private let baseRetryDelay: TimeInterval = 1.0  // Base delay in seconds (1s, 2s, 4s)
    private let maxRetryDelay: TimeInterval = 10.0  // Maximum delay cap
    
    /// Retryable HTTP status codes (network errors, server errors, but not client errors)
    private let retryableStatusCodes: Set<Int> = [
        408,  // Request Timeout
        429,  // Too Many Requests
        500,  // Internal Server Error
        502,  // Bad Gateway
        503,  // Service Unavailable
        504   // Gateway Timeout
    ]
    
    /// Network error codes that should be retried
    private let retryableErrorCodes: [Int] = [
        NSURLErrorTimedOut,
        NSURLErrorCannotFindHost,
        NSURLErrorCannotConnectToHost,
        NSURLErrorNetworkConnectionLost,
        NSURLErrorNotConnectedToInternet,
        NSURLErrorDNSLookupFailed
    ]

    /// Custom URLSession with SSL pinning delegate and timeout configuration
    private lazy var session: URLSession = {
        let configuration = URLSessionConfiguration.default
        // Set timeout intervals for network requests
        configuration.timeoutIntervalForRequest = 30.0  // 30 seconds for individual request timeout
        configuration.timeoutIntervalForResource = 60.0  // 60 seconds for total resource timeout
        configuration.waitsForConnectivity = true  // Wait for network connectivity
        return URLSession(
            configuration: configuration,
            delegate: SSLPinningManager.shared,
            delegateQueue: nil
        )
    }()

    private init() {}
    
    // MARK: - Retry Helper Methods
    
    /// Calculate exponential backoff delay: baseDelay * 2^attempt, capped at maxDelay
    private func calculateRetryDelay(attempt: Int) -> TimeInterval {
        let delay = baseRetryDelay * pow(2.0, Double(attempt))
        return min(delay, maxRetryDelay)
    }
    
    /// Check if error is retryable
    private func isRetryableError(_ error: Error?, statusCode: Int) -> Bool {
        // Check status code
        if retryableStatusCodes.contains(statusCode) {
            return true
        }
        
        // Check network error codes
        if let nsError = error as NSError? {
            return retryableErrorCodes.contains(nsError.code)
        }
        
        return false
    }
    
    /// Check if we should retry based on attempt count and error type
    private func shouldRetry(attempt: Int, error: Error?, statusCode: Int) -> Bool {
        guard attempt < maxRetryAttempts else {
            return false
        }
        return isRetryableError(error, statusCode: statusCode)
    }

    // MARK: - Async wrappers (Swift Concurrency)

    /// Async/await wrapper for `request(_:completion:)` to gradually migrate the networking layer to Swift Concurrency.
    func requestAsync<T: Decodable>(_ url: URL,
                                    method: HTTPMethod = .get,
                                    body: Data? = nil,
                                    headers: [String: String]? = nil,
                                    auth: Bool = true) async -> Result<T, APIError> {
        await withCheckedContinuation { continuation in
            self.request(url,
                         method: method,
                         body: body,
                         headers: headers,
                         auth: auth) { (result: Result<T, APIError>) in
                continuation.resume(returning: result)
            }
        }
    }

    /// Async/await wrapper for `requestWithHTTPResponse(_:completion:)` to read both body + header
    func requestWithHTTPResponseAsync<T: Decodable>(_ url: URL,
                                                    method: HTTPMethod = .get,
                                                    body: Data? = nil,
                                                    headers: [String: String]? = nil,
                                                    auth: Bool = true) async -> Result<(T, HTTPURLResponse), APIError> {
        await withCheckedContinuation { continuation in
            self.requestWithHTTPResponse(url,
                                         method: method,
                                         body: body,
                                         headers: headers,
                                         auth: auth) { (result: Result<(T, HTTPURLResponse), APIError>) in
                continuation.resume(returning: result)
            }
        }
    }

    /// Generic request for Decodable responses
    func request<T: Decodable>(_ url: URL,
                               method: HTTPMethod = .get,
                               body: Data? = nil,
                               headers: [String: String]? = nil,
                               auth: Bool = true,
                               completion: @escaping (Result<T, APIError>) -> Void) {
        requestWithRetry(url: url,
                        method: method,
                        body: body,
                        headers: headers,
                        auth: auth,
                        retryCount: 0,
                        networkRetryCount: 0,
                        completion: completion)
    }
    
    /// Internal method with retry logic for token refresh and network failures
    private func requestWithRetry<T: Decodable>(url: URL,
                                               method: HTTPMethod,
                                               body: Data?,
                                               headers: [String: String]?,
                                               auth: Bool,
                                               retryCount: Int,
                                               networkRetryCount: Int,
                                               completion: @escaping (Result<T, APIError>) -> Void) {
        let request = createRequest(url: url, method: method, body: body, headers: headers, auth: auth)

        self.session.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                // Network error - check if retryable
                if self.shouldRetry(attempt: networkRetryCount, error: error, statusCode: 0) {
                    let delay = self.calculateRetryDelay(attempt: networkRetryCount)
                    debugLog("🔄 Network error, retrying in \(delay)s (attempt \(networkRetryCount + 1)/\(self.maxRetryAttempts))...")
                    DispatchQueue.global().asyncAfter(deadline: .now() + delay) {
                        self.requestWithRetry(url: url,
                                             method: method,
                                             body: body,
                                             headers: headers,
                                             auth: auth,
                                             retryCount: retryCount,
                                             networkRetryCount: networkRetryCount + 1,
                                             completion: completion)
                    }
                    return
                }
                completion(.failure(.noData))
                return
            }

            // Handle network errors with retry logic
            if let error = error {
                let nsError = error as NSError
                if self.shouldRetry(attempt: networkRetryCount, error: error, statusCode: httpResponse.statusCode) {
                    let delay = self.calculateRetryDelay(attempt: networkRetryCount)
                    debugLog("🔄 Network error (code: \(nsError.code)), retrying in \(delay)s (attempt \(networkRetryCount + 1)/\(self.maxRetryAttempts))...")
                    DispatchQueue.global().asyncAfter(deadline: .now() + delay) {
                        self.requestWithRetry(url: url,
                                             method: method,
                                             body: body,
                                             headers: headers,
                                             auth: auth,
                                             retryCount: retryCount,
                                             networkRetryCount: networkRetryCount + 1,
                                             completion: completion)
                    }
                    return
                }
                completion(.failure(.service(APIServiceError(code: "", status: httpResponse.statusCode, title: error.localizedDescription, detail: ""))))
                return
            }

            guard let data = data else {
                completion(.failure(.noData))
                return
            }

            // Handle 401 - Check error code to decide refresh or logout
            if httpResponse.statusCode == 401 && auth && retryCount == 0 {
                // Parse error code to determine action
                if let errorCode = self.parseErrorCode(from: data) {
                    // Check if should refresh (ErrAccessTokenExpired) or logout
                    if errorCode == .accessTokenExpired {
                        debugLog("🔄 Received 401 with ErrAccessTokenExpired, attempting token refresh...")
                        Task {
                            let refreshResult = await TokenRefreshManager.shared.refreshAccessToken()
                            
                            switch refreshResult {
                            case .success:
                                // Retry request with new token
                                debugLog("✅ Token refreshed, retrying original request...")
                                self.requestWithRetry(url: url,
                                                     method: method,
                                                     body: body,
                                                     headers: headers,
                                                     auth: auth,
                                                     retryCount: retryCount + 1,
                                                     networkRetryCount: 0, // Reset network retry count after token refresh
                                                     completion: completion)
                            case .failure:
                                // Refresh failed -> logout
                                debugLog("❌ Token refresh failed, logging out...")
                                DispatchQueue.main.async {
                                    AppState.shared.logout(remotely: false)
                                }
                                completion(.failure(.unauthorized))
                            }
                        }
                        return
                    } else if self.shouldLogoutForError(code: errorCode) {
                        // Refresh token expired or session terminated -> logout
                        debugLog("❌ Error code \(errorCode.rawValue) requires logout")
                        DispatchQueue.main.async {
                            AppState.shared.logout(remotely: false)
                        }
                        completion(.failure(.unauthorized))
                        return
                    }
                }
            }
            
            // If retry still returns 401 -> logout
            if httpResponse.statusCode == 401 && auth && retryCount > 0 {
                debugLog("❌ Request still failed after refresh, logging out...")
                DispatchQueue.main.async {
                    AppState.shared.logout(remotely: false)
                }
                completion(.failure(.unauthorized))
                return
            }

            // Handle HTTP error status codes with retry logic (but not for 401 which is handled separately)
            if !(200...299).contains(httpResponse.statusCode) && httpResponse.statusCode != 401 {
                // Check if status code is retryable
                if self.shouldRetry(attempt: networkRetryCount, error: nil, statusCode: httpResponse.statusCode) {
                    let delay = self.calculateRetryDelay(attempt: networkRetryCount)
                    debugLog("🔄 HTTP \(httpResponse.statusCode) error, retrying in \(delay)s (attempt \(networkRetryCount + 1)/\(self.maxRetryAttempts))...")
                    DispatchQueue.global().asyncAfter(deadline: .now() + delay) {
                        self.requestWithRetry(url: url,
                                             method: method,
                                             body: body,
                                             headers: headers,
                                             auth: auth,
                                             retryCount: retryCount,
                                             networkRetryCount: networkRetryCount + 1,
                                             completion: completion)
                    }
                    return
                }
                
                // Not retryable or max retries reached - handle error normally
                self.handleErrorResponse(data: data, statusCode: httpResponse.statusCode, shouldCheckRefresh: auth && retryCount == 0, completion: completion)
                return
            }

            self.decodeResponse(data: data, completion: completion)
        }.resume()
    }

    /// Request that returns both decoded body and HTTPURLResponse (to read headers like X-Total-Count)
    func requestWithHTTPResponse<T: Decodable>(_ url: URL,
                                               method: HTTPMethod = .get,
                                               body: Data? = nil,
                                               headers: [String: String]? = nil,
                                               auth: Bool = true,
                                               completion: @escaping (Result<(T, HTTPURLResponse), APIError>) -> Void) {
        requestWithHTTPResponseRetry(url: url,
                                    method: method,
                                    body: body,
                                    headers: headers,
                                    auth: auth,
                                    retryCount: 0,
                                    networkRetryCount: 0,
                                    completion: completion)
    }
    
    /// Internal method with retry logic for token refresh and network failures (HTTPResponse version)
    private func requestWithHTTPResponseRetry<T: Decodable>(url: URL,
                                                           method: HTTPMethod,
                                                           body: Data?,
                                                           headers: [String: String]?,
                                                           auth: Bool,
                                                           retryCount: Int,
                                                           networkRetryCount: Int,
                                                           completion: @escaping (Result<(T, HTTPURLResponse), APIError>) -> Void) {
        let request = createRequest(url: url, method: method, body: body, headers: headers, auth: auth)

        self.session.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                // Network error - check if retryable
                if self.shouldRetry(attempt: networkRetryCount, error: error, statusCode: 0) {
                    let delay = self.calculateRetryDelay(attempt: networkRetryCount)
                    debugLog("🔄 Network error, retrying in \(delay)s (attempt \(networkRetryCount + 1)/\(self.maxRetryAttempts))...")
                    DispatchQueue.global().asyncAfter(deadline: .now() + delay) {
                        self.requestWithHTTPResponseRetry(url: url,
                                                         method: method,
                                                         body: body,
                                                         headers: headers,
                                                         auth: auth,
                                                         retryCount: retryCount,
                                                         networkRetryCount: networkRetryCount + 1,
                                                         completion: completion)
                    }
                    return
                }
                completion(.failure(.noData))
                return
            }

            // Handle network errors with retry logic
            if let error = error {
                let nsError = error as NSError
                if self.shouldRetry(attempt: networkRetryCount, error: error, statusCode: httpResponse.statusCode) {
                    let delay = self.calculateRetryDelay(attempt: networkRetryCount)
                    debugLog("🔄 Network error (code: \(nsError.code)), retrying in \(delay)s (attempt \(networkRetryCount + 1)/\(self.maxRetryAttempts))...")
                    DispatchQueue.global().asyncAfter(deadline: .now() + delay) {
                        self.requestWithHTTPResponseRetry(url: url,
                                                         method: method,
                                                         body: body,
                                                         headers: headers,
                                                         auth: auth,
                                                         retryCount: retryCount,
                                                         networkRetryCount: networkRetryCount + 1,
                                                         completion: completion)
                    }
                    return
                }
                completion(.failure(.service(APIServiceError(code: "", status: httpResponse.statusCode, title: error.localizedDescription, detail: ""))))
                return
            }

            guard let data = data else {
                completion(.failure(.noData))
                return
            }

            // Handle 401 - Check error code to decide refresh or logout
            if httpResponse.statusCode == 401 && auth && retryCount == 0 {
                // Parse error code to determine action
                if let errorCode = self.parseErrorCode(from: data) {
                    // Check if should refresh (ErrAccessTokenExpired) or logout
                    if errorCode == .accessTokenExpired {
                        debugLog("🔄 Received 401 with ErrAccessTokenExpired, attempting token refresh...")
                        Task {
                            let refreshResult = await TokenRefreshManager.shared.refreshAccessToken()
                            
                            switch refreshResult {
                            case .success:
                                // Retry request with new token
                                debugLog("✅ Token refreshed, retrying original request...")
                                self.requestWithHTTPResponseRetry(url: url,
                                                                 method: method,
                                                                 body: body,
                                                                 headers: headers,
                                                                 auth: auth,
                                                                 retryCount: retryCount + 1,
                                                                 networkRetryCount: 0, // Reset network retry count after token refresh
                                                                 completion: completion)
                            case .failure:
                                // Refresh failed -> logout
                                debugLog("❌ Token refresh failed, logging out...")
                                DispatchQueue.main.async {
                                    AppState.shared.logout(remotely: false)
                                }
                                completion(.failure(.unauthorized))
                            }
                        }
                        return
                    } else if self.shouldLogoutForError(code: errorCode) {
                        // Refresh token expired or session terminated -> logout
                        debugLog("❌ Error code \(errorCode.rawValue) requires logout")
                        DispatchQueue.main.async {
                            AppState.shared.logout(remotely: false)
                        }
                        completion(.failure(.unauthorized))
                        return
                    }
                }
            }
            
            // If retry still returns 401 -> logout
            if httpResponse.statusCode == 401 && auth && retryCount > 0 {
                debugLog("❌ Request still failed after refresh, logging out...")
                DispatchQueue.main.async {
                    AppState.shared.logout(remotely: false)
                }
                completion(.failure(.unauthorized))
                return
            }

            // Handle HTTP error status codes with retry logic (but not for 401 which is handled separately)
            if !(200...299).contains(httpResponse.statusCode) && httpResponse.statusCode != 401 {
                // Check if status code is retryable
                if self.shouldRetry(attempt: networkRetryCount, error: nil, statusCode: httpResponse.statusCode) {
                    let delay = self.calculateRetryDelay(attempt: networkRetryCount)
                    debugLog("🔄 HTTP \(httpResponse.statusCode) error, retrying in \(delay)s (attempt \(networkRetryCount + 1)/\(self.maxRetryAttempts))...")
                    DispatchQueue.global().asyncAfter(deadline: .now() + delay) {
                        self.requestWithHTTPResponseRetry(url: url,
                                                         method: method,
                                                         body: body,
                                                         headers: headers,
                                                         auth: auth,
                                                         retryCount: retryCount,
                                                         networkRetryCount: networkRetryCount + 1,
                                                         completion: completion)
                    }
                    return
                }
                
                // Not retryable or max retries reached - handle error normally
                let error = self.decodeAPIError(from: data, statusCode: httpResponse.statusCode, shouldCheckRefresh: auth && retryCount == 0)
                completion(.failure(error))
                return
            }

            do {
                let decoder = self.createJSONDecoder()
                let decoded = try decoder.decode(T.self, from: data)
                completion(.success((decoded, httpResponse)))
            } catch {
                completion(.failure(.decodingError(error)))
            }
        }.resume()
    }

    private func createRequest(url: URL, method: HTTPMethod, body: Data?, headers: [String: String]?, auth: Bool) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = body
        applySecurityHeaders(to: &request)
        if auth {
            request.setValue("Bearer \(KeyStorage.shared.readAccessToken() ?? "")", forHTTPHeaderField: "Authorization")
        }
        headers?.forEach { request.setValue($1, forHTTPHeaderField: $0) }
        return request
    }

    private func handleResponse<T: Decodable>(data: Data?, response: URLResponse?, error: Error?, completion: @escaping (Result<T, APIError>) -> Void) {
        guard let httpResponse = response as? HTTPURLResponse else {
            completion(.failure(.noData))
            return
        }

        if let error = error {
            completion(.failure(.service(APIServiceError(code: "", status: httpResponse.statusCode, title: error.localizedDescription, detail: ""))))
            return
        }

        guard let data = data else {
            completion(.failure(.noData))
            return
        }

        if !(200...299).contains(httpResponse.statusCode) {
            handleErrorResponse(data: data, statusCode: httpResponse.statusCode, shouldCheckRefresh: false, completion: completion)
            return
        }

        decodeResponse(data: data, completion: completion)
    }

    private func handleErrorResponse<T: Decodable>(data: Data, statusCode: Int, shouldCheckRefresh: Bool = false, completion: @escaping (Result<T, APIError>) -> Void) {
        let error = decodeAPIError(from: data, statusCode: statusCode, shouldCheckRefresh: shouldCheckRefresh)
        completion(.failure(error))
    }

    private func decodeResponse<T: Decodable>(data: Data, completion: @escaping (Result<T, APIError>) -> Void) {
        do {
            let decoder = createJSONDecoder()
            let decoded = try decoder.decode(T.self, from: data)
            completion(.success(decoded))
        } catch {
            completion(.failure(.decodingError(error)))
        }
    }

    private func createJSONDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        let iso8601WithFraction = DateFormatters.iso8601Fractional
        let iso8601NoFraction = DateFormatters.iso8601
        let fallbackFormatter: DateFormatter = {
            let f = DateFormatter()
            f.dateFormat = "yyyy-MM-dd HH:mm:ss"
            f.locale = LanguageManager.shared.locale
            return f
        }()

        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let str = try container.decode(String.self)
            if let d = iso8601WithFraction.date(from: str) { return d }
            if let d = iso8601NoFraction.date(from: str) { return d }
            if let d = fallbackFormatter.date(from: str) { return d }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid date format: \(str)")
        }
        return decoder
    }

    /// Parse error code from response data
    private func parseErrorCode(from data: Data) -> APIErrorCode? {
        // Try structured error first: { "error": { code, status, message, ... } }
        if let envelope = try? JSONDecoder().decode(APIErrorEnvelope.self, from: data) {
            return envelope.error.errorCode
        }
        return nil
    }
    
    /// Check if error requires logout (not refresh)
    private func shouldLogoutForError(code: APIErrorCode) -> Bool {
        switch code {
        case .expireRefreshToken, .terminateSession:
            return true
        case .accessTokenExpired:
            return false // Should refresh instead
        case .unknown:
            return true // Unknown error, default to logout for safety
        }
    }
    
    /// Decode API errors consistently across all requests to avoid logic loops.
    private func decodeAPIError(from data: Data, statusCode: Int, shouldCheckRefresh: Bool = false) -> APIError {
        // Try structured error first: { "error": { code, status, message, ... } }
        if let envelope = try? JSONDecoder().decode(APIErrorEnvelope.self, from: data) {
            let errorCode = envelope.error.errorCode
            
            // Handle 401 with specific error codes
            if envelope.error.status == 401 || statusCode == 401 {
                // If shouldCheckRefresh is true, don't logout here - let request handler decide
                if shouldCheckRefresh {
                    // Check error code to decide action
                    if errorCode == .accessTokenExpired {
                        // Access token expired - return error but don't logout (will refresh)
                        return .service(envelope.error)
                    } else if shouldLogoutForError(code: errorCode) {
                        // Refresh token expired or session terminated - logout
                        DispatchQueue.main.async { AppState.shared.logout(remotely: false) }
                        return .unauthorized
                    }
                }
                // Default: logout for 401
                DispatchQueue.main.async { AppState.shared.logout(remotely: false) }
                return .unauthorized
            }
            return .service(envelope.error)
        }

        // Fallback: simple { "error": "msg" } or { "status": "msg" }
        if let dict = try? JSONDecoder().decode([String: String].self, from: data),
           let msg = dict["error"] ?? dict["status"] {
            if statusCode == 401 {
                // For 401 without structured error, logout by default
                if !shouldCheckRefresh {
                    DispatchQueue.main.async { AppState.shared.logout(remotely: false) }
                }
                return .unauthorized
            }
            let serviceError = APIServiceError(code: "",
                                               status: statusCode,
                                               title: msg,
                                               detail: "")
            return .service(serviceError)
        }

        switch statusCode {
        case 401:
            if !shouldCheckRefresh {
                DispatchQueue.main.async { AppState.shared.logout(remotely: false) }
            }
            return .unauthorized
        case 404:
            return .userNotFound
        case 500:
            return .serverError
        default:
            return .statusCode(statusCode)
        }
    }

    /// Raw data request
    func request(_ url: URL,
                 method: String = "GET",
                 body: Data? = nil,
                 headers: [String: String]? = nil,
                 completion: @escaping (Result<Data, APIError>) -> Void) {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.httpBody = body
        applySecurityHeaders(to: &request)
        request.setValue("Bearer \(KeyStorage.shared.readAccessToken() ?? "")", forHTTPHeaderField: "Authorization")
        headers?.forEach { request.setValue($1, forHTTPHeaderField: $0) }

        self.session.dataTask(with: request) { data, response, error in
            guard let httpResponse = response as? HTTPURLResponse else {
                completion(.failure(.noData))
                return
            }
            if let error = error {
                completion(.failure(.service(APIServiceError(code: "", status: httpResponse.statusCode, title: error.localizedDescription, detail: ""))))
                return
            }

            // Handle non-2xx status codes
            guard (200...299).contains(httpResponse.statusCode) else {
                guard let data = data else {
                    completion(.failure(.noData))
                    return
                }
                
                // Handle 401 - Check error code to decide refresh or logout
                if httpResponse.statusCode == 401 {
                    // Parse error code to determine action
                    if let errorCode = self.parseErrorCode(from: data) {
                        // Check if should refresh (ErrAccessTokenExpired) or logout
                        if errorCode == .accessTokenExpired {
                            debugLog("🔄 Received 401 with ErrAccessTokenExpired in raw request, attempting token refresh...")
                            Task { [weak self] in
                                guard let self = self else { return }
                                let refreshResult = await TokenRefreshManager.shared.refreshAccessToken()
                                
                                switch refreshResult {
                                case .success:
                                    // Retry request with new token
                                    debugLog("✅ Token refreshed, retrying original raw request...")
                                    self.request(url, method: method, body: body, headers: headers, completion: completion)
                                case .failure:
                                    // Refresh failed -> logout
                                    debugLog("❌ Token refresh failed, logging out...")
                                    DispatchQueue.main.async {
                                        AppState.shared.logout(remotely: false)
                                    }
                                    completion(.failure(.unauthorized))
                                }
                            }
                            return
                        } else if self.shouldLogoutForError(code: errorCode) {
                            // Refresh token expired or session terminated -> logout
                            debugLog("❌ Error code \(errorCode.rawValue) requires logout")
                            DispatchQueue.main.async {
                                AppState.shared.logout(remotely: false)
                            }
                            completion(.failure(.unauthorized))
                            return
                        }
                    }
                    
                    // Default: logout for 401 without recognized error code
                    DispatchQueue.main.async { AppState.shared.logout(remotely: false) }
                }
                completion(.failure(.statusCode(httpResponse.statusCode)))
                return
            }
            
            guard let data = data else {
                completion(.failure(.noData))
                return
            }
            completion(.success(data))
        }.resume()
    }
}

// MARK: - Private helpers
private extension APIClient {
    func applySecurityHeaders(to request: inout URLRequest) {
        let timestamp = String(UInt64(Date().timeIntervalSince1970))
        let method = request.httpMethod ?? HTTPMethod.get.rawValue
        let body = request.httpBody.flatMap { String(data: $0, encoding: .utf8) } ?? ""
        let path = {
            let value = request.url?.path ?? ""
            return value.isEmpty ? "/" : value
        }()

        let raw = environment.appApiId + method + path + body + timestamp
        let signature = raw.hmacSHA256(key: environment.appApiHash)

        request.setValue(environment.appApiId, forHTTPHeaderField: "X-Api-Id")
        request.setValue(signature, forHTTPHeaderField: "X-Signature")
        request.setValue(timestamp, forHTTPHeaderField: "X-Nonce")
    }
}
