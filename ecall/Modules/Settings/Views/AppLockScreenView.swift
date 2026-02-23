import SwiftUI
import LocalAuthentication
import UIKit

struct AppLockScreenView: View {
    @StateObject private var appLockManager = AppLockManager.shared
    @StateObject private var biometricAuthManager = BiometricAuthManager.shared
    @State private var isAuthenticating = false
    @State private var hasAttemptedUnlock = false
    
    private var deviceHasPasscode: Bool {
        let context = LAContext()
        var error: NSError?
        return context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error)
    }

    var body: some View {
        ZStack {
            // White background
            Color.white
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                Spacer()
                
                // App Icon with badge
                ZStack(alignment: .bottomTrailing) {
                    // Main app icon
                    ZStack {
                        RoundedRectangle(cornerRadius: 24)
                            .fill(Color.blue)
                            .frame(width: 120, height: 120)
                        
                        Image(systemName: "phone.fill")
                            .font(.system(size: 60, weight: .medium))
                            .foregroundColor(.white)
                            .rotationEffect(.degrees(-20))
                    }
                    
                    // Security badge
                    ZStack {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 32, height: 32)
                        
                        Image(systemName: "shield.fill")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    .offset(x: 8, y: 8)
                }
                .padding(.bottom, 30)
                
                // App Name
                Text(KeyLocalized.app_title)
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.black)
                    .padding(.bottom, 12)
                
                // End-to-End Encrypted Badge
                HStack(spacing: 8) {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 8, height: 8)
                    
                    Text(KeyLocalized.app_lock_end_to_end_encrypted)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Color.green)
                        .textCase(.uppercase)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.white)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(Color.green.opacity(0.3), lineWidth: 1)
                        )
                )
                .padding(.bottom, 48)
                
                // If App Lock is enabled but device has no passcode, show a clear warning.
                if appLockManager.isAppLockEnabled && !deviceHasPasscode {
                    VStack(spacing: 12) {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                            Text(KeyLocalized.passcode_required_title)
                                .font(.system(size: 17, weight: .bold))
                                .foregroundColor(.black)
                        }

                        Text(KeyLocalized.passcode_required_full_message)
                            .font(.system(size: 14))
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                            .lineLimit(nil)

                        Button {
                            openPasscodeSettings()
                        } label: {
                            Text(KeyLocalized.open_passcode_settings_button)
                                .font(.system(size: 15, weight: .semibold))
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(16)
                    .background(Color.orange.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.orange.opacity(0.25), lineWidth: 1)
                    )
                    .cornerRadius(12)
                    .padding(.bottom, 40)
                } else {
                    // Unlock Button
                    Button {
                        Task {
                            await unlock()
                        }
                    } label: {
                        VStack(spacing: 12) {
                            // Circular button with key icon
                            ZStack {
                                Circle()
                                    .fill(Color.white)
                                    .frame(width: 80, height: 80)
                                    .overlay(
                                        Circle()
                                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                    )
                                
                                Image(systemName: "key.fill")
                                    .font(.system(size: 36, weight: .medium))
                                    .foregroundColor(Color(red: 0.85, green: 0.65, blue: 0.13)) // Gold color
                                    .rotationEffect(.degrees(-45))
                            }
                            
                            // Unlock text
                            Text(unlockText)
                                .font(.system(size: 17, weight: .bold))
                                .foregroundColor(.black)
                            
                            // Tap to authenticate
                            Text(KeyLocalized.app_lock_tap_to_authenticate)
                                .font(.system(size: 14, weight: .regular))
                                .foregroundColor(.gray)
                        }
                    }
                    .disabled(isAuthenticating)
                    .padding(.bottom, 60)
                }
                
                Spacer()
                
                // Security message at bottom
                HStack(spacing: 6) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Color(red: 0.85, green: 0.65, blue: 0.13)) // Gold color
                    
                    Text(KeyLocalized.app_lock_data_protected)
                        .font(.system(size: 13, weight: .regular))
                        .foregroundColor(.gray)
                }
                .padding(.bottom, 40)
            }
            .padding(.horizontal, 24)
        }
        .task {
            // Only attempt unlock once when view appears, not continuously
            if !hasAttemptedUnlock {
                hasAttemptedUnlock = true
                // Small delay to ensure view is fully rendered
                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                await unlock()
            }
        }
    }
    
    private var unlockText: String {
        switch biometricAuthManager.biometricType {
        case .faceID:
            return KeyLocalized.app_lock_unlock_with_face_id
        case .touchID:
            return KeyLocalized.app_lock_unlock_with_touch_id
        default:
            return KeyLocalized.app_lock_unlock_with_passcode
        }
    }
    
    private func unlock() async {
        guard !isAuthenticating else { return }
        isAuthenticating = true
        defer { isAuthenticating = false }
        
        let success = await appLockManager.unlock()
        if success {
            // Unlock successful, view will automatically dismiss via @Published property
            hasAttemptedUnlock = false // Reset for next time
        }
    }
    
    private func openPasscodeSettings() {
        // Apple does not provide a public API to open Face ID & Passcode.
        // The only non-app destination we can attempt is the SYSTEM Settings root.
        // If this fails or is ignored by iOS, we STOP and do nothing.

        let systemSettingsURLs = [
            "App-Prefs:",          // iOS private scheme – may open System Settings root
            "prefs:"               // legacy fallback (may be ignored)
        ]

        for urlString in systemSettingsURLs {
            guard let url = URL(string: urlString) else { continue }
            UIApplication.shared.open(url, options: [:]) { success in
                if success {
                    return
                }
            }
        }

        // HARD STOP: no fallback to app settings
        debugPrint("[AppLock] Unable to open System Settings root. Abort redirect.")
    }
}

#Preview {
    AppLockScreenView()
}
