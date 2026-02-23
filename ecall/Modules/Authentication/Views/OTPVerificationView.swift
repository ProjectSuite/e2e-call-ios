import SwiftUI

enum OTPPurpose {
    case login
    case profileUpdate
}

struct OTPVerificationView: View {
    @ObservedObject var viewModel: AuthViewModel
    @Environment(\.presentationMode) private var presentation
    @EnvironmentObject var appState: AppState
    @State var isLoading: Bool = false
    @State var timeRemaining = 30
    @State var timer: Timer?
    @State var canResend = false
    @State var resendCount = 0

    let onSuccess: () -> Void

    let purpose: OTPPurpose

    init(viewModel: AuthViewModel, purpose: OTPPurpose = .login, onSuccess: @escaping () -> Void = {}) {
        self.viewModel = viewModel
        self.purpose = purpose
        self.onSuccess = onSuccess
    }

    func startTimer() {
        canResend = false
        timeRemaining = 30
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            if timeRemaining > 0 {
                timeRemaining -= 1
            } else {
                timer?.invalidate()
                canResend = true
            }
        }
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // OTP Sent Information
                VStack(spacing: 8) {
                    switch viewModel.type {
                    case .email:
                        Text(KeyLocalized.otp_sent_to_email)
                            .font(.headline)
                            .foregroundColor(.primary)
                        Text(viewModel.email)
                            .font(.subheadline)
                            .foregroundColor(.blue)
                            .fontWeight(.medium)
                    case .phoneNumber:
                        Text(KeyLocalized.otp_sent_to_phone)
                            .font(.headline)
                            .foregroundColor(.primary)
                        Text(AppUtils.formatPhoneNumber(viewModel.phoneNumber))
                            .font(.subheadline)
                            .foregroundColor(.blue)
                            .fontWeight(.medium)
                    case .apple:
                        Text("")
                    }
                }
                .padding(.horizontal)

                // Instructions
                switch viewModel.type {
                case .email:
                    Text(KeyLocalized.look_for_email_from_app)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .font(.subheadline)
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)

                case .phoneNumber:
                    Text(KeyLocalized.look_for_sms_from_app)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .font(.subheadline)
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)

                case .apple:
                    Text("")
                }

                OTPInputView(code: $viewModel.otp)

                if viewModel.showError {
                    Text(viewModel.errorMessage)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if canResend {
                    Button {
                        isLoading = true
                        viewModel.resendOTP { ok in
                            isLoading = false
                            if ok {
                                resendCount += 1
                                startTimer()
                            }
                        }
                    } label: {
                        HStack {
                            if isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(1)
                            } else {
                                Text(KeyLocalized.resend_otp)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .foregroundColor(.blue)
                        .cornerRadius(12)
                    }
                    .disabled(viewModel.errorMessage.contains("Too many failed attempts.") || viewModel.errorMessage.contains("You've reached the maximum number of resend attempts."))
                } else {
                    Button {

                    } label: {
                        Text(String(format: KeyLocalized.resend_otp_in, timeRemaining))
                            .foregroundColor(.gray)
                    }
                }

                Button {
                    isLoading = true
                    handleVerification()
                } label: {
                    HStack {
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(1)
                        } else {
                            Text(KeyLocalized.verify)
                                .font(.title3)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(viewModel.otp.count == 6 && !isLoading
                                    ? Color.blue
                                    : Color.gray.opacity(0.5)
                    )
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .disabled(viewModel.otp.count != 6 || isLoading || viewModel.errorMessage.contains("Too many failed attempts."))

                Spacer()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(KeyLocalized.cancel) {
                        viewModel.clearKeys()
                        viewModel.clearError()
                        presentation.wrappedValue.dismiss()
                    }
                }
                ToolbarItem(placement: .principal) {
                    Text(purpose == .login ? KeyLocalized.otp_for_login : KeyLocalized.otp_for_profile_update)
                        .font(.headline)
                }
            }
            .padding()
        }
        .onAppear {
            startTimer()
            resendCount = 0
        }
        .onDisappear {
            // Stop timer to avoid multiple timers after re-entering the screen
            timer?.invalidate()
            timer = nil
        }
        .logViewName()
    }

    private func handleVerification() {
        switch purpose {
        case .login:
            // For login: verify OTP and save immediately (no finalize step)
            viewModel.verifyLogin { success in
                DispatchQueue.main.async {
                    isLoading = false
                    debugPrint("OTP Verification success: \(success)")
                    if success {
                        appState.loadCredentials()
                        // Send notification to switch to Settings tab after successful OTP login
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            NotificationCenter.default.post(name: .switchToSettingsTab, object: nil)
                        }
                        onSuccess()
                    }
                }
            }

        case .profileUpdate:
            // For profile update: only verify OTP, don't complete user registration
            viewModel.verificationOTPOnly { success in
                DispatchQueue.main.async {
                    isLoading = false
                    if success {
                        // For profile update, just dismiss and let the parent handle success
                        presentation.wrappedValue.dismiss()
                        onSuccess()
                    }
                }
            }
        }
    }
}
