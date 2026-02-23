import SwiftUI
import WebRTC
import AVFoundation

struct VideoParticipantTileView: View {
    let participant: Participant
    let videoTrack: RTCVideoTrack?

    var body: some View {
        ZStack {
            // Background
            Color.gray.opacity(0.4)

            // Content
            if let videoTrack = videoTrack {
                // Video mode
                videoContentView(videoTrack: videoTrack)

                // Local participant indicator
                if participant.isLocal {
                    localParticipantIndicator
                }

                if participant.isMuted == true || participant.isVideoEnabled == false {
                    VStack {
                        HStack(spacing: 6) {
                            Spacer()

                            if participant.isVideoEnabled == false {
                                Image(systemName: "video.slash.fill")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 12, height: 12)
                                    .padding(4)
                                    .foregroundColor(.white)
                                    .background(Color.red.opacity(0.8))
                                    .clipShape(Circle())
                            }

                            if participant.isMuted == true {
                                Image(systemName: "mic.slash.fill")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 12, height: 12)
                                    .padding(4)
                                    .foregroundColor(.white)
                                    .background(Color.red.opacity(0.8))
                                    .clipShape(Circle())
                            }
                        }

                        Spacer()
                    }
                    .padding(8)
                }

                // User name overlay at bottom
                VStack {
                    Spacer()
                    HStack {
                        Text(participant.displayName)
                            .font(.caption)
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.black.opacity(0.6))
                            .cornerRadius(4)

                        Spacer()
                    }
                }
                .padding(8)

            } else {
                // Audio mode or no video
                audioContentView
            }
        }
        .id("\(participant.userId)_\(participant.feedId ?? 0)")
    }

    // MARK: - Video Content View
    @ViewBuilder
    private func videoContentView(videoTrack: RTCVideoTrack) -> some View {
        GeometryReader { geometry in
            VideoTrackRendererView(
                videoTrack: videoTrack,
                isMirrored: participant.isLocal && WebRTCManager.publisher.currentCameraPosition == .front
            )
                .frame(width: geometry.size.width, height: geometry.size.height)
                .aspectRatio(1, contentMode: .fill)
                .clipped()
        }
    }

    // MARK: - Audio Content View
    private var audioContentView: some View {
        AudioParticipantTileView(participant: participant)
    }

    // MARK: - Local Participant Indicator
    private var localParticipantIndicator: some View {
        VStack {
            HStack(spacing: 8) {
                Text(KeyLocalized.You)
                    .font(.caption2)
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.blue)
                    .cornerRadius(4)
                Spacer()
            }

            Spacer()
        }
        .padding(8)
    }
}
