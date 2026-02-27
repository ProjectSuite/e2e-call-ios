import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var languageManager: LanguageManager
    @State private var isNotificationsEnabled: Bool = true
    @EnvironmentObject var appState: AppState
    @StateObject private var appLockManager = AppLockManager.shared
    @State private var showLogoutConfirmation: Bool = false
    @State private var showQRCodePopup: Bool = false
    @State private var showMyProfile: Bool = false
    @State private var showDeleteAccount: Bool = false

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text(KeyLocalized.personal_info_header)) {
                    Button(action: {
                        showMyProfile = true
                    }, label: {
                        HStack(spacing: 16) {
                            SmartAvatarView(
                                url: nil,
                                name: appState.displayName,
                                size: 50
                            )

                            VStack(alignment: .leading, spacing: 4) {
                                Text(appState.displayName)
                                    .font(.headline)
                                if !appState.email.isEmpty {
                                    Text(appState.email)
                                        .font(.subheadline)
                                        .foregroundColor(.gray)
                                }
                                if !appState.phoneNumber.isEmpty {
                                    Text(AppUtils.formatPhoneNumber(appState.phoneNumber))
                                        .font(.subheadline)
                                        .foregroundColor(.gray)
                                }
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .foregroundColor(.gray)
                                .font(.system(size: 14, weight: .medium))
                        }
                        .padding(.vertical, 4)
                    })
                    .buttonStyle(.plain)
                }

                Section(header: Text(KeyLocalized.general)) {
                    HStack(spacing: 12) {
                        Image(systemName: "globe")
                            .foregroundColor(.accentColor)
                        LanguageSwitcherView()
                    }
                    NavigationLink(destination: DevicesView()) {
                        Label(KeyLocalized.devices, systemImage: "laptopcomputer.and.iphone")
                    }
                    NavigationLink(destination: PermissionsView()) {
                        HStack(spacing: 12) {
                            Image(systemName: "shield.fill")
                                .foregroundColor(.accentColor)
                                .frame(width: 24, height: 24)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(KeyLocalized.permissions_row_title)
                                Text(KeyLocalized.permissions_row_subtitle)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            Spacer()
                        }
                    }
                }

                Section(header: Text(KeyLocalized.security_header)) {
                    NavigationLink(destination: AppLockSettingsView()) {
                        HStack(spacing: 12) {
                            Image(systemName: "lock.fill")
                                .foregroundColor(.green)
                                .frame(width: 24, height: 24)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(KeyLocalized.app_lock_title)
                                Text(KeyLocalized.app_lock_subtitle)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                        }
                    }
                }

                Section {
                    Button(action: {
                        showLogoutConfirmation = true
                    }, label: {
                        HStack(spacing: 12) {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                                .foregroundColor(.red)
                            Text(KeyLocalized.logout)
                                .foregroundColor(.red)
                        }
                    })

                    Button(action: {
                        showDeleteAccount = true
                    }, label: {
                        if appState.deletedAt != nil {
                            HStack(spacing: 12) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.orange)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(KeyLocalized.delete_account)
                                        .foregroundColor(.orange)
                                    Text(KeyLocalized.delete_account_pending_banner)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        } else {
                            HStack(spacing: 12) {
                                Image(systemName: "trash.fill")
                                    .foregroundColor(.red)
                                Text(KeyLocalized.delete_account)
                                    .foregroundColor(.red)
                            }
                        }
                    })
                }

                Section {
                    HStack {
                        Spacer()
                        Text(String(format: KeyLocalized.app_version,
                                    Bundle.main.releaseVersionNumber ?? "1.0",
                                    Bundle.main.buildVersionNumber ?? "1"))
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        showQRCodePopup = true
                    } label: {
                        Image(systemName: "qrcode")
                    }
                }
                ToolbarItem(placement: .principal) {
                    Text(KeyLocalized.settings_title)
                        .font(.headline)
                }

            }
            .alert(KeyLocalized.confirm_logout, isPresented: $showLogoutConfirmation) {
                Button(KeyLocalized.confirm, role: .destructive) {
                    appState.logout()
                }
                Button(KeyLocalized.cancel, role: .cancel) { }
            } message: {
                Text(KeyLocalized.logout_confirmation_message)
            }
            .sheet(isPresented: $showQRCodePopup) {
                MyQRCodeView(showQRCodePopup: $showQRCodePopup)
                    .presentationDetents([.large])          // iOS 16+ for "full" style
                    .interactiveDismissDisabled(false)      // allow swiping down
            }
            .navigationDestination(isPresented: $showMyProfile) {
                MyProfileView()
                    .environmentObject(appState)
            }
            .sheet(isPresented: $showDeleteAccount) {
                DeleteAccountView()
                    .environmentObject(appState)
                    .presentationDetents([.large])
            }

            .navigationBarTitleDisplayMode(.inline)
            .logViewName()
            .onAppear {
                appState.fetchCurrentUserInfo()
            }
        }
        .id(appLockManager.isLocked ? "locked" : "unlocked")
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
            .environmentObject(LanguageManager())
    }
}
