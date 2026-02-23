import Foundation
import Combine

/// Observable store for app-level configuration flags so views can reactively update.
@MainActor
final class AppConfigurationStore: ObservableObject {
    static let shared = AppConfigurationStore()

    @Published private(set) var config: AppConfiguration = .init(
        twilioConfigured: false,
        appleLoginConfigured: false
    )
    @Published private(set) var isLoading: Bool = false

    private init() {
        Task { await refresh() }
    }

    /// Fetch latest configuration. Defaults remain false on failure.
    func refresh() async {
        isLoading = true
        let result = await AppConfigService.shared.fetchConfiguration()
        isLoading = false

        if case .success(let newConfig) = result {
            config = newConfig
        }
    }
}
