import Foundation

enum H264NALUType: UInt8 {
    case slice = 1, idr = 5, sps = 7, pps = 8, other = 0
    init(byte: UInt8) {
        switch byte & 0x1F {
        case 1: self = .slice
        case 5: self = .idr
        case 7: self = .sps
        case 8: self = .pps
        default: self = .other
        }
    }
}

/// Describes one NALU’s byte‐range and header length (in bytes)
struct H264NALU {
    let type: H264NALUType
    let range: Range<Int>
    let headerLength: Int
}

struct H264NALUParser {
    /// Auto-detect Annex-B (start codes) vs AVCC (length prefix)
    static func parse(_ data: Data) -> [H264NALU] {
        // debugLog("📦 [Parser] parse called with buffer size: \(data.count) bytes")
        let isAnnexB = data.starts(with: [0, 0, 0, 1]) || data.starts(with: [0, 0, 1])
        // debugLog("📦 [Parser] detected format: \(isAnnexB ? "AnnexB" : "AVCC")")
        let nalus = isAnnexB ? parseAnnexB(data) : parseAVCC(data)
        // debugLog("📦 [Parser] total NALUs found: \(nalus.count)")
        return nalus
    }

    // ——— Annex-B parser ———
    private static func parseAnnexB(_ data: Data) -> [H264NALU] {
        let bytes = [UInt8](data)
        let len = bytes.count
        var nalus: [H264NALU] = []
        var offset = 0

        func findStart(at idx: Int) -> (pos: Int, scLen: Int)? {
            guard idx <= len - 3 else { return nil }
            for j in idx..<(len-2) {
                if j+3 < len,
                   bytes[j]==0, bytes[j+1]==0, bytes[j+2]==0, bytes[j+3]==1 {
                    return (j, 4)
                }
                if bytes[j]==0, bytes[j+1]==0, bytes[j+2]==1 {
                    return (j, 3)
                }
            }
            return nil
        }

        while let (start, scLen) = findStart(at: offset) {
            let hdrIdx = start + scLen
            guard hdrIdx < len else { break }
            let type = H264NALUType(byte: bytes[hdrIdx])
            let next = findStart(at: hdrIdx+1)?.pos ?? len
            let headerLength = scLen + 1
            nalus.append(.init(
                type: type,
                range: start..<next,
                headerLength: headerLength
            ))
            // debugLog("📦 [AnnexB] NALU: type=\(type), headerLen=\(headerLength), payloadRange=\(start+headerLength)..<\(next)")
            offset = next
        }

        return nalus
    }

    // ——— AVCC parser ———
    private static func parseAVCC(_ data: Data) -> [H264NALU] {
        var nalus: [H264NALU] = []
        var offset = 0
        let total = data.count

        while offset + 4 <= total {
            let lengthBE = data.subdata(in: offset..<offset+4)
            let nLen = Int(lengthBE.withUnsafeBytes { $0.load(as: UInt32.self).bigEndian })
            let start = offset + 4
            let end = start + nLen
            if end > total {
                // debugLog("⚠️ [AVCC] bad length \(nLen) at offset \(offset), total=\(total)")
                break
            }
            let type = H264NALUType(byte: data[start])
            let headerLength = 1
            nalus.append(.init(
                type: type,
                range: start..<end,
                headerLength: headerLength
            ))
            // debugLog("📦 [AVCC] NALU: type=\(type), length=\(nLen), payloadRange=\(start+headerLength)..<\(end)")
            offset = end
        }

        return nalus
    }
}
