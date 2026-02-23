protocol SignalingDelegate: AnyObject {
    func didReceiveSignal(_ message: SignalMessage)

    // Reconciliation helpers:
    func didCancelAllRinging()
    func didSyncIncomingCall(_ callId: UInt?, participants: [Participant]?)
    func didSyncOngoingCall(_ callId: UInt?, participants: [Participant]?)
}

// Default no-ops so conformers don’t need to implement unless they care.
extension SignalingDelegate {
    func didCancelAllRinging() {}
    func didSyncIncomingCall(_ callId: UInt?, participants: [Participant]?) {}
    func didSyncOngoingCall(_ callId: UInt?, participants: [Participant]?) {}
}

// MARK: - SignalMessage Model
enum SignalType: String, Codable {
    case participant_updated
    case participant_feedId_updated
    case participant_left
    case participant_joined
    case participant_invited
    case participant_rejected
    case participant_request_rejoin
    case participant_accept_rejoin
    case call_invitation
    case call_ended
    case call_cancelled
    case handover_host
    case key_rotation
    case request_aes_key  // Emergency key request from non-host participant
    case send_aes_key     // Emergency key response from host
}

struct SignalMessage: Codable {
    var type: SignalType
    var callerId: UInt64?
    var callerDeviceId: UInt64?
    var callerName: String?
    var encryptedAESKey: String?
    var calleeId: UInt64?
    var calleeDeviceId: UInt64?
    var participantId: UInt64?
    var participantDeviceId: UInt64?
    var participantName: String?
    var callId: UInt64?
    var roomId: UInt64?
    var status: ParticipantStatus?
    var feedId: UInt64?
    var isVideo: Bool? // state detect audio or video
    var isVideoEnabled: Bool?
    var isMuted: Bool?
    var sdp: String?
    var candidate: ICECandidate?
    var transaction: String?
    var handleId: UInt?
    var isOnGoing: Bool?
    // Key rotation timing synchronization
    var keyRotationTimestamp: Double? // Unix timestamp when key should be applied (synchronized across all participants)
    var senderId: UInt64?
    var senderDeviceId: UInt64?
}

extension SignalMessage {
    init(type: SignalType) {
        self.type = type
        self.callerId = nil
        self.callerDeviceId = nil
        self.callerName = nil
        self.encryptedAESKey = nil
        self.calleeId = nil
        self.calleeDeviceId = nil
        self.participantId = nil
        self.participantDeviceId = nil
        self.participantName = nil
        self.callId = nil
        self.roomId = nil
        self.status = nil
        self.feedId = nil
        self.isVideo = nil
        self.isVideoEnabled = nil
        self.isMuted = nil
        self.sdp = nil
        self.candidate = nil
        self.transaction = nil
        self.handleId = nil
        self.isOnGoing = nil
        self.keyRotationTimestamp = nil
        self.senderId = nil
        self.senderDeviceId = nil
    }
}
