struct Participant: Codable, Hashable {
    let id: UInt64
    let callId: UInt64
    let userId: UInt64
    let deviceId: UInt64
    let displayName: String
    let isHost: Bool
    let isHostKey: Bool  // Backend determines who rotates group key
    var isLocal: Bool

    // User information from API
    let user: UserInfo?

    // WebRTC properties
    var feedId: UInt64?
    var isMuted: Bool?
    var isVideoEnabled: Bool?

    // Participant status (only for remote participants being invited/joining)
    var status: ParticipantStatus?

    // Computed property to get displayName from user if available, fallback to displayName
    var effectiveDisplayName: String {
        return user?.displayName ?? displayName
    }

    init(id: UInt64 = 0,
         callId: UInt64 = 0,
         userId: UInt64,
         deviceId: UInt64,
         displayName: String,
         isHost: Bool,
         isHostKey: Bool = false,
         isLocal: Bool,
         user: UserInfo? = nil,
         feedId: UInt64? = nil,
         isMuted: Bool? = nil,
         isVideoEnabled: Bool? = nil,
         status: ParticipantStatus? = nil
    ) {
        self.id = id
        self.callId = callId
        self.userId = userId
        self.deviceId = deviceId
        self.displayName = displayName
        self.isHost = isHost
        self.isHostKey = isHostKey
        self.isLocal = isLocal
        self.user = user
        self.feedId = feedId
        self.isMuted = isMuted
        self.isVideoEnabled = isVideoEnabled
        self.status = status
    }

    private enum CodingKeys: String, CodingKey {
        case id, callId, userId, deviceId, displayName, isHost, isHostKey, isLocal
        case user, feedId, isMuted, isVideoEnabled, status
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UInt64.self, forKey: .id) ?? 0
        callId = try c.decodeIfPresent(UInt64.self, forKey: .callId) ?? 0
        userId = try c.decode(UInt64.self, forKey: .userId)
        deviceId = try c.decode(UInt64.self, forKey: .deviceId)
        displayName = try c.decode(String.self, forKey: .displayName)
        isHost = try c.decode(Bool.self, forKey: .isHost)
        isHostKey = try c.decodeIfPresent(Bool.self, forKey: .isHostKey) ?? false
        isLocal = try c.decodeIfPresent(Bool.self, forKey: .isLocal) ?? false
        user = try c.decodeIfPresent(UserInfo.self, forKey: .user)
        feedId = try c.decodeIfPresent(UInt64.self, forKey: .feedId)
        isMuted = try c.decodeIfPresent(Bool.self, forKey: .isMuted)
        isVideoEnabled = try c.decodeIfPresent(Bool.self, forKey: .isVideoEnabled)
        status = try c.decodeIfPresent(ParticipantStatus.self, forKey: .status)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(callId, forKey: .callId)
        try container.encode(userId, forKey: .userId)
        try container.encode(deviceId, forKey: .deviceId)
        try container.encode(displayName, forKey: .displayName)
        try container.encode(isHost, forKey: .isHost)
        try container.encode(isHostKey, forKey: .isHostKey)
        try container.encode(isLocal, forKey: .isLocal)
        try container.encodeIfPresent(user, forKey: .user)
        try container.encodeIfPresent(feedId, forKey: .feedId)
        try container.encodeIfPresent(isMuted, forKey: .isMuted)
        try container.encodeIfPresent(isVideoEnabled, forKey: .isVideoEnabled)
        try container.encodeIfPresent(status, forKey: .status)
    }
}
