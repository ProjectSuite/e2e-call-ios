import SwiftUI
import WebRTC

// MARK: - VideoTrackRendererView Component
struct VideoTrackRendererView: UIViewRepresentable {
    let videoTrack: RTCVideoTrack
    let isMirrored: Bool

    func makeUIView(context: Context) -> RTCMTLVideoView {
        let videoView = RTCMTLVideoView(frame: .zero)
        videoView.videoContentMode = .scaleAspectFill

        if isMirrored {
            videoView.transform = CGAffineTransform(scaleX: -1, y: 1)
        }

        // Attach the video track to this renderer
        videoTrack.add(videoView)
        context.coordinator.videoView = videoView
        context.coordinator.videoTrack = videoTrack
        return videoView
    }

    func updateUIView(_ uiView: RTCMTLVideoView, context: Context) {
        if context.coordinator.videoTrack !== videoTrack {
            debugLog("🔄 VideoTrack changed - updating renderer")

            // Remove old track
            if let oldTrack = context.coordinator.videoTrack {
                oldTrack.remove(uiView)
            }

            // Add new track
            videoTrack.add(uiView)
            context.coordinator.videoTrack = videoTrack
        }

        // Update mirror transform
        let shouldMirror = isMirrored
        let isMirrored = uiView.transform.a == -1
        if shouldMirror != isMirrored {
            uiView.transform = shouldMirror ? CGAffineTransform(scaleX: -1, y: 1) : .identity
        }
    }

    static func dismantleUIView(_ uiView: RTCMTLVideoView, coordinator: Coordinator) {
        if let track = coordinator.videoTrack {
            track.remove(uiView)
        }
        coordinator.videoView = nil
        coordinator.videoTrack = nil
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator {
        var videoView: RTCMTLVideoView?
        var videoTrack: RTCVideoTrack?
    }
}
