import SwiftUI

struct LoginMethodsInfoView: View {
    let isAppleConnected: Bool
    let isPhoneEnabled: Bool

    var body: some View {
        VStack {
            VStack(alignment: .leading, spacing: 16) {
                Text(KeyLocalized.login_methods_title)
                    .font(.title2)
                    .fontWeight(.bold)
                    .padding(.bottom, 10)

                Text(KeyLocalized.login_methods_description)
                    .font(.body)

                VStack(alignment: .leading, spacing: 12) {
                    Label("Email / Gmail", systemImage: "envelope.fill")
                    if isPhoneEnabled {
                        Label(KeyLocalized.phone_number, systemImage: "phone.fill")
                    }

                    if isAppleConnected {
                        Label(KeyLocalized.sign_in_with_apple, systemImage: "applelogo")
                    }
                }
                .font(.headline)
            }
            .padding(.horizontal, 12)
        }
    }
}
