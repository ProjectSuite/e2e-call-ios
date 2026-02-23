import SwiftUI
import WebRTC

struct TwoPersonCallView: View {
    @ObservedObject private var publisherRtc = WebRTCManager.publisher
    @ObservedObject private var subscriberRtc = WebRTCManager.subscriber

    let isVideoCall: Bool
    let participantName: String
    let callStatus: CallStatus
    let callDuration: TimeInterval
    let isMuted: Bool
    let isVideoEnabled: Bool
    let isCameraOn: Bool?
    let isFrontCamera: Bool?
    let isSpeakerOn: Bool?
    let feedId: UInt64? // Participant's feedId to retrieve the correct video track (last feedId when rejoining)

    var body: some View {
        if isVideoCall {
            videoCallView
        } else {
            audioCallView
        }
    }

    // MARK: - Video Call View
    private var videoCallView: some View {
        ZStack {
            // Full screen remote video - use feedId to get the correct track (last feedId when rejoining)
            if let remoteVideoTrack = getRemoteVideoTrack() {
                VideoTrackRendererView(videoTrack: remoteVideoTrack, isMirrored: false)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()

                // Top-right status badges: video disabled (left) and mute (right)
                if isMuted || !isVideoEnabled {
                    VStack {
                        HStack(spacing: 8) {
                            Spacer()
                            // If both show: place video-left, mute-right. If only one, show that one.
                            if !isVideoEnabled {
                                Image(systemName: "video.slash.fill")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 20, height: 20)
                                    .padding(4)
                                    .foregroundColor(.white)
                                    .background(Color.red.opacity(0.8))
                                    .clipShape(Circle())
                            }

                            if isMuted {
                                Image(systemName: "mic.slash.fill")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 20, height: 20)
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

            } else {
                // Fallback when no video - same as audio view
                audioCallView
            }

            // Local video PIP (bottom left corner)
            if let localVideoTrack = publisherRtc.localVideoTrack {
                VStack {
                    Spacer()

                    HStack {
                        VideoTileView(
                            track: localVideoTrack,
                            name: "",
                            isMuted: false,
                            isMirrored: isFrontCamera ?? false
                        )
                        .aspectRatio(16/9, contentMode: .fit)
                        .frame(width: 150, height: 150)
                        .cornerRadius(12)
                        .shadow(radius: 8)

                        Spacer()
                    }
                }
                .padding(.bottom, 6)
                .padding(.leading, 6)
            }
        }
    }

    // MARK: - Audio Call View
    private var audioCallView: some View {
        VStack(spacing: 32) {
            ZStack(alignment: .bottomTrailing) {
                SmartAvatarView(
                    url: nil,
                    name: participantName,
                    size: 120
                )

                // Mute state icon (bottom-right)
                if isMuted == true {
                    Image(systemName: "mic.slash.fill")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(.white)
                        .padding(8)
                        .background(Color.red.opacity(0.8))
                        .clipShape(Circle())
                }
            }

            // Participant name
            Text(participantName)
                .font(.title2)
                .fontWeight(.medium)
                .foregroundColor(.white)

            // Call status/duration
            Text(callStatusText)
                .font(callStatus == .connected ? .headline : .subheadline)
                .foregroundColor(.white.opacity(0.8))

            Spacer()
        }
        .padding(.top, 80)
    }

    // MARK: - Helper Properties
    private var callStatusText: String {
        if callStatus == .connected {
            return AppUtils.getTimeDisplay(callDuration: Int(callDuration))
        } else {
            return callStatus.title
        }
    }

    /// Retrieve remote video track based on feedId (last feedId when rejoining)
    // If no feedId or feedId does not exist, fallback to the first track
    private func getRemoteVideoTrack() -> RTCVideoTrack? {
        // Prioritize using feedId if available (last feedId when rejoining)
        if let feedId = feedId, let track = subscriberRtc.remoteVideoTracks[feedId] {
            return track
        }

        // Fallback: Get the first track if there is no feedId or the feedId does not exist.
        if let firstTrack = subscriberRtc.remoteVideoTracks.first {
            return firstTrack.value
        }

        return nil
    }
}
