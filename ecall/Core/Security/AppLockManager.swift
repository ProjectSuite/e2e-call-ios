import Foundation
import LocalAuthentication
import UIKit

@MainActor
class AppLockManager: ObservableObject {
    static let shared = AppLockManager()
    
    @Published var isLocked = false
    @Published var isAppLockEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isAppLockEnabled, forKey: "appLockEnabled")
        }
    }
    
    // Managers
    private let biometricAuthManager = BiometricAuthManager.shared
    private let appLockEnabledKey = "appLockEnabled"
    private var backgroundTime: Date?
    
    private init() {
        self.isAppLockEnabled = UserDefaults.standard.bool(forKey: appLockEnabledKey)
        setupNotifications()
    }
    
    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.appDidEnterBackground()
            }
        }
        
        NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.appWillEnterForeground()
            }
        }
    }
    
    private func appDidEnterBackground() {
        if isAppLockEnabled {
            backgroundTime = Date()
        }
    }
    
    private func appWillEnterForeground() {
        // Only lock if app lock is enabled and user is logged in
        guard isAppLockEnabled, AppState.shared.isRegistered, backgroundTime != nil else {
            backgroundTime = nil
            return
        }

        // If the device has no passcode set, we must NOT lock the app.
        // Otherwise the user will be stuck on the lock screen because LocalAuthentication
        // cannot evaluate any owner authentication policy.
        guard deviceHasOwnerAuthentication() else {
            isLocked = false
            backgroundTime = nil
            return
        }

        // Lock app when returning from background
        isLocked = true
        backgroundTime = nil
    }

    func checkAndLockIfNeeded() async {
        // Only lock if app lock is enabled and user is logged in
        guard isAppLockEnabled, AppState.shared.isRegistered else {
            isLocked = false
            return
        }

        // If the device has no passcode set, don't lock.
        guard deviceHasOwnerAuthentication() else {
            isLocked = false
            return
        }

        // Lock the app if App Lock is enabled
        isLocked = true
    }

    func deviceHasOwnerAuthentication() -> Bool {
        let context = LAContext()
        var error: NSError?
        return context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error)
    }
    
    func clearAppLockSettings() {
        isAppLockEnabled = false
        isLocked = false
        UserDefaults.standard.removeObject(forKey: appLockEnabledKey)
    }
    
    func unlock() async -> Bool {
        guard isLocked else { return true }
        
        let reason = KeyLocalized.app_lock_unlock_reason
        let success = await biometricAuthManager.authenticate(reason: reason)
        
        if success {
            isLocked = false
        }
        
        return success
    }
    
    func enableAppLock() {
        isAppLockEnabled = true
    }
    
    func disableAppLock() {
        isAppLockEnabled = false
        isLocked = false
    }
}
