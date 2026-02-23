import SwiftUI

struct CallDetails: Identifiable {
    let id = UUID()
    let isVideo: Bool
}

struct ContactRow: View {
    let contact: Contact
    @EnvironmentObject var languageManager: LanguageManager

    @State private var callDetails: CallDetails?
    // Shared flag to disable all rows during call start
    @Binding var isStartingCall: Bool

    var body: some View {
        HStack {
            SmartAvatarView(
                url: nil,
                name: contact.contactName,
                size: 40
            )
            VStack(alignment: .leading) {
                Text(contact.contactName)
                    .bold()
                    .font(.subheadline)

                if let lastInteraction = contact.lastInteraction {
                    Text(AppUtils.relativeTime(from: lastInteraction))
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
            }

            Spacer()

            Button {
                guard !isStartingCall else { return }
                isStartingCall = true
                let details = CallDetails(isVideo: false)
                callDetails = details
                GroupCallManager.shared.startCall(to: [contact.contactName], calleeIDs: [contact.contactId], isVideo: details.isVideo)
                // Re-enable after 1 second to throttle taps
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    isStartingCall = false
                }
            } label: {
                CallMediaType.audio.icon
                    .resizable()
                    .scaledToFit()
                    .frame(width: 22, height: 22)
                    .foregroundColor(.cyan)
                    .padding(.horizontal, 10)
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(isStartingCall)
            .opacity(isStartingCall ? 0.6 : 1)

            Button {
                guard !isStartingCall else { return }
                isStartingCall = true
                let details = CallDetails(isVideo: true)
                callDetails = details
                GroupCallManager.shared.startCall(to: [contact.contactName], calleeIDs: [contact.contactId], isVideo: details.isVideo)
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    isStartingCall = false
                }
            } label: {
                CallMediaType.video.icon
                    .resizable()
                    .scaledToFit()
                    .frame(width: 26, height: 26)
                    .foregroundColor(.cyan)
                    .padding(.horizontal, 10)
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(isStartingCall)
            .opacity(isStartingCall ? 0.6 : 1)
        }
        .padding(.vertical, 2)
    }
}
