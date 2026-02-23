import SwiftUI
import WebRTC

struct VideoTileView: View {
    let track: RTCVideoTrack?
    let name: String            // Participant name (or "" for none)
    let isMuted: Bool           // Whether participant’s audio is muted
    let isMirrored: Bool        // Whether to mirror the video (for local camera)

    var body: some View {
        ZStack(alignment: .bottom) {
            // Video renderer or placeholder
            if let videoTrack = track {
                VideoTrackRendererView(videoTrack: videoTrack, isMirrored: isMirrored)
                    .aspectRatio(3/4, contentMode: .fill)
                    .clipped()
            } else {
                // Placeholder for no video: colored background with initial or icon
                ZStack {
                    Rectangle().fill(Color.gray.opacity(0.6))
                    if !name.isEmpty {
                        Text(String(name.prefix(1)))  // first initial
                            .font(.largeTitle).bold()
                            .foregroundColor(.white)
                    } else {
                        Image(systemName: "person.fill")
                            .resizable().scaledToFit()
                            .frame(width: 40, height: 40)
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
            }
            // Overlay: name and mute icon bar
            if !(name.isEmpty && !isMuted) {
                HStack {
                    if !name.isEmpty {
                        Text(name)
                            .foregroundColor(.white)
                            .font(.footnote)
                            .lineLimit(1)
                    }
                    Spacer()
                    if isMuted {
                        Image(systemName: "mic.slash.fill")
                            .foregroundColor(.white)
                            .font(.footnote)
                    }
                }
                .padding(6)
                .background(Color.black.opacity(0.5))
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .padding([.horizontal, .bottom], 4)
            }
        }
        .cornerRadius(8)
        .shadow(color: Color.black.opacity(0.3), radius: 4)
    }
}
