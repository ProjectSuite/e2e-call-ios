import SwiftUI
import GoogleSignInSwift
import AuthenticationServices
import UIKit

struct AuthFlowMainView: View {
    @EnvironmentObject var languageManager: LanguageManager
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var appConfig: AppConfigurationStore

    @StateObject private var viewModel = AuthViewModel()
    @State private var showEmailForm = false
    @State private var showPhoneForm = false
    @State private var navigateToOtp = false
    @State private var isLoading = false
    @State private var appleCoordinator: AppleSignInCoordinator?

    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                gradient: Gradient(colors: [Color.blue.opacity(0.1), Color.white]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            // Centered card container
            VStack {
                Spacer()

                VStack(spacing: 36) {
                    VStack(spacing: 16) {
                        Image("Logo")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 100, height: 100)
                            .cornerRadius(8)

                        Text(KeyLocalized.app_title)
                            .font(.system(size: 28, weight: .bold))

                    }
                    .padding(.top, 16)

                    VStack(spacing: 16) {
                        if appConfig.config.twilioConfigured {
                            AuthButton(
                                title: KeyLocalized.continue_with_phone,
                                systemImage: "phone.fill",
                                disabled: isLoading
                            ) {
                                viewModel.clearError()
                                viewModel.type = .phoneNumber
                                showPhoneForm = true
                            }
                        }

                        AuthButton(
                            title: KeyLocalized.continue_with_email,
                            systemImage: "envelope.fill",
                            disabled: isLoading
                        ) {
                            viewModel.clearError()
                            viewModel.type = .email
                            showEmailForm = true
                        }

                        Text(KeyLocalized.or_separator)
                            .font(.system(size: 16))
                            .foregroundColor(.gray)

                        AuthButton(
                            title: KeyLocalized.continue_with_google,
                            customImage: Image("googleLogin"),
                            disabled: isLoading
                        ) {
                            continueWithGoogle()
                        }

                        if appConfig.config.appleLoginConfigured {
                            AuthButton(
                                title: KeyLocalized.continue_with_apple,
                                systemImage: "applelogo",
                                disabled: isLoading
                            ) {
                                signInWithApple()
                            }
                        }
                    }
                    .padding(.horizontal, 32)
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 16)

                Spacer()
            }
            .fullScreenCover(isPresented: $showEmailForm) {
                EmailAuthFormView(
                    viewModel: viewModel,
                    isLoading: $isLoading
                ) {
                    showEmailForm = false
                    navigateToOtp = true
                }
            }
            .fullScreenCover(isPresented: $showPhoneForm) {
                PhoneAuthFormView(
                    viewModel: viewModel,
                    isLoading: $isLoading
                ) {
                    showPhoneForm = false
                    navigateToOtp = true
                }
            }
            .fullScreenCover(isPresented: $navigateToOtp) {
                OTPVerificationView(viewModel: viewModel) {}
            }
            .sheet(isPresented: $viewModel.showPendingDeletionSheet) {
                DeleteAccountView(onCancelDeletionSuccess: {
                    viewModel.onCancelDeletionFromLogin()
                })
                .environmentObject(appState)
                .presentationDetents([.large])
                .interactiveDismissDisabled(true)
            }
            .task {
                await appConfig.refresh()
            }
            .logViewName()

            // Loading overlay
            if isLoading {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(1.5)
            }
        }
    }

    private func continueWithGoogle() {
        isLoading = true
        viewModel.googleSignIn { _ in
            isLoading = false
        }
    }

    private func signInWithApple() {
        isLoading = true

        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.fullName, .email]

        let controller = ASAuthorizationController(authorizationRequests: [request])
        let coordinator = AppleSignInCoordinator()
        coordinator.onResult = { result in
            switch result {
            case .success(let credential):
                handleAppleCredential(credential)
            case .failure(let error):
                handleAppleError(message: error.localizedDescription)
            }
        }
        controller.delegate = coordinator
        controller.presentationContextProvider = coordinator
        appleCoordinator = coordinator
        controller.performRequests()
    }

    private func handleAppleCredential(_ credential: ASAuthorizationAppleIDCredential) {
        guard let codeData = credential.authorizationCode,
              let code = String(data: codeData, encoding: .utf8) else {
            handleAppleError(message: KeyLocalized.invalid_data)
            return
        }
        let appleIdToken = credential.identityToken.flatMap { String(data: $0, encoding: .utf8) }

        let displayName = resolveDisplayName(from: credential)

        // Call Apple login API (publicKey is ensured at app startup and read from KeyStorage)
        viewModel.appleLogin(code: code, appleIdToken: appleIdToken, displayName: displayName) { _ in
            isLoading = false
        }
    }

    private func resolveDisplayName(from credential: ASAuthorizationAppleIDCredential) -> String {
        if let nameComponents = credential.fullName {
            let formatter = PersonNameComponentsFormatter()
            formatter.style = .medium
            let formattedName = formatter.string(from: nameComponents).trimmingCharacters(in: .whitespacesAndNewlines)
            if !formattedName.isEmpty {
                return formattedName
            }
        }
        if let email = credential.email, !email.isEmpty {
            return email
        }
        if !viewModel.displayName.isEmpty {
            return viewModel.displayName
        }
        return "Apple User"
    }

    private func handleAppleError(message: String) {
        isLoading = false
        viewModel.errorMessage = message
        viewModel.showError = true
    }
}

private final class AppleSignInCoordinator: NSObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    var onResult: ((Result<ASAuthorizationAppleIDCredential, Error>) -> Void)?

    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first(where: \.isKeyWindow) ?? UIWindow()
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            let error = NSError(domain: "AppleSignIn", code: -1, userInfo: [NSLocalizedDescriptionKey: KeyLocalized.user_not_found])
            onResult?(.failure(error))
            return
        }
        onResult?(.success(credential))
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        onResult?(.failure(error))
    }
}
