import SwiftUI

struct SentRequestRow: View {
    let request: FriendRequest
    let onCancel: () -> Void
    @EnvironmentObject private var languageManager: LanguageManager

    var body: some View {
        HStack(spacing: 12) {
            SmartAvatarView(
                url: nil,
                name: request.receiverName,
                size: 40
            )

            VStack(alignment: .leading, spacing: 2) {
                Text(request.receiverName)
                    .font(.subheadline)
                    .bold()
                Text(request.dateDisplay)
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }

            Spacer()

            Button(action: onCancel) {
                Text(KeyLocalized.cancel)
            }
            .buttonStyle(RecallButtonStyle())
        }
        .background(Color(.systemBackground))
    }
}

struct RecallButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline)
            .bold()
            .foregroundColor(.black)
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.gray, lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}
