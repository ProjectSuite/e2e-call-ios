import Foundation
import WebRTC

/// Custom video decoder that wraps an underlying RTCVideoDecoder.

@objcMembers
class CustomVideoDecoder: NSObject, RTCVideoDecoder {

    private let wrappedDecoder: RTCVideoDecoder
    private var callback: RTCVideoDecoderCallback?

    init(
        wrappedDecoder: RTCVideoDecoder
    ) {
        self.wrappedDecoder = wrappedDecoder
        super.init()
    }

    /// Store the callback and pass it on to the underlying decoder.
    func setCallback(_ callback: @escaping RTCVideoDecoderCallback) {
        self.callback = callback
        wrappedDecoder.setCallback(callback)
    }

    /// Start the decoder on the given number of cores.
    func startDecode(withNumberOfCores numberOfCores: Int32) -> Int {
        return wrappedDecoder.startDecode(withNumberOfCores: numberOfCores)
    }

    /// Release decoder resources.
    func release() -> Int {
        // Note: the underlying API calls this `releaseDecoder()`.
        return wrappedDecoder.release()
    }

    /// Decrypt each encoded frame before passing it to the real decoder.
    func decode(
        _ encodedImage: RTCEncodedImage,
        missingFrames: Bool,
        codecSpecificInfo info: (any RTCCodecSpecificInfo)?,
        renderTimeMs: Int64
    ) -> Int {
        // 1) copy metadata into a new RTCEncodedImage

        let modified = RTCEncodedImage()
        modified.encodedWidth   = encodedImage.encodedWidth
        modified.encodedHeight  = encodedImage.encodedHeight
        modified.timeStamp      = encodedImage.timeStamp
        modified.captureTimeMs  = encodedImage.captureTimeMs
        modified.ntpTimeMs      = encodedImage.ntpTimeMs
        modified.flags          = encodedImage.flags
        modified.encodeStartMs  = encodedImage.encodeStartMs
        modified.encodeFinishMs = encodedImage.encodeFinishMs
        modified.frameType      = encodedImage.frameType
        modified.rotation       = encodedImage.rotation
        // modified.completeFrame  = encodedImage.completeFrame
        modified.qp             = encodedImage.qp
        modified.contentType    = encodedImage.contentType

        // 2) parse and decrypt slice NALUs only
        var raw = encodedImage.buffer

        let nalus = H264NALUParser.parse(raw)
        var decryptedCount = 0
        for nalu in nalus {
            switch nalu.type {
            case .slice, .idr:
                let payloadStart = nalu.range.lowerBound + nalu.headerLength + 1
                let payloadEnd   = nalu.range.upperBound
                guard payloadStart < payloadEnd else { continue }
                let sliceRange = payloadStart..<payloadEnd
                let sliceBytes = raw[sliceRange]
                if let decrypted = CallEncryptionManager.shared.decryptCallMediaData(sliceBytes) {
                    raw.replaceSubrange(sliceRange, with: decrypted)
                    decryptedCount += 1
                    // debugLog("🔓 E2EE ○ Decrypted NALU \(nalu.type) at \(nalu.range)")
                }
            default:
                break
            }
        }

        modified.buffer = raw

        // 3) hand off to the real decoder
        return wrappedDecoder.decode(
            modified,
            missingFrames: missingFrames,
            codecSpecificInfo: info,
            renderTimeMs: renderTimeMs
        )
    }

    /// Identify yourself.
    func implementationName() -> String {
        return "CustomVideoDecoder(\(wrappedDecoder.implementationName()))"
    }

}
