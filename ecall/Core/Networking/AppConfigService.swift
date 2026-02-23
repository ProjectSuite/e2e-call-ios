import Foundation

struct AppConfiguration: Decodable {
    let twilioConfigured: Bool
    let appleLoginConfigured: Bool

    static let disabled = AppConfiguration(twilioConfigured: false, appleLoginConfigured: false)
}

final class AppConfigService {
    static let shared = AppConfigService()

    private init() {}

    /// Fetches app-level configuration flags (e.g. Twilio / Apple login availability).
    /// This endpoint is explicitly public and should be callable before login,
    /// so we do NOT attach the Authorization header (`auth: false`).
    func fetchConfiguration() async -> Result<AppConfiguration, APIError> {
        let url = APIEndpoint.appConfig.fullURL
        return await APIClient.shared.requestAsync(url, auth: false)
    }
}
