import SwiftUI

struct MyProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var appConfig: AppConfigurationStore
    @StateObject private var biometricAuth = BiometricAuthManager.shared

    @State private var showEditPhone = false
    @State private var showEditEmail = false
    @State private var showLoginInfoSheet = false

    var body: some View {
        VStack(spacing: 16) {
            // Avatar section
            SmartAvatarView(
                url: nil,
                name: appState.displayName,
                size: 80
            )
            .padding(.top, 20)
            .padding(.bottom, 30)

            // Name row
            NavigationLink(destination: ChangeNameView()) {
                profileRow(
                    systemImage: "person",
                    value: appState.displayName.isEmpty ? KeyLocalized.name : appState.displayName,
                    isPlaceholder: appState.displayName.isEmpty,
                    showChevron: true
                )
            }

            // Phone row (only show when Twilio is configured)
            if appConfig.config.twilioConfigured {
                Button(action: {
                    authenticateAndShowPhoneEdit()
                }, label: {
                    profileRow(
                        systemImage: "phone",
                        value: appState.phoneNumber.isEmpty ? KeyLocalized.phone_number : AppUtils.formatPhoneNumber(appState.phoneNumber),
                        isPlaceholder: appState.phoneNumber.isEmpty,
                        showChevron: true
                    )
                })
            }

            // Email row
            Button(action: {
                authenticateAndShowEmailEdit()
            }, label: {
                profileRow(
                    systemImage: "envelope",
                    value: appState.email.isEmpty ? KeyLocalized.email : appState.email,
                    isPlaceholder: appState.email.isEmpty,
                    showChevron: true
                )
            })

            if KeyStorage.shared.readAppleLoginFlag() && appConfig.config.appleLoginConfigured {
                // Apple method section
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 12) {
                        Image(systemName: "applelogo")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 28, height: 28)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(KeyLocalized.sign_in_with_apple)
                                .foregroundColor(.primary)
                                .font(.system(size: 16))

                            Text(KeyLocalized.connected)
                                .foregroundColor(.secondary)
                                .font(.system(size: 13))
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        Circle()
                            .fill(Color.green)
                            .frame(width: 8, height: 8)
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color(.secondarySystemBackground))
                    )
                    .contentShape(Rectangle())
                }
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .navigationTitle(KeyLocalized.my_profile)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    showLoginInfoSheet = true
                }) {
                    Image(systemName: "info.circle")
                }
            }
        }
        .navigationDestination(isPresented: $showEditPhone) {
            ChangePhoneNumberView()
        }
        .navigationDestination(isPresented: $showEditEmail) {
            ChangeEmailView()
        }
        .toolbar(.hidden, for: .tabBar)
        .sheet(isPresented: $showLoginInfoSheet) {
            LoginMethodsInfoView(
                isAppleConnected: KeyStorage.shared.readAppleLoginFlag(),
                isPhoneEnabled: appConfig.config.twilioConfigured
            )
                .presentationDetents([.height(280)])
        }
        .task {
            await appConfig.refresh()
        }
        .logViewName()
    }

    // MARK: - Row
    private func profileRow(systemImage: String, value: String, isPlaceholder: Bool, showChevron: Bool = true) -> some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 20, weight: .regular))
                .foregroundColor(.black)
                .frame(width: 28, height: 28)

            Text(value)
                .foregroundColor(isPlaceholder ? .gray : .primary)
                .opacity(isPlaceholder ? 0.6 : 1.0)
                .frame(maxWidth: .infinity, alignment: .leading)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)

            if showChevron {
                Image(systemName: "chevron.right")
                    .foregroundColor(.gray)
                    .frame(width: 20, height: 20)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(.secondarySystemBackground))
        )
        .contentShape(Rectangle())
    }

    // MARK: - Helper Methods

    // MARK: - Authentication Methods
    private func authenticateAndShowPhoneEdit() {
        Task {
            let success = await biometricAuth.authenticate(reason: KeyLocalized.biometric_reason_change_profile)
            if success {
                await MainActor.run {
                    showEditPhone = true
                }
            }
        }
    }

    private func authenticateAndShowEmailEdit() {
        Task {
            let success = await biometricAuth.authenticate(reason: KeyLocalized.biometric_reason_change_profile)
            if success {
                await MainActor.run {
                    showEditEmail = true
                }
            }
        }
    }
}

#Preview {
    MyProfileView()
}
