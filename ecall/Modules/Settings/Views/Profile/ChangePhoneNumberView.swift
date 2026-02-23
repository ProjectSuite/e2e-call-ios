import SwiftUI

struct ChangePhoneNumberView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var appState: AppState

    @State private var phoneNumber: String = ""
    @State private var isPhoneAvailable: Bool = false
    @State private var isLoading: Bool = false
    @State private var showOTPVerification: Bool = false
    @State private var authViewModel: AuthViewModel?
    @State private var showError: Bool = false
    @State private var errorMessage: String = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // Phone input field
                VStack(alignment: .leading, spacing: 8) {
                    CountryPhoneInputSection(
                        fullPhoneNumber: $phoneNumber,
                        onPhoneAvailabilityChanged: { available in
                            isPhoneAvailable = available
                        }
                    )
                    .onChange(of: phoneNumber) { _ in
                        clearError()
                    }

                    if showError {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundColor(.red)
                            .padding(.leading, 4)
                    }
                }
                .padding(.horizontal)

                // Notice section
                VStack(alignment: .leading, spacing: 12) {
                    Text(KeyLocalized.notice)
                        .font(.headline)
                        .foregroundColor(.primary)

                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .top, spacing: 8) {
                            Text("•")
                                .foregroundColor(.primary)
                            Text(KeyLocalized.phone_notice_1)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }

                        HStack(alignment: .top, spacing: 8) {
                            Text("•")
                                .foregroundColor(.primary)
                            Text(KeyLocalized.phone_notice_2)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }

                        HStack(alignment: .top, spacing: 8) {
                            Text("•")
                                .foregroundColor(.primary)
                            Text(KeyLocalized.phone_notice_3)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }

                        HStack(alignment: .top, spacing: 8) {
                            Text("•")
                                .foregroundColor(.primary)
                            Text(KeyLocalized.phone_notice_4)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }

                    Spacer()

                    // Next button
                    Button(action: {
                        updatePhoneNumber()
                    }, label: {
                        HStack {
                            if isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(1)
                            } else {
                                Text(KeyLocalized.next)
                                    .font(.system(size: 18, weight: .medium))
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            !isLoading && isPhoneAvailable
                                ? Color.blue
                                : Color.gray.opacity(0.5)
                        )
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    })
                    .disabled(phoneNumber.isEmpty || !isPhoneAvailable || isLoading)
                    .padding(.horizontal)
                }
                .padding(.horizontal, 16)

                Spacer()
            }
            .padding(.vertical, 32)
            .navigationBarTitle(KeyLocalized.change_phone_number, displayMode: .inline)
            .fullScreenCover(isPresented: $showOTPVerification) {
                if let viewModel = authViewModel {
                    OTPVerificationView(viewModel: viewModel, purpose: .profileUpdate) {
                        updateUser()
                    }
                }
            }
            .logViewName()
        }
    }

    private func updatePhoneNumber() {
        guard !phoneNumber.isEmpty else { return }

        // Check if phone number actually changed
        if phoneNumber == appState.phoneNumber {
            dismiss()
            return
        }

        // Validate phone number format
        guard phoneNumber.isValidPhoneNumber else {
            showErrorMessage(KeyLocalized.invalid_phone_format)
            return
        }

        isLoading = true

        // Create AuthViewModel for OTP verification
        let viewModel = AuthViewModel()
        viewModel.phoneNumber = phoneNumber
        viewModel.type = .phoneNumber

        // Trigger send OTP
        viewModel.resendOTP { success in
            isLoading = false
            if success {
                self.authViewModel = viewModel
                self.showOTPVerification = true
            } else {
                self.showErrorMessage(viewModel.errorMessage)
            }
        }
    }

    private func updateUser() {
        isLoading = true
        UserService.shared.updateUser(displayName: AppState.shared.displayName, phoneNumber: phoneNumber) { data, error in
            Task { @MainActor in
                isLoading = false

                if data != nil { // success
                    appState.updatePhoneNumber(phoneNumber)
                    dismiss()
                    ToastManager.shared.success(KeyLocalized.change_info_success)
                } else {
                    self.showErrorMessage(error?.content ?? KeyLocalized.unknown_error_try_again)
                }
            }
        }
    }

    private func showErrorMessage(_ message: String) {
        errorMessage = message
        showError = true
    }

    private func clearError() {
        showError = false
        errorMessage = ""
    }
}

#Preview {
    ChangePhoneNumberView()
}
