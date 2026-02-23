import SwiftUI

struct ReceivedRequestRow: View {
    @EnvironmentObject var languageManager: LanguageManager
    let request: FriendRequest
    let onAccept: () -> Void
    let onDecline: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 12) {
                SmartAvatarView(
                    url: nil,
                    name: request.receiverName,
                    size: 40
                )

                VStack(alignment: .leading, spacing: 2) {
                    Text(request.receiverName)
                        .font(.subheadline)
                        .bold()
                    Text(KeyLocalized.wants_to_be_friends)
                        .font(.subheadline)
                }
                Spacer()
            }

            HStack(spacing: 12) {
                Button {
                    onDecline()
                } label: {
                    Text(KeyLocalized.decline)
                        .font(.subheadline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .foregroundColor(.black)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.gray, lineWidth: 1)
                        )
                }

                Button {
                    onAccept()
                } label: {
                    Text(KeyLocalized.accept)
                        .font(.subheadline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .foregroundColor(.cyan)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.cyan, lineWidth: 1)
                        )
                }
            }
        }
        .padding(.vertical, 8)
        .background(Color.white)
    }
}
