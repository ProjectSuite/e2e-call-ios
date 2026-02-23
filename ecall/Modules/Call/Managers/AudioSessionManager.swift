import AVFoundation
import UIKit
import WebRTC

class AudioSessionManager {
    static let shared = AudioSessionManager()
    static let audioSession = RTCAudioSession.sharedInstance()

    private init() {}

    /// Call this once when the call starts (pass in both flags)
    func configureAudioSession() {
        let session = AVAudioSession.sharedInstance()
        let isVideoCall = GroupCallSessionManager.shared.isVideoCall
        let isSpeakerOn = GroupCallSessionManager.shared.isSpeakerOn
        do {
            // 1) Always use playAndRecord so you can toggle speaker later.
            try session.setCategory(.playAndRecord,
                                    options: [.allowBluetoothHFP, .allowBluetoothA2DP])
            // 2) Mode depends on *video* vs *audio*—not on speaker!
            try session.setMode(isVideoCall ? .videoChat : .voiceChat)
            // 3) Activate before overriding
            try session.setActive(true)
            // 4) Route explicitly
            try session.overrideOutputAudioPort(isSpeakerOn ? .speaker : .none)
        } catch {
            errorLog(error)
        }
    }

    func deactivateAudioSession() {
        let rtcAudio = RTCAudioSession.sharedInstance()
        rtcAudio.lockForConfiguration()
        rtcAudio.isAudioEnabled = false      // ← cleanly mute WebRTC
        rtcAudio.unlockForConfiguration()

        let session = AVAudioSession.sharedInstance()
        do {
            try session.setActive(false)
            debugLog("Audio session deactivated.")
        } catch {
            errorLog(error)
        }
    }

    // MARK: - Screen Lock Control

    /// Control screen auto-lock during call
    /// - Parameter enabled: true to keep screen on, false to allow auto-lock
    func setKeepScreenOn(_ enabled: Bool) {
        DispatchQueue.main.async {
            UIApplication.shared.isIdleTimerDisabled = enabled
            debugLog("Screen auto-lock: \(enabled ? "disabled (keep on)" : "enabled")")
        }
    }

}
