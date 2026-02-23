import Foundation
import Security
import CryptoKit

/// SSL Public Key Pinning Manager to prevent MITM attacks
/// Validates server certificates by comparing public key hashes against pinned values
final class SSLPinningManager: NSObject, URLSessionDelegate {
    static let shared = SSLPinningManager()
    
    // MARK: - Public Key Hashes (SHA-256)
    // These hashes are HARDCODED for security - they cannot be changed at runtime
    // Extract hashes using the extraction script or from app debug logs
    
    /// Service-specific pinned keys structure
    /// Separates hashes by service type (API, Socket/STOMP, Janus) for clarity
    private struct ServicePinnedKeys {
        let api: Set<String>      // Hashes for REST API (HTTPS)
        let socket: Set<String>   // Hashes for STOMP WebSocket (WSS)
        let janus: Set<String>    // Hashes for Janus WebSocket (WSS)
    }
    
    /// Public key hashes for Staging environment
    /// Organized by service type: API, Socket (STOMP), and Janus
    /// TODO: Add your server's public key SHA-256 hashes here
    /// Use the debug log output "COPY THIS HASH FOR CERTIFICATE" to extract hashes
    private let stagingPinnedKeys: ServicePinnedKeys = ServicePinnedKeys(
        api: [
            // "your_staging_api_public_key_sha256_hash_here"
        ],
        socket: [
            // "your_staging_socket_public_key_sha256_hash_here"
        ],
        janus: [
            // "your_staging_janus_public_key_sha256_hash_here"
        ]
    )
    
    /// Public key hashes for Production environment
    /// Organized by service type: API, Socket (STOMP), and Janus
    /// TODO: Add your server's public key SHA-256 hashes here
    /// Use the debug log output "COPY THIS HASH FOR CERTIFICATE" to extract hashes
    private let productionPinnedKeys: ServicePinnedKeys = ServicePinnedKeys(
        api: [
            "your_production_api_public_key_sha256_hash_here"
        ],
        socket: [
            "your_production_socket_public_key_sha256_hash_here"
        ],
        janus: [
            "your_production_janus_public_key_sha256_hash_here"
        ]
    )
    
    /// Dynamically build domain-to-hash mapping based on current environment
    /// Extracts hostnames from Endpoints URLs and maps them to service-specific hardcoded hashes
    private var pinnedHashes: [String: Set<String>] {
        let environment = AppEnvironment.current.type
        let serviceKeys: ServicePinnedKeys
        
        switch environment {
        case .staging:
            serviceKeys = stagingPinnedKeys
        case .production:
            serviceKeys = productionPinnedKeys
        case .dev:
            return [:] // No pinning for dev
        }
        
        // Build dynamic mapping: extract hostnames from Endpoints and map to service-specific hashes
        var dynamicMapping: [String: Set<String>] = [:]
        
        // Map API hostname to API hashes
        if let apiHostname = extractHostname(from: Endpoints.shared.baseURL),
           !serviceKeys.api.isEmpty {
            dynamicMapping[apiHostname, default: []].formUnion(serviceKeys.api)
        }
        
        // Map Socket/STOMP hostname to Socket hashes (or reuse API hashes if socket is empty)
        if let socketHostname = extractHostname(from: Endpoints.shared.baseSocketURL) {
            if !serviceKeys.socket.isEmpty {
                // Socket has its own hashes
                dynamicMapping[socketHostname, default: []].formUnion(serviceKeys.socket)
            } else {
                // Socket uses same certificate as API - reuse API hashes
                if extractHostname(from: Endpoints.shared.baseURL) != nil,
                   !serviceKeys.api.isEmpty {
                    dynamicMapping[socketHostname, default: []].formUnion(serviceKeys.api)
                }
            }
        }
        
        // Map Janus hostname to Janus hashes (or reuse API hashes if janus is empty)
        if let janusHostname = extractHostname(from: Endpoints.shared.baseJanusSocketURL) {
            if !serviceKeys.janus.isEmpty {
                // Janus has its own hashes
                dynamicMapping[janusHostname, default: []].formUnion(serviceKeys.janus)
            } else {
                // Janus uses same certificate as API - reuse API hashes
                if extractHostname(from: Endpoints.shared.baseURL) != nil,
                   !serviceKeys.api.isEmpty {
                    dynamicMapping[janusHostname, default: []].formUnion(serviceKeys.api)
                }
            }
        }
        
        return dynamicMapping
    }
    
