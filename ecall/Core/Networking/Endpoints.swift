import Foundation

// MARK: - Environment Type

enum EnvironmentType: String {
    case dev = "Dev"
    case staging = "Staging"
    case production = "Production"

    var displayName: String {
        return self.rawValue
    }

    var icon: String {
        switch self {
        case .dev: return "🔧"
        case .staging: return "🧪"
        case .production: return "🚀"
        }
    }
}

// MARK: - App Environment

struct AppEnvironment {
    let type: EnvironmentType
    let baseURL: String
    let socketURL: String
    let janusSocketURL: String
    let janusApiSecret: String
    let appApiId: String
    let appApiHash: String
    let googleClientID: String
    let shareURL: String
    let bundleURLScheme: String
    let baseDomain: String

    /// Automatically read environment from Build Configuration via Info.plist
    /// Returns a default staging environment if configuration fails (graceful degradation)
    static var current: AppEnvironment {
        guard let infoDictionary = Bundle.main.infoDictionary else {
            errorLog("❌ [CRITICAL] Info.plist not found - using default staging environment")
            // Return a safe default environment instead of crashing
            return AppEnvironment.createDefaultEnvironment()
        }

        // Read values from Info.plist (injected from Build Settings)
        let environmentName = infoDictionary["ENVIRONMENT_NAME"] as? String ?? EnvironmentType.staging.rawValue
        let baseURL = infoDictionary["API_BASE_URL"] as? String ?? ""
        let socketURL = infoDictionary["SOCKET_BASE_URL"] as? String ?? ""
        let janusSocketURL = infoDictionary["JANUS_SOCKET_URL"] as? String ?? ""
        let janusApiSecret = infoDictionary["JANUS_API_SECRET"] as? String ?? ""
        let appApiId = infoDictionary["APP_API_ID"] as? String ?? ""
        let appApiHash = infoDictionary["APP_API_HASH"] as? String ?? ""
        let googleClientID = infoDictionary["GOOGLE_CLIENT_ID"] as? String ?? ""
        let shareURL = infoDictionary["SHARE_URL"] as? String ?? "https://app.example.com/share"

        // Read new configurable values with fallbacks
        let bundleURLScheme = infoDictionary["BUNDLE_URL_SCHEME"] as? String ?? "yourapp"
        let baseDomain = infoDictionary["BASE_DOMAIN"] as? String ?? "example.com"

        // Validate URLs - log warning but use defaults instead of crashing
        var missingConfigs: [String] = []
        if baseURL.isEmpty { missingConfigs.append("API_BASE_URL") }
        if socketURL.isEmpty { missingConfigs.append("SOCKET_BASE_URL") }
        if janusSocketURL.isEmpty { missingConfigs.append("JANUS_SOCKET_URL") }
        
        if !missingConfigs.isEmpty {
            errorLog("⚠️ [WARNING] Environment URLs not configured: \(missingConfigs.joined(separator: ", ")) - using default staging environment")
            // Return default environment instead of crashing
            return AppEnvironment.createDefaultEnvironment()
        }

        let envType = EnvironmentType(rawValue: environmentName) ?? .staging

        return AppEnvironment(
            type: envType,
            baseURL: baseURL,
            socketURL: socketURL,
            janusSocketURL: janusSocketURL,
            janusApiSecret: janusApiSecret,
            appApiId: appApiId,
            appApiHash: appApiHash,
            googleClientID: googleClientID,
            shareURL: shareURL,
            bundleURLScheme: bundleURLScheme,
            baseDomain: baseDomain
        )
    }
    
    /// Create a default staging environment as fallback
    private static func createDefaultEnvironment() -> AppEnvironment {
        return AppEnvironment(
            type: .staging,
            baseURL: "https://staging.example.com/api",
            socketURL: "wss://staging.example.com/ws",
            janusSocketURL: "wss://staging.example.com/janus",
            janusApiSecret: "",
            appApiId: "",
            appApiHash: "",
            googleClientID: "",
            shareURL: "https://staging.example.com/share",
            bundleURLScheme: "ecall",
            baseDomain: "example.com"
        )
    }

    /// Print environment information for debugging
    func printInfo() {
        printLog("🌍 ==================== ENVIRONMENT ====================")
        printLog("📱 Environment: \(type.icon) \(type.displayName)")
        printLog("🌐 Base URL: \(baseURL)")
        printLog("🔌 Socket URL: \(socketURL)")
        printLog("📹 Janus URL: \(janusSocketURL)")
        printLog("🔐 Janus API Secret: \(janusApiSecret)")
        printLog("🆔 App Api Id: \(appApiId)")
        printLog("🔗 Share URL: \(shareURL)")
        printLog("📦 Bundle URL Scheme: \(bundleURLScheme)")
        printLog("🌐 Base Domain: \(baseDomain)")
        printLog("🌍 ====================================================")
    }
}

// MARK: - Endpoints

class Endpoints {
    static let shared = Endpoints()
    private init() {
        environment.printInfo()
    }

    private let environment = AppEnvironment.current

    var baseURL: String {
        return environment.baseURL
    }

    var baseSocketURL: String {
        return environment.socketURL
    }

    var baseJanusSocketURL: String {
        return environment.janusSocketURL
    }

    var janusApiSecret: String {
        return environment.janusApiSecret
    }

    var bundleURLScheme: String {
        return environment.bundleURLScheme
    }

    var googleClientID: String {
        return environment.googleClientID
    }

    var shareURL: String {
        return environment.shareURL
    }
}
