import Foundation
import WebRTC

@objcMembers
class CustomVideoEncoder: NSObject, RTCVideoEncoder {

    private let wrappedEncoder: RTCVideoEncoder
    private var outerCallback: RTCVideoEncoderCallback?

    // —————————————————————————————————————————————————————————
    // Required protocol properties – give them defaults here!
    var resolutionAlignment: Int = 16
    var applyAlignmentToAllSimulcastLayers: Bool = false
    var supportsNativeHandle: Bool = false
    // —————————————————————————————————————————————————————————

    init(wrappedEncoder: RTCVideoEncoder) {
        self.wrappedEncoder = wrappedEncoder
        super.init()
    }

    // Store the user callback and register an inner one that encrypts the payload
    // func setCallback(_ callback: @escaping RTCVideoEncoderCallback) {
    func setCallback(_ callback: RTCVideoEncoderCallback?) {
        self.outerCallback = callback

        // let inner: RTCVideoEncoderCallback = { [weak self] frame, info, header in
        let inner: RTCVideoEncoderCallback = { [weak self] frame, info in
            guard let self = self else { return false }
            var raw = frame.buffer
            let nalus = H264NALUParser.parse(raw)
            var encryptedCount = 0
            for nalu in nalus {
                switch nalu.type {
                case .slice, .idr:
                    // compute where the payload really starts:
                    let payloadStart = nalu.range.lowerBound + nalu.headerLength + 1
                    let payloadEnd   = nalu.range.upperBound
                    // make sure we actually have payload bytes
                    guard payloadStart < payloadEnd else { continue }

                    let sliceRange = payloadStart..<payloadEnd
                    let sliceBytes = raw[sliceRange]
                    // encrypt only the slice RBSP, leave length + header alone
                    if let encrypted = CallEncryptionManager.shared.encryptCallMediaData(sliceBytes) {
                        raw.replaceSubrange(sliceRange, with: encrypted)
                        encryptedCount += 1
                        // debugLog("🔒 E2EE ⬢ Encrypted NALU \(nalu.type) at \(nalu.range)")
                    }
                default:
                    break
                }
            }
            frame.buffer = raw
            // return self.outerCallback?(frame, info, header) ?? false
            return self.outerCallback?(frame, info) ?? false
        }

        wrappedEncoder.setCallback(inner)
    }

    func startEncode(with settings: RTCVideoEncoderSettings, numberOfCores: Int32) -> Int {
        // debugLog("🔒 E2EE – startEncode \(settings.name) @ \(settings.width)x\(settings.height)")
        // let t0 = DispatchTime.now().uptimeNanoseconds
        // debugLog("📦 [ENC] startEncode \(settings.name) @ \(settings.width)x\(settings.height), cores=\(numberOfCores), t0=\(t0)")
        return wrappedEncoder.startEncode(with: settings, numberOfCores: numberOfCores)
    }

    func release() -> Int {
        return wrappedEncoder.release()
    }

    func encode(
        _ frame: RTCVideoFrame,
        codecSpecificInfo info: (any RTCCodecSpecificInfo)?,
        frameTypes: [NSNumber]
    ) -> Int {
        return wrappedEncoder.encode(frame, codecSpecificInfo: info, frameTypes: frameTypes)
    }

    func setBitrate(_ bitrateKbit: UInt32, framerate: UInt32) -> Int32 {
        return wrappedEncoder.setBitrate(bitrateKbit, framerate: framerate)
    }

    func implementationName() -> String {
        return "CustomVideoEncoder(\(wrappedEncoder.implementationName()))"
    }

    func scalingSettings() -> RTCVideoEncoderQpThresholds? {
        return wrappedEncoder.scalingSettings()
    }
}