    private override init() {
        super.init()
    }
    
    // MARK: - Helper Methods
    
    /// Extract hostname from URL string (removes protocol, port, and path)
    /// Example: "https://api.example.com:443/path" -> "api.example.com"
    private func extractHostname(from urlString: String) -> String? {
        guard let url = URL(string: urlString) else {
            return nil
        }
        
        // Use host property which automatically handles port removal
        return url.host
    }
    
    // MARK: - URLSessionDelegate
    
    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        // Only validate server trust
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
              let serverTrust = challenge.protectionSpace.serverTrust else {
            completionHandler(.performDefaultHandling, nil)
            return
        }
        
        // Extract hostname from challenge
        let hostname = challenge.protectionSpace.host
        
        // Skip pinning for Dev environment
        let environment = AppEnvironment.current.type
        if environment == .dev {
            debugLog("🔓 Skipping pinning for Dev environment: \(hostname)")
            let credential = URLCredential(trust: serverTrust)
            completionHandler(.useCredential, credential)
            return
        }
        
        // Validate public key for Staging/Production
        if validatePublicKey(serverTrust: serverTrust, hostname: hostname, environment: environment) {
            let credential = URLCredential(trust: serverTrust)
            completionHandler(.useCredential, credential)
        } else {
            // SSL pinning failed - possible MITM attack
            let msg = "🚨 [CRITICAL] SSL Pinning failed for \(hostname) in \(environment.rawValue) - possible MITM attack detected!"
            errorLog(msg)
            completionHandler(.cancelAuthenticationChallenge, nil)
        }
    }
    
    // MARK: - Private Methods
    
    /// Validate server public key against pinned hashes
    private func validatePublicKey(serverTrust: SecTrust, hostname: String, environment: EnvironmentType) -> Bool {
        // Get dynamic pinned hashes for current environment (built from Endpoints)
        let pinnedHashes = self.pinnedHashes
        
        // Check if we have pinned hashes for this hostname
        guard let expectedHashes = pinnedHashes[hostname], !expectedHashes.isEmpty else {
            // No pinned hash for this hostname - log warning but allow connection
            let msg = "No pinned hash found for \(hostname) in \(environment.rawValue)"
            errorLog(msg)
            return false
        }
        
        // Validate certificate chain using modern API (iOS 15+)
        guard let certificateChain = SecTrustCopyCertificateChain(serverTrust) as? [SecCertificate] else {
            errorLog("Failed to get certificate chain for \(hostname)")
            return false
        }

        for (index, certificate) in certificateChain.prefix(3).enumerated() {
            // Extract public key from certificate
            guard let publicKey = SecCertificateCopyKey(certificate) else {
                warningLog("Failed to extract public key from certificate \(index) for \(hostname)")
                continue
            }

            // Export public key data
            guard let publicKeyData = SecKeyCopyExternalRepresentation(publicKey, nil) as Data? else {
                warningLog("Failed to export public key data from certificate \(index) for \(hostname)")
                continue
            }

            // Hash public key with SHA-256 (lowercase hex format)
            let publicKeyHash = SHA256.hash(data: publicKeyData)
            let publicKeyHashString = publicKeyHash.map { String(format: "%02x", $0) }.joined()
            
            // Debug: Log each certificate hash for troubleshooting
            let isLeaf = index == 0
            debugLog("🔍 Certificate \(index) (\(isLeaf ? "LEAF" : "INTERMEDIATE")) hash: \(publicKeyHashString)")
            
            // Check if this hash matches any expected hash
            if expectedHashes.contains(publicKeyHashString) {
                let msg = "Public key pinning validated for \(hostname) (certificate \(index), \(isLeaf ? "leaf" : "intermediate"))"
                successLog(msg)
                return true
            }
            
            // Print hash for easy copying to code (temporary debug)
            warningLog("COPY THIS HASH FOR CERTIFICATE \(index) (\(hostname)): \(publicKeyHashString)")
        }
        
        // No matching hash found in certificate chain
        let msg = "Public key hash mismatch for \(hostname) in \(environment.rawValue) - none of the certificate hashes matched expected values"
        errorLog(msg)
        return false
    }
}
