import SwiftUI

enum CallType: String, Codable, RawValueInitializable {
    case incoming // defaultCase
    case outgoing

    static var defaultCase: CallType {return .incoming}

    var title: String {
        switch self {
        case .incoming: return KeyLocalized.incoming
        case .outgoing: return KeyLocalized.outgoing
        }
    }
}

enum CallMediaType: String, Codable, RawValueInitializable {
    case audio // defaultCase
    case video

    static var defaultCase: CallMediaType {return .audio}

    var title: String {
        switch self {
        case .audio: return KeyLocalized.audio
        case .video: return KeyLocalized.video
        }
    }

    var icon: Image {
        switch self {
        case .audio: return Image(systemName: "phone.fill")
        case .video: return Image(systemName: "video.fill")
        }
    }
}

enum CallCategory: String, Codable, RawValueInitializable {
    case personal // defaultCase
    case group

    static var defaultCase: CallCategory {return .personal}
}

enum CallRecordStatus: String, Codable, RawValueInitializable {
    case calling
    case active
    case missed
    case completed

    case unknown // defaultCase

    static var defaultCase: CallRecordStatus {return .unknown}
}

struct Call: Codable {
    var callRecord: CallRecord
    var offlineCallees: [OfflineParticipant]?
}

struct OfflineParticipant: Codable {
    let id: UInt64?
    let displayName: String?
}

struct CallRecord: Identifiable, Codable, Hashable {
    let id: UInt64?
    let contactPublicKey: String?
    let contactPublicKeyHash: String?
    let callType: CallType?
    let callMediaType: CallMediaType?
    let callCategory: CallCategory?
    let startedAt: String?
    let answeredAt: String?
    let endedAt: String?
    let status: CallRecordStatus?
    let janusRoomId: UInt64?
    let duration: Int?
    let participants: [Participant]?

    var availableParticipants: [Participant] {
        return participants ?? []
    }

    enum CodingKeys: String, CodingKey {
        case id
        case contactPublicKey
        case contactPublicKeyHash
        case callType
        case callMediaType
        case callCategory
        case callTime
        case startedAt
        case answeredAt
        case endedAt
        case status
        case janusRoomId
        case duration
        case participants
    }

    // Custom initializer for creating a new record
    init(id: UInt64,
         contactPublicKey: String,
         contactPublicKeyHash: String,
         callType: CallType,
         callMediaType: CallMediaType,
         callCategory: CallCategory,
         callTime: String,
         startedAt: String,
         answeredAt: String? = nil,
         endedAt: String? = nil,
         status: CallRecordStatus,
         janusRoomId: UInt64? = nil,
         duration: Int? = nil,
         participants: [Participant]? = nil) {
        self.id = id
        self.contactPublicKey = contactPublicKey
        self.contactPublicKeyHash = contactPublicKeyHash
        self.callType = callType
        self.callMediaType = callMediaType
        self.callCategory = callCategory
        self.startedAt = startedAt
        self.answeredAt = answeredAt
        self.endedAt = endedAt
        self.status = status
        self.janusRoomId = janusRoomId
        self.duration = duration
        self.participants = participants
    }

    // Custom initializer for decoding
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try? container.decode(UInt64.self, forKey: .id)
        self.contactPublicKey = try container.decodeIfPresent(String.self, forKey: .contactPublicKey) ?? ""
        self.contactPublicKeyHash = try container.decodeIfPresent(String.self, forKey: .contactPublicKeyHash) ?? ""
        self.callType = try? container.decodeIfPresent(CallType.self, forKey: .callType) ?? CallType.incoming
        self.callMediaType = try? container.decodeIfPresent(CallMediaType.self, forKey: .callMediaType) ?? CallMediaType.audio
        self.callCategory = try? container.decodeIfPresent(CallCategory.self, forKey: .callCategory) ?? CallCategory.personal
        self.startedAt = try container.decodeIfPresent(String.self, forKey: .startedAt) ?? Date().formatted()
        self.answeredAt = try? container.decodeIfPresent(String.self, forKey: .answeredAt) ?? Date().formatted()
        self.endedAt = try? container.decodeIfPresent(String.self, forKey: .endedAt) ?? Date().formatted()
        self.status = try? container.decodeIfPresent(CallRecordStatus.self, forKey: .status) ?? .unknown
        self.janusRoomId = try container.decodeIfPresent(UInt64.self, forKey: .janusRoomId) ?? 0
        self.duration = try? container.decodeIfPresent(Int.self, forKey: .duration) ?? 0
        self.participants = try? container.decodeIfPresent([Participant].self, forKey: .participants) ?? []
    }

    // Custom encode method
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(contactPublicKeyHash, forKey: .contactPublicKeyHash)
        try container.encode(callType, forKey: .callType)
        try container.encode(callMediaType, forKey: .callMediaType)
        try container.encode(callCategory, forKey: .callCategory)
        try container.encode(startedAt, forKey: .startedAt)
        try container.encode(answeredAt, forKey: .answeredAt)
        try container.encode(endedAt, forKey: .endedAt)
        try container.encode(status, forKey: .status)
        try container.encode(janusRoomId, forKey: .janusRoomId)
        try container.encode(duration, forKey: .duration)
        try container.encode(participants, forKey: .participants)
    }

    var callIconName: String {
        switch (callType, callMediaType) {
        case (.incoming, .audio):
            return "phone.arrow.down.left"
        case (.incoming, .video):
            return "arrow.down.left.video.fill"
        case (.outgoing, .audio):
            return "phone.arrow.up.right"
        case (.outgoing, .video):
            return "arrow.up.right.video.fill"
        case (.none, _):
            return "phone.arrow.down.left"
        case (_, .none):
            return "phone.arrow.down.left"
        }
    }

    var iconColor: Color {
        switch status {
        case .missed:
            return .red
        default:
            return .blue
        }
    }

    var contactNameColor: Color {
        switch status {
        case .missed:
            return .red
        default:
            return .black
        }
    }

    private var startedAtDate: Date? {
        guard let startedAtString = startedAt else { return nil }
        return DateFormatters.iso8601Fractional.date(from: startedAtString) ??
            DateFormatters.iso8601.date(from: startedAtString)
    }

    var formattedDate: String {
        guard let date = startedAtDate else {
            return startedAt ?? ""
        }
        return DateFormatters.dateShort.string(from: date)
    }

    var formattedDateWithRelativeDay: String {
        guard let date = startedAtDate else {
            return startedAt ?? ""
        }
        return CallUtils.formatDateWithRelativeDay(date)
    }

    var formattedTime: String {
        guard let date = startedAtDate else {
            return startedAt ?? ""
        }
        if LanguageManager.shared.currentLanguage == .vi {
            return DateFormatters.time24Hour.string(from: date)
        } else {
            return DateFormatters.time12Hour.string(from: date)
        }
    }

    var isVideo: Bool {
        switch callMediaType {
        case (.video):
            return true
        default:
            return false
        }
    }
}

struct ICECandidate: Codable {
    let candidate: String
    let sdpMid: String?
    let sdpMLineIndex: Int32

    init(candidate: String, sdpMid: String?, sdpMLineIndex: Int32) {
        self.candidate = candidate
        self.sdpMid = sdpMid
        self.sdpMLineIndex = sdpMLineIndex
    }

    init(from rtcCandidate: RTCIceCandidate) {
        self.candidate = rtcCandidate.sdp
        self.sdpMid = rtcCandidate.sdpMid
        self.sdpMLineIndex = rtcCandidate.sdpMLineIndex
    }
}
