import SwiftUI
import GoogleSignIn

enum IdentityType {
    case email, phoneNumber, apple
}

class AuthViewModel: ObservableObject {
    @Published var userID: UInt64 = 0
    @Published var displayName: String = ""
    @Published var email: String = ""
    @Published var phoneNumber: String = ""
    @Published var verified = false
    @Published var otp: String = ""
    @Published var showError: Bool = false
    @Published var errorMessage: String = ""
    @Published var type: IdentityType = .email

    private let authService = AuthService()

    /// Verify OTP and save immediately for email/phone flows
    func verifyLogin(_ completion: @escaping (Bool) -> Void) {
        Task { @MainActor in
            let success = await verifyLogin()
            completion(success)
        }
    }

    @MainActor
    func verifyLogin() async -> Bool {
        guard !otp.isEmpty else {
            showErrorMessage(KeyLocalized.otp_required)
            return false
        }

        let result = await authService.verifyLogin(
            email: email,
            phoneNumber: phoneNumber,
            code: otp,
            type: type
        )

        switch result {
        case .success(let response):
            clearError()
            // Access token is required to complete login
            guard let token = response.accessToken, !token.isEmpty else {
                showErrorMessage(KeyLocalized.unknown_error_try_again)
                return false
            }

            handleLoginSuccessAfterVerified(response)
            debugLog("OTP verification success for user: \(email)")
            return true
        case .failure(let error):
            errorLog(error.content)
            showErrorMessage(error.content)
            return false
        }
    }

    func verificationOTPOnly(_ completion: @escaping (Bool) -> Void) {
        Task { @MainActor in
            let success = await verificationOTPOnly()
            completion(success)
        }
    }

    @MainActor
    func verificationOTPOnly() async -> Bool {
        guard !otp.isEmpty else {
            showErrorMessage(KeyLocalized.otp_required)
            return false
        }

        let result = await authService.verifyUser(
            email: email,
            phoneNumber: phoneNumber,
            code: otp,
            type: type
        )

        switch result {
        case .success:
            clearError()
            return true
        case .failure(let error):
            showErrorMessage(error.content)
            return false
        }
    }

    func resendOTP(_ completion: @escaping (Bool) -> Void) {
        Task { @MainActor in
            let success = await resendOTP()
            completion(success)
        }
    }

    @MainActor
    func resendOTP() async -> Bool {
        otp = ""

        var isUsingPhone = true

        switch type {
        case .email:
            guard !email.isEmpty else {
                showErrorMessage(KeyLocalized.email_required)
                return false
            }
            isUsingPhone = false

        case .phoneNumber:
            guard !phoneNumber.isEmpty else {
                showErrorMessage(KeyLocalized.phoneNumber_required)
                return false
            }
        case .apple:
            return false
        }
        // case resendOTP with account have both method (emai/phone) receiver OTP, should using only target type (email or phone)
        let result = await authService.resendOTP(
            email: isUsingPhone ? "" : email,
            phoneNumber: isUsingPhone ? phoneNumber : ""
        )

        switch result {
        case .success:
            clearError()
            return true
        case .failure(let error):
            errorLog(error.content)
            showErrorMessage(error.content)
            return false
        }
    }

    func resetState() {
        verified = false

        clearError()
    }

    /// Login for email/phone (requires OTP verification before finalization)
    func loginApp(_ completion: @escaping (Bool) -> Void) {
        Task { @MainActor in
            let success = await loginApp()
            completion(success)
        }
    }

    @MainActor
    func loginApp() async -> Bool {
        switch type {
        case .email:
            guard email.isValidEmail else {
                showErrorMessage(KeyLocalized.invalid_email_format)
                return false
            }
        case .phoneNumber:
            debugLog("phone number", phoneNumber)
            guard !phoneNumber.isEmpty else {
                showErrorMessage(KeyLocalized.invalid_phone_format)
                return false
            }

        case .apple:
            return false
        }

        let result = await authService.login(
            email: email,
            phoneNumber: phoneNumber,
            displayName: displayName,
            verified: verified
        )

        switch result {
        case .success(let response):
            clearError()
            // Persist basic profile fields from login response
            userID = response.userId ?? 0
            displayName = response.displayName ?? displayName
            email = response.email ?? email
            phoneNumber = response.phoneNumber ?? phoneNumber
            if let token = response.accessToken, !token.isEmpty {
                // Verified=true: token present -> mark verified and save immediately
                verified = true
                handleLoginSuccess(response: response)
            } else {
                // Verified=false: go to OTP (do not save yet)
                verified = false
            }
            return true
        case .failure(let error):
            errorLog(error.content)
            showErrorMessage(error.content)
            return false
        }
    }

    /// Apple login (pre-verified, saves immediately)
    func appleLogin(code: String, appleIdToken: String?, displayName: String, completion: @escaping (Bool) -> Void) {
        Task { @MainActor in
            let success = await appleLogin(code: code,
                                          appleIdToken: appleIdToken,
                                          displayName: displayName)
            completion(success)
        }
    }

