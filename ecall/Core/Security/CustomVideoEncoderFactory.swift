import Foundation
import WebRTC

@objcMembers
class CustomVideoEncoderFactory: NSObject, RTCVideoEncoderFactory {
    private let baseFactory: RTCVideoEncoderFactory

    override init() {
        self.baseFactory = RTCDefaultVideoEncoderFactory()
        // self.baseFactory = RTCVideoEncoderFactoryH264()
        super.init()
    }

    func supportedCodecs() -> [RTCVideoCodecInfo] {
        return baseFactory.supportedCodecs()
    }

    func createEncoder(_ info: RTCVideoCodecInfo) -> (any RTCVideoEncoder)? {
        guard let encoder = baseFactory.createEncoder(info) else { return nil }
        return CustomVideoEncoder(wrappedEncoder: encoder)
    }
}
