import SwiftUI

struct ChangeEmailView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var appState: AppState

    @State private var email: String = ""
    @State private var isLoading: Bool = false
    @State private var showOTPVerification: Bool = false
    @State private var authViewModel: AuthViewModel?
    @State private var showError: Bool = false
    @State private var errorMessage: String = ""

    @FocusState private var isEmailFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {

                // Email input field
                VStack(alignment: .leading, spacing: 8) {
                    TextField(KeyLocalized.email_placeholder, text: $email)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .textFieldStyle(LargeTextFieldStyle())
                        .autocorrectionDisabled(true)
                        .focused($isEmailFocused)
                        .clearButton(text: $email)
                        .onChange(of: email) { _ in
                            clearError()
                        }

                    if showError {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundColor(.red)
                            .padding(.leading, 4)
                    }
                }
                .padding(.horizontal, 16)

                // Notice section
                VStack(alignment: .leading, spacing: 12) {
                    Text(KeyLocalized.notice)
                        .font(.headline)
                        .foregroundColor(.primary)

                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .top, spacing: 8) {
                            Text("•")
                                .foregroundColor(.primary)
                            Text(KeyLocalized.email_notice_1)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }

                        HStack(alignment: .top, spacing: 8) {
                            Text("•")
                                .foregroundColor(.primary)
                            Text(KeyLocalized.email_notice_2)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }

                        HStack(alignment: .top, spacing: 8) {
                            Text("•")
                                .foregroundColor(.primary)
                            Text(KeyLocalized.email_notice_3)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }

                        HStack(alignment: .top, spacing: 8) {
                            Text("•")
                                .foregroundColor(.primary)
                            Text(KeyLocalized.email_notice_4)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(.horizontal, 16)

                Spacer()

                // Next button
                Button(action: {
                    updateEmail()
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
                        !isLoading && email.isValidEmail && email != appState.email
                            ? Color.blue
                            : Color.gray.opacity(0.5)
                    )
                    .foregroundColor(.white)
                    .cornerRadius(12)
                })
                .disabled(email.isEmpty || !email.isValidEmail || email == appState.email || isLoading)
                .padding(.horizontal, 16)
                .padding(.bottom, 20)
            }
            .padding(.vertical, 32)
            .navigationBarTitle(KeyLocalized.change_email, displayMode: .inline)
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

    private func updateEmail() {
        guard !email.isEmpty else { return }

        // Check if email actually changed
        if email == appState.email {
            dismiss()
            return
        }

        // Validate email format
        guard email.isValidEmail else {
            showErrorMessage(KeyLocalized.invalid_email_format)
            return
        }

        isLoading = true

        // Create AuthViewModel for OTP verification
        let viewModel = AuthViewModel()
        viewModel.email = email
        viewModel.type = .email

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
        UserService.shared.updateUser(displayName: AppState.shared.displayName, email: email) { data, error in
            Task { @MainActor in
                isLoading = false

                if data != nil { // success
                    appState.updateEmail(email)
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
    ChangeEmailView()
}
