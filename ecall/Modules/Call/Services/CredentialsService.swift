import Foundation

struct CredentialsResponse: Codable {
    var tlsUrl: String?
    var noneTlsUrl: String
    var turnUsername: String
    var turnPassword: String
    // New JWT-based auth for RabbitMQ
    var rabbitmqToken: String?
    var rabbitmqTokenExpiresAt: TimeInterval?
    // Legacy credentials (for backward compatibility during rollout)
    var rabbitmqUsername: String?
    var rabbitmqPassword: String?
}

class CredentialsService {
    static let shared = CredentialsService()
    private init() {}
    
    private let queue = DispatchQueue(label: "com.app.credentials", qos: .utility)
    private var pendingCompletions: [() -> Void] = []
    private var isFetching = false
    private var lastFetchTime: Date?
    private let minRefreshInterval: TimeInterval = 5 // Minimum seconds between fetches

    func fetchCredentials(completion: (() -> Void)? = nil) {
        queue.async { [weak self] in
            guard let self = self else { return }
            
            // Add completion to pending list if provided
            if let completion = completion {
                self.pendingCompletions.append(completion)
            }
            
            // If already fetching, just wait for it to complete
            guard !self.isFetching else { return }
            
            // Rate limiting - don't fetch more than once per minRefreshInterval
            if let lastFetch = self.lastFetchTime,
               Date().timeIntervalSince(lastFetch) < self.minRefreshInterval {
                self.callCompletions()
                return
            }
            
            self.isFetching = true
            
            DispatchQueue.main.async {
                guard let components = URLComponents(string: APIEndpoint.credentials.fullURLString),
                      let url = components.url else {
                    self.queue.async {
                        self.isFetching = false
                        self.callCompletions()
                    }
                    return
                }
                
                APIClient.shared.request(url, method: .get) { [weak self] (result: Result<CredentialsResponse, APIError>) in
                    guard let self = self else { return }
                    
                    self.queue.async {
                        defer {
                            self.lastFetchTime = Date()
                            self.isFetching = false
                            self.callCompletions()
                        }
                        
                        switch result {
                        case .success(let credentials):
                            CredentialStorage.save(credentials: credentials)
                            debugLog("✅ Successfully refreshed credentials")
                        case .failure(let error):
                            errorLog("❌ FetchTurnCredentials API error: \(error)")
                        }
                    }
                }
            }
        }
    }
    
    private func callCompletions() {
        let completions = pendingCompletions
        pendingCompletions.removeAll()
        
        DispatchQueue.main.async {
            completions.forEach { $0() }
        }
    }

    func loadCredentials() -> CredentialsResponse? {
        return CredentialStorage.load()
    }
}
