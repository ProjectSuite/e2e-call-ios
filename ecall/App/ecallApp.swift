import SwiftUI
import UserNotifications
import UIKit
import AVFoundation

@main
struct ecallApp: App {
    @StateObject private var addFriendVM = AddFriendViewModel()
    @StateObject var languageManager = LanguageManager()
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @State private var showAddFriendSheet = false

    init() {
        let isFirstLaunch = !UserDefaults.standard.bool(forKey: "hasLaunchedBefore")
        if isFirstLaunch {
            AppState.shared.logout()
            _ = KeyStorage.shared.removeUserInfos()
            UserDefaults.standard.set(true, forKey: "hasLaunchedBefore")
        }

        // Initialize PushRegistry for VoIP notifications.
        StompSignalingManager.shared.signalingDelegate = CallSignalingHandler.shared
        StompSignalingManager.shared.connectIfReady(force: true)
        JanusSocketClient.shared.signalingDelegate = JanusSignalingHandler.shared
        _ = PushRegistryManager.shared

        // Initialize CallKit provider early to prevent first-call failures
        _ = GroupCallManager.shared

        // Request microphone permission early (triggers system popup immediately)
        requestMicrophonePermission()

        // Request notification permission
        requestNotificationPermission()

        // Pre-fetch TURN credentials after login to speed up first call
        NotificationCenter.default.addObserver(
            forName: Notification.Name("LoginSuccess"),
            object: nil,
            queue: .main
        ) { _ in
            debugLog("🔥 Pre-fetching TURN credentials for faster first call")
            CredentialsService.shared.fetchCredentials()
        }
    }

    private func requestMicrophonePermission() {
        AVAudioSession.sharedInstance().requestRecordPermission { granted in
            DispatchQueue.main.async {
                if granted {
                    debugLog("✅ Microphone permission granted")
                } else {
                    errorLog("❌ Microphone permission denied")
                }
            }
        }
    }

    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            DispatchQueue.main.async {
                if granted {
                    debugLog("✅ Notification permission granted")
                    UIApplication.shared.registerForRemoteNotifications()
                } else {
                    errorLog(" Notification permission denied: \(error?.localizedDescription ?? "Unknown error")")
                }
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(languageManager)
                .environment(\.locale, languageManager.locale)
                .environmentObject(AppState.shared)
                .environmentObject(addFriendVM)
                .sheet(isPresented: $showAddFriendSheet) {
                    AddFriendView(initialKey: addFriendVM.importedQRPayload)
                        .environmentObject(languageManager)
                }
                .onOpenURL { url in
                    guard AppUtils.validUrlApp(url) else { return }
                    addFriendVM.importedQRPayload = url.absoluteString
                    showAddFriendSheet = true
                }
                .onAppear {
                    // Initialize AppLockManager to setup notifications
                    _ = AppLockManager.shared
                }
        }
    }
}