    @MainActor
    func appleLogin(code: String,
                    appleIdToken: String?,
                    displayName: String) async -> Bool {
        let result = await authService.appleLogin(
            code: code,
            appleIdToken: appleIdToken,
            displayName: displayName
        )

        switch result {
        case .success(let response):
            verified = true
            type = .apple
            // For Apple: save immediately (no OTP needed)
            handleLoginSuccess(response: response)
            return true
        case .failure(let error):
            errorLog(error.content)
            ToastManager.shared.error(error.content)
            return false
        }
    }

    func googleSignIn(completion: @escaping (Bool) -> Void) {
        // Find the active key window’s rootViewController
        guard let windowScene = UIApplication.shared
                .connectedScenes
                .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene,
              let rootVC = windowScene
                .windows
                .first(where: \.isKeyWindow)?
                .rootViewController else {
            self.showErrorMessage(KeyLocalized.no_root_view_controller)
            completion(false)
            return
        }

        authService.googleSignOn(from: rootVC) { (result: Result<GIDGoogleUser, Error>) in
            DispatchQueue.main.async {
                switch result {
                case .success(let user):
                    self.displayName = user.profile?.name ?? ""
                    self.email = user.profile?.email ?? ""
                    self.clearError()
                    self.verified = true
                    self.type = .email

                    self.loginApp { success in
                        completion(success)
                    }

                case .failure(let error):
                    errorLog(error.localizedDescription)
                    ToastManager.shared.error(error.localizedDescription)
                    completion(false)
                }
            }
        }
    }

    private func storeUserInfosInKeychain(accessToken: String, refreshToken: String? = nil) {
        let userIdString = "\(userID)"
        let publicKey = KeyStorage.shared.readPublicKey() ?? ""
        let privateKey = KeyStorage.shared.readPrivateKeyString() ?? ""

        let identitySuccess = KeyStorage.shared.storeUserIdentity(userId: userIdString,
                                                                 email: email,
                                                                 phoneNumber: phoneNumber,
                                                                 displayName: displayName)
        let keysSuccess = KeyStorage.shared.storeUserKeys(publicKey: publicKey, privateKey: privateKey)
        let tokensSuccess = KeyStorage.shared.storeUserTokens(accessToken: accessToken, refreshToken: refreshToken)

        if identitySuccess && keysSuccess && tokensSuccess {
            debugLog("✅ User info stored successfully in Keychain.")
        } else {
            debugLog("Failed to store user info in Keychain.")
        }
    }

    private func showErrorMessage(_ msg: String) {
        errorMessage = msg
        showError = true
    }

    func clearError() {
        errorMessage = ""
        showError = false
    }

    func clearKeys() {
        displayName = ""
        email = ""
        phoneNumber = ""
        otp = ""
        userID = 0
    }

    private static func getIdentifier() -> String {
        var systemInfo = utsname()
        uname(&systemInfo)
        return withUnsafePointer(to: &systemInfo.machine) { ptr in
            return String(cString: UnsafeRawPointer(ptr).assumingMemoryBound(to: CChar.self))
        }
    }

    // MARK: - Navigation & persistence glue
    @MainActor
    private func routeToMainTab() {
        let app = AppState.shared
        app.userID = String(self.userID)
        app.displayName = self.displayName
        app.email = self.email
        app.phoneNumber = self.phoneNumber
        app.isRegistered = !app.userID.isEmpty && !app.publicKey.isEmpty

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            NotificationCenter.default.post(name: .switchToSettingsTab, object: nil)
        }
    }

    private func handleLoginSuccessAfterVerified(_ response: VerifyResponse) {
        clearError()

        // Mark verified and persist credentials
        self.verified = true
        self.storeUserInfosInKeychain(accessToken: response.accessToken ?? "", refreshToken: response.refreshToken)
        StompSignalingManager.shared.onLoginCompleted(deviceId: String(response.deviceId ?? 0))

        // Route to Main tab via central VM method
        Task { @MainActor in
            AppState.shared.deletedAt = response.deletedAt
            self.routeToMainTab()
        }
    }

    private func handleLoginSuccess(response: AuthResponse) { // no verify
        clearError()

        userID = response.userId ?? 0
        displayName = response.displayName ?? ""
        email = response.email ?? ""
        phoneNumber = response.phoneNumber ?? ""

        // Save user data to keychain including refreshToken
        storeUserInfosInKeychain(accessToken: response.accessToken ?? "", refreshToken: response.refreshToken)

        // Save Apple login flag if applicable
        KeyStorage.shared.storeAppleLoginFlag(self.type == .apple)

        // Notify signaling manager
        StompSignalingManager.shared.onLoginCompleted(deviceId: String(response.deviceId ?? 0))

        debugLog("Login success for user: \(email)")
        Task { @MainActor in
            AppState.shared.deletedAt = response.deletedAt
            routeToMainTab()
        }
    }
}
