import SwiftUI
import GoogleSignIn
import GoogleSignInSwift

struct GoogleSignInView: View {
    var body: some View {
        Button(KeyLocalized.continue_with_google) {
            continueWithGoogle()
        }
    }

    func continueWithGoogle() {
        guard let rootVC = UIApplication.shared.connectedScenes
                .compactMap({ ($0 as? UIWindowScene)?.keyWindow?.rootViewController })
                .first else {
            return
        }

        // Gọi signIn
        GIDSignIn.sharedInstance.signIn(withPresenting: rootVC) { result, error in
            if error != nil {
                return
            }

            guard result?.user != nil else { return }
        }
    }
}
