import SwiftUI
import UIKit

private struct PasscodeWarningView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                Text(KeyLocalized.passcode_required_title)
                    .font(.headline)
                    .foregroundColor(.primary)
            }

            Text(KeyLocalized.passcode_required_message)
                .fixedSize(horizontal: false, vertical: true)
                .lineLimit(nil)
                .font(.subheadline)
                .foregroundColor(.secondary)

            Button {
                openPasscodeSettings()
            } label: {
                Text(KeyLocalized.open_passcode_settings_button)
                    .font(.subheadline.weight(.semibold))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.orange.opacity(0.10))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.orange.opacity(0.25), lineWidth: 1)
        )
        .cornerRadius(12)
    }

    private func openPasscodeSettings() {
        // Try to open passcode settings in system settings
        // Note: App-Prefs: and prefs: are private URL schemes that may not work on all iOS versions
        // We try passcode settings first, then fall back to General settings
        // IMPORTANT: We do NOT open app settings (UIApplication.openSettingsURLString)
        // If nothing works, we stop here - do NOT fallback to app settings
        
        // Priority order: try passcode-specific settings first
        let passcodeURLs = [
            "App-Prefs:root=PASSCODE",
            "App-Prefs:root=TOUCHID_PASSCODE",
            "App-Prefs:root=FaceID",
            "prefs:root=PASSCODE",
            "prefs:root=TOUCHID_PASSCODE",
            "prefs:root=FaceID"
        ]
        
        // Try the first passcode URL (iOS will handle if it works or not)
        // We don't check canOpenURL because it may return false for private schemes
        // but the URL might still work when opened
        if let firstURL = URL(string: passcodeURLs[0]) {
            UIApplication.shared.open(firstURL, options: [:], completionHandler: nil)
            return
        }
        
        // If first URL creation failed, try others
        for urlString in passcodeURLs.dropFirst() {
            if let url = URL(string: urlString) {
                UIApplication.shared.open(url, options: [:], completionHandler: nil)
                return
            }
        }
        
        // If all passcode URLs failed, try General settings (still system settings, not app settings)
        if let generalURL = URL(string: "App-Prefs:root=General") {
            UIApplication.shared.open(generalURL, options: [:], completionHandler: nil)
            return
        }
        
        if let generalURL = URL(string: "prefs:root=General") {
            UIApplication.shared.open(generalURL, options: [:], completionHandler: nil)
            return
        }
        
        // If nothing works, stop here - do NOT open app settings
        // This ensures we never redirect to app settings (all apps list)
    }
}

struct AppLockSettingsView: View {
    @EnvironmentObject var languageManager: LanguageManager
    @StateObject private var appLockManager = AppLockManager.shared
    @StateObject private var biometricAuthManager = BiometricAuthManager.shared
    @Environment(\.dismiss) private var dismiss
    private var isPasscodeSet: Bool {
        appLockManager.deviceHasOwnerAuthentication()
    }

    @State private var showPasscodeRequiredAlert = false
    
    var body: some View {
        Form {
            VStack(spacing: 24) {
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
                
                // Description
                Text(KeyLocalized.app_lock_description)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                // Enable Toggle Section
                VStack(spacing: 8) {
                    HStack {
                        Text(KeyLocalized.app_lock_enable)
                            .font(.body)
                        Spacer()
                        Toggle("", isOn: $appLockManager.isAppLockEnabled)
                            .labelsHidden()
                            .onChange(of: appLockManager.isAppLockEnabled) { newValue in
                                if newValue {
                                    appLockManager.enableAppLock()
                                    // If passcode is not set upon enabling, show an alert.
                                    if !isPasscodeSet {
                                        showPasscodeRequiredAlert = true
                                    }
                                } else {
                                    appLockManager.disableAppLock()
                                }
                            }
                    }
                    
                    // Show a persistent warning if App Lock is on but no passcode is set.
                    // This covers the case where a user removes their passcode after enabling the lock.
                    if appLockManager.isAppLockEnabled && !isPasscodeSet {
                        PasscodeWarningView()
                    }
                }
                .padding(.vertical, 8)
                
                // How it works info box
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "info.circle.fill")
                        .foregroundColor(.accentColor)
                        .font(.title3)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(KeyLocalized.app_lock_how_it_works_title)
                            .font(.headline)
                            .foregroundColor(.accentColor)
                        
                        Text(KeyLocalized.app_lock_how_it_works_description)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
                .padding()
                .background(Color.accentColor.opacity(0.1))
                .cornerRadius(12)
            }
            .padding(.vertical)
        }
        .navigationTitle(KeyLocalized.app_lock_title)
        .navigationBarTitleDisplayMode(.inline)
        .alert(KeyLocalized.passcode_required_title, isPresented: $showPasscodeRequiredAlert) {
            Button(KeyLocalized.ok, role: .cancel) {}
        } message: {
            Text(KeyLocalized.passcode_required_full_message)
        }
    }
}

#Preview {
    NavigationStack {
        AppLockSettingsView()
            .environmentObject(LanguageManager())
    }
}
