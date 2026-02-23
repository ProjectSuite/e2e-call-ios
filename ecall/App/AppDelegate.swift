import UIKit
import GoogleSignIn
import UserNotifications

class AppDelegate: UIResponder, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication,
                     open url: URL,
                     options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
        return GIDSignIn.sharedInstance.handle(url)
    }

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        center.requestAuthorization(options: [.alert, .badge, .sound]) { granted, err in
            if let err = err { errorLog("Notif auth error: \(err)") }
            debugLog("Notif permission granted: \(granted)")
            DispatchQueue.main.async {
                application.registerForRemoteNotifications()
            }
        }
        return true
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .list, .sound])
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo
        if (userInfo["type"] as? String) == APNsNotificationType.newFriendRequest.rawValue {
            NotificationCenter.default.post(name: .newFriendRequested, object: nil)
            AppState.shared.pendingRoute = .contactsFriendRequests
        }
        completionHandler()
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let tokenString = deviceToken.map { String(format: "%02x", $0) }.joined()
        debugLog("📮 APNs token: \(tokenString)")
        KeyStorage.shared.storeApnsToken(tokenString)
        Task { @MainActor in
            if AppState.shared.isRegistered {
                VoipService.shared.registerDeviceTokens(
                    voipToken: KeyStorage.shared.readVoipToken(),
                    apnsToken: tokenString
                )
            }
        }
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        errorLog("Failed to register APNs: \(error.localizedDescription)")
    }

    // Handle remote notifications (APNs alert) for friend requests, warnings, etc.
    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable: Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        debugLog("📮 Received APNs remote notification: \(userInfo)")

        // Handle APNs notification types (friend requests, warnings, etc.)
        if let typeRawValue = userInfo["type"] as? String,
           let type = APNsNotificationType(rawValue: typeRawValue) {

            // Show local notification for user visibility
            showAPNsNotification(type: type, userInfo: userInfo)

            // Handle notification actions
            Task { @MainActor in
                switch type {
                case .userInfoUpdate:
                    NotificationCenter.default.post(
                        name: .profileDidChange,
                        object: nil,
                        userInfo: userInfo
                    )
                case .newFriendRequest:
                    break
                case .acceptFriendRequest:
                    NotificationCenter.default.post(name: .acceptFriendRequested, object: nil)
                case .warningLogin:
                    NotificationCenter.default.post(
                        name: .warningLoginNotificationTapped,
                        object: nil,
                        userInfo: userInfo
                    )
                }
            }
        }

        completionHandler(.newData)
    }

    // MARK: - Helper Methods

    private func showAPNsNotification(type: APNsNotificationType, userInfo: [AnyHashable: Any]) {
        var title = type.title
        var body = type.body

        // Format body with user info if needed
        switch type {
        case .newFriendRequest:
            if let displayName = userInfo["displayName"] as? String {
                body = String(format: body, displayName)
            }
        case .acceptFriendRequest:
            if let displayName = userInfo["displayName"] as? String {
                title = String(format: title, displayName)
                body = String(format: body, displayName)
            }
        case .userInfoUpdate, .warningLogin:
            break
        }

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.userInfo = userInfo

        let request = UNNotificationRequest(
            identifier: "apns-\(type.rawValue)-\(UUID().uuidString)",
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                errorLog("❌ Failed to show APNs notification: \(error)")
            } else {
                debugLog("✅ APNs \(type.rawValue) notification displayed")
            }
        }
    }
}
