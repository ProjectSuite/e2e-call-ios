import SwiftUI

struct MultiPersonAudioView: View {
    let participants: [Participant]
    let callStatus: CallStatus
    let callDuration: TimeInterval
    let isMuted: Bool
    let isSpeakerOn: Bool

    private let spacing: CGFloat = 8

    var body: some View {
        ScrollView {
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: spacing),
                GridItem(.flexible(), spacing: spacing),
                GridItem(.flexible(), spacing: spacing)
            ], spacing: spacing) {
                ForEach(participants, id: \.userId) { participant in
                    ZStack {
                        Color.gray.opacity(0.4)
                            .cornerRadius(12)

                        AudioParticipantTileView(
                            participant: participant
                        )
                    }
                    .aspectRatio(1, contentMode: .fit)
                }
            }
            .padding(.horizontal, spacing)
            .padding(.top, 12)
            .padding(.bottom, 8)
        }
    }
}
