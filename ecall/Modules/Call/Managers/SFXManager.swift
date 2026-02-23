import Foundation
import AVFoundation

final class SFXManager {
    static let shared = SFXManager()
    private var player: AVAudioPlayer?

    private init() {}

    private func play(fileName: String, loop: Bool) {
        guard let url = Bundle.main.url(forResource: fileName, withExtension: nil) else {
            errorLog(" SFX file not found: \(fileName)")
            return
        }
        do {
            player = try AVAudioPlayer(contentsOf: url)
            player?.numberOfLoops = loop ? -1 : 0
            player?.prepareToPlay()
            player?.play()
        } catch {
            errorLog(" Failed to play SFX \(fileName): \(error)")
        }
    }

    func stop() {
        player?.stop()
        player = nil
    }

    func playRingback() { play(fileName: "ringback.mp3", loop: true) }
    func playEndCall() { play(fileName: "end_call.mp3", loop: false) }
    func playReconnect() { play(fileName: "reconnect.mp3", loop: true) }
}
