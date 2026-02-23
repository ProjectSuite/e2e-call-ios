import SwiftUI
import AVFoundation

struct ControlButtonConfig {
    let iconName: String
    let isActive: Bool
    let activeColor: Color
    let activeBackground: Color
    let inactiveBackground: Color
}

struct CallControlsView: View {
    @Binding var isMuted: Bool
    @Binding var isCameraOn: Bool
    @Binding var isSpeakerOn: Bool

    let isVideoCall: Bool

    // Callbacks
    var onToggleMute: (Bool) -> Void
    var onToggleCamera: (Bool) -> Void
    var onToggleSpeaker: (Bool) -> Void
    var onEndCall: () -> Void
    var onFlipCamera: (() -> Void)?

    var body: some View {
        HStack(spacing: 40) {
            // Speaker toggle
            if !isVideoCall {
                controlButton(
                    config: ControlButtonConfig(
                        iconName: isSpeakerOn ? "speaker.wave.2.fill" : "speaker.wave.1.fill",
                        isActive: isSpeakerOn,
                        activeColor: .accentColor,
                        activeBackground: Color.white,
                        inactiveBackground: Color.white.opacity(0.3)
                    ),
                    action: toggleSpeaker
                )
            }

            if isVideoCall {
                controlButton(
                    config: ControlButtonConfig(
                        iconName: isCameraOn ? "video.fill" : "video.slash.fill",
                        isActive: isCameraOn,
                        activeColor: .accentColor,
                        activeBackground: Color.white,
                        inactiveBackground: Color.white.opacity(0.3)
                    ),
                    action: {
                        isCameraOn.toggle()
                        onToggleCamera(isCameraOn)
                    }
                )
                // Rotate camera
                controlButton(
                    config: ControlButtonConfig(
                        iconName: "camera.rotate",
                        isActive: true,
                        activeColor: .accentColor,
                        activeBackground: Color.white,
                        inactiveBackground: Color.white.opacity(0.3)
                    ),
                    action: {
                        onFlipCamera?()
                    }
                )
            }

            // Mute/unmute
            controlButton(
                config: ControlButtonConfig(
                    iconName: isMuted ? "mic.slash.fill" : "mic.fill",
                    isActive: !isMuted,
                    activeColor: .accentColor,
                    activeBackground: Color.white,
                    inactiveBackground: Color.white.opacity(0.3)
                ),
                action: {
                    isMuted.toggle()
                    onToggleMute(isMuted)
                }
            )

            // End call
            controlButton(
                config: ControlButtonConfig(
                    iconName: "phone.down.fill",
                    isActive: true,
                    activeColor: .white,
                    activeBackground: .red,
                    inactiveBackground: .clear
                ),
                action: onEndCall
            )
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 10)
    }

    /// Toggles audio output to speaker or earpiece
    private func toggleSpeaker() {
        let session = AVAudioSession.sharedInstance()
        let newValue = !isSpeakerOn
        do {
            var options: AVAudioSession.CategoryOptions = [.allowBluetoothHFP, .allowBluetoothA2DP]
            if newValue {
                options.insert(.defaultToSpeaker)
            }
            try session.setCategory(.playAndRecord, options: options)
            try session.setActive(true)
            isSpeakerOn = newValue
            GroupCallSessionManager.shared.isSpeakerOn = newValue
            onToggleSpeaker(newValue)
        } catch {
            debugLog("Error toggling speaker: \(error)")
        }
    }

    /// Generic control button with icon + label
    @ViewBuilder
    private func controlButton(config: ControlButtonConfig, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: config.iconName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 24, height: 24)
                    .foregroundColor(config.isActive ? config.activeColor : .white)
                    .padding(16)
                    .background(config.isActive ? config.activeBackground : config.inactiveBackground)
                    .clipShape(Circle())
            }
        }
    }
}
