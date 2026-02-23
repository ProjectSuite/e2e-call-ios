import Foundation

/// Manages token refresh operations with thread safety to prevent multiple simultaneous refresh requests
actor TokenRefreshState {
    var isRefreshing = false
    var refreshQueue: [(Result<Void, APIError>) -> Void] = []
    
    func addToQueue(_ continuation: @escaping (Result<Void, APIError>) -> Void) {
        refreshQueue.append(continuation)
    }
    
    func startRefreshing() -> Bool {
        if isRefreshing {
            return false
        }
        isRefreshing = true
        return true
    }
    
    func finishRefreshing(error: APIError?) -> [(Result<Void, APIError>) -> Void] {
        isRefreshing = false
        let queue = refreshQueue
        refreshQueue.removeAll()
        return queue
    }
}

/// Manages token refresh operations with thread safety to prevent multiple simultaneous refresh requests
class TokenRefreshManager {
    static let shared = TokenRefreshManager()
    
    private let state = TokenRefreshState()
    
    private init() {}
    
    /// Refresh access token using refresh token
    /// - Returns: Result indicating success or failure
    func refreshAccessToken() async -> Result<Void, APIError> {
        // Check if already refreshing
        let shouldStart = await state.startRefreshing()
        
        if !shouldStart {
            // Wait for existing refresh to complete
            return await withCheckedContinuation { continuation in
                Task {
                    await state.addToQueue { result in
                        continuation.resume(returning: result)
                    }
                }
            }
        }
        
        // Check if refresh token exists
        guard let refreshToken = KeyStorage.shared.readRefreshToken(), !refreshToken.isEmpty else {
            await finishRefresh(error: .unauthorized)
            debugLog("❌ No refresh token found, logout required")
            DispatchQueue.main.async {
                AppState.shared.logout(remotely: false)
            }
            return .failure(.unauthorized)
        }
        
        // Call refresh token API
        guard let url = URL(string: APIEndpoint.refreshToken.fullURLString) else {
            let error = APIError.invalidURL
            await finishRefresh(error: error)
            return .failure(error)
        }
        
        let body: [String: String] = ["refreshToken": refreshToken]
        guard let httpBody = try? JSONSerialization.data(withJSONObject: body) else {
            let error = APIError.invalidData
            await finishRefresh(error: error)
            return .failure(error)
        }
        
        debugLog("🔄 Refreshing access token...")
        
        // Call refresh token API without auth header
        let result: Result<RefreshTokenResponse, APIError> = await APIClient.shared.requestAsync(url,
                                                                                                    method: .post,
                                                                                                    body: httpBody,
                                                                                                    headers: nil,
                                                                                                    auth: false)
        
        switch result {
        case .success(let response):
            // Update access token
            if let newAccessToken = response.accessToken {
                KeyStorage.shared.storeAccessToken(newAccessToken)
                debugLog("✅ Access token refreshed successfully")
            } else {
                debugLog("⚠️ Refresh response missing accessToken")
            }
            
            if let newRefreshToken = response.refreshToken, !newRefreshToken.isEmpty {
                _ = KeyStorage.shared.storeRefreshToken(newRefreshToken)
                debugLog("✅ Refresh token updated successfully")
            } else {
                debugLog("⚠️ Refresh response missing refreshToken (keeping existing one)")
            }
            
            await finishRefresh(error: nil)
            return .success(())
            
        case .failure(let error):
            // Refresh token also expired or invalid -> logout
            debugLog("❌ Refresh token failed: \(error.content)")
            if case .unauthorized = error {
                DispatchQueue.main.async {
                    AppState.shared.logout(remotely: false)
                }
            }
            await finishRefresh(error: error)
            return .failure(error)
        }
    }
    
    private func finishRefresh(error: APIError?) async {
        let queue = await state.finishRefreshing(error: error)
        
        // Notify all waiting requests
        let result: Result<Void, APIError> = error.map { .failure($0) } ?? .success(())
        queue.forEach { $0(result) }
    }
}
