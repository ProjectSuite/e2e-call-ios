import Foundation
import WebRTC

@objcMembers
class CustomVideoDecoderFactory: NSObject, RTCVideoDecoderFactory {
    // 1) Just declare the property—no default here:
    private let baseFactory: RTCVideoDecoderFactory

    // 2) In your init, supply a default for baseFactory if you like:
    override init() {
        // self.baseFactory = RTCVideoDecoderFactoryH264()
        self.baseFactory = RTCDefaultVideoDecoderFactory()
        super.init()
    }

    func supportedCodecs() -> [RTCVideoCodecInfo] {
        return baseFactory.supportedCodecs()
    }

    func createDecoder(_ info: RTCVideoCodecInfo) -> (any RTCVideoDecoder)? {
        guard let decoder = baseFactory.createDecoder(info) else { return nil }
        return CustomVideoDecoder(wrappedDecoder: decoder)
    }
}
