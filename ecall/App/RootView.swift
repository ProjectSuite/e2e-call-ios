import SwiftUI

struct RootView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var toastManager = ToastManager.shared
    @StateObject private var appConfigStore = AppConfigurationStore.shared
    @AppStorage("isIntroCompleted") private var isIntroCompleted: Bool = false
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        if isIntroCompleted {
            ZStack {
                if appState.isRegistered {
                    MainTabView()
                } else {
                    AuthFlowMainView()
                }
            }
            .environmentObject(toastManager)
            .environmentObject(appConfigStore)
            .onChange(of: scenePhase) { newPhase in
                if newPhase == .active && appState.isRegistered {
                    // Proactively refresh token when app comes to foreground
                    Task {
                        debugLog("🔄 App became active, proactively refreshing token...")
                        let result = await TokenRefreshManager.shared.refreshAccessToken()
                        switch result {
                        case .success:
                            debugLog("✅ Proactive token refresh succeeded")
                        case .failure(let error):
                            debugLog("⚠️ Proactive token refresh failed: \(error.content)")
                            // Note: logout is handled inside TokenRefreshManager if refresh token expired
                        }

                        // Verify STOMP connection and credentials on foreground
                        StompSignalingManager.shared.verifyConnectionOnForeground()
                    }
                }
            }
        } else {
            IntroPageView()
        }
    }
}
