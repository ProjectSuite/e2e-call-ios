import Foundation
import LocalAuthentication

@MainActor
class BiometricAuthManager: ObservableObject {
    static let shared = BiometricAuthManager()

    @Published var isAuthenticated = false
    @Published var biometricType: LABiometryType = .none

    private init() {
        checkBiometricType()
    }

    private func checkBiometricType() {
        let context = LAContext()
        var error: NSError?

        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            biometricType = context.biometryType
        } else {
            biometricType = .none
        }
    }

    func authenticate(reason: String = KeyLocalized.biometric_reason_generic) async -> Bool {
        let context = LAContext()
        var error: NSError?

        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            // Fallback to passcode
            return await authenticateWithPasscode(reason: reason)
        }

        do {
            let success = try await context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason)
            isAuthenticated = success
            return success
        } catch {
            debugLog("Biometric authentication failed: \(error.localizedDescription)")
            // Fallback to passcode
            return await authenticateWithPasscode(reason: reason)
        }
    }

    private func authenticateWithPasscode(reason: String = KeyLocalized.biometric_reason_generic) async -> Bool {
        let context = LAContext()
        var error: NSError?

        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            debugLog("Passcode authentication not available: \(error?.localizedDescription ?? "Unknown error")")
            return false
        }

        do {
            let success = try await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason)
            isAuthenticated = success
            return success
        } catch {
            debugLog("Passcode authentication failed: \(error.localizedDescription)")
            return false
        }
    }

    func resetAuthentication() {
        isAuthenticated = false
    }
}
