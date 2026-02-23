import SwiftUI

struct AudioParticipantTileView: View {
    let participant: Participant

    var body: some View {
        VStack(spacing: 6) {
            ZStack(alignment: .bottomTrailing) {
                SmartAvatarView(
                    url: nil,
                    name: participant.displayName,
                    size: 60
                )

                // Mute state icon (bottom-right)
                if participant.isMuted == true {
                    Image(systemName: "mic.slash.fill")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white)
                        .padding(4)
                        .background(Color.red.opacity(0.8))
                        .clipShape(Circle())
                }
            }

            let isLocal = participant.isLocal
            Text(isLocal ? KeyLocalized.You : participant.displayName)
                .font(.caption2)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .foregroundColor(.white)
                .background(isLocal ? Color.blue : .clear)
                .cornerRadius(4)

        }
    }
}
