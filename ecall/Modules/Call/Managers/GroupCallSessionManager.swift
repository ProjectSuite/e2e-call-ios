import Foundation

class GroupCallSessionManager: ObservableObject {
    static let shared = GroupCallSessionManager()
    @Published var participants: [Participant] = []
    @Published var currentHost: Participant?
    @Published var callStatus: CallStatus = .ended

    var currentCallUUID: UUID?
    var currentCallId: UInt64?
    var janusRoomId: UInt64?
    var isVideoCall: Bool = false
    var isSpeakerOn: Bool = false
    
    // Flag to indicate current call session is from rejoin flow (not via CallKit)
    var isRejoinFlow: Bool = false
    private(set) var pendingRejoinCallId: UInt64?
    private var hasConsumedRejoinAcceptance = false

    // Computed property: Check if current user is key rotation host based on participant data
    var isKeyRotationHost: Bool {
        guard let currentUserId = UInt64(KeyStorage.shared.readUserId() ?? "") else {
            return false
        }
        return participants.first(where: { $0.userId == currentUserId })?.isHostKey ?? false
    }

    // Starts a new group call session (caller side or when receiving invite)
    func startCallSession(uuid: UUID, callId: UInt64, janusRoomId: UInt64, participants: [Participant], isVideo: Bool) {
        currentCallUUID = uuid
        currentCallId = callId
        self.janusRoomId = janusRoomId
        self.isVideoCall = isVideo
        self.isSpeakerOn = isVideo
        self.participants = participants
        self.callStatus = .requesting
        // New session via normal flow -> not a rejoin
        self.isRejoinFlow = false
        if let host = participants.first(where: { $0.isHost }) {
            currentHost = host
            debugLog("🎉 Host is \(host.displayName) (id=\(host.userId))")
        } else {
            debugLog("⚠️ No host flagged in participants.")
            currentHost = nil
        }
    }

    func requestRejoinCall(callId: UInt64, onSuccess: (() -> Void)? = nil, onError: (() -> Void)? = nil) {
        pendingRejoinCallId = callId
        hasConsumedRejoinAcceptance = false

        DispatchQueue.main.async {
            self.callStatus = .requesting
            NotificationCenter.default.post(name: .didStartCall, object: nil)
        }

        CallService.shared.requestRejoinGroupCall(callId: callId) { result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    debugLog("📨 Rejoin request sent for callId: \(callId)")
                    // Mark that following session is from rejoin flow
                    self.isRejoinFlow = true
                    onSuccess?()
                case .failure(let error):
                    NotificationCenter.default.post(name: .callDidEnd, object: nil)
                    ToastManager.shared.error(error.content)
                    self.pendingRejoinCallId = nil
                    onError?()
                }
            }
        }
    }

    func clearPendingRejoinRequest() {
        pendingRejoinCallId = nil
        hasConsumedRejoinAcceptance = false
    }

    func tryConsumeRejoinAcceptance(for callId: UInt64) -> Bool {
        guard pendingRejoinCallId == callId, !hasConsumedRejoinAcceptance else {
            return false
        }
        hasConsumedRejoinAcceptance = true
        return true
    }

    func endRejoinCall() {
        CallService.shared.endCall(callId: pendingRejoinCallId) { _ in
            debugLog("📞 endCall API called for rejoin flow")
        }
    }

    func rejoinActiveCall(callId: UInt64, encryptedAESKeyBase64: String? = nil, onError: (() -> Void)? = nil) {
        // Retrieve and decrypt encryptedAESKey for this call
        let encryptedKeyString = encryptedAESKeyBase64 ?? CallKeyStorage.shared.getEncryptedAESKey(for: callId)

        guard let encryptedAESKeyBase64 = encryptedKeyString else {
            errorLog("❌ Cannot rejoin call: No encryptedAESKey found for callId: \(callId)")
            DispatchQueue.main.async {
                ToastManager.shared.error(KeyLocalized.invalid_rejoin_room_information)
                onError?()
            }
            endRejoinCall()
            clearPendingRejoinRequest()
            return
        }

        // Detect format and decrypt accordingly
        var decryptSuccess = false

        if encryptedAESKeyBase64.contains(":") {
            // P-256 group call format: "publicKey:encryptedGroupKey"
            let components = encryptedAESKeyBase64.split(separator: ":")
            if components.count == 2 {
                let callerPublicKey = String(components[0])
                let encryptedGroupKeyBase64 = String(components[1])

                if let encryptedGroupKeyData = Data(base64Encoded: encryptedGroupKeyBase64),
                   let groupKey = CallEncryptionManager.shared.decryptGroupKeyP256(
                    encryptedGroupKey: encryptedGroupKeyData,
                    initiatorPublicKeyBase64: callerPublicKey
                   ) {
                    // Set up session with group key
                    // NOTE: setUpAesKey will set sessionAESKey thread-safely
                    CallEncryptionManager.shared.originalAESKey = groupKey
                    CallEncryptionManager.shared.setUpAesKey(groupKey)
                    decryptSuccess = true
                    debugLog("✅ P256 group key decrypted for rejoin")
                }
            }

        } else if encryptedAESKeyBase64.count < 150 {
            // P-256 1-to-1 call format: just "publicKey"
            if CallEncryptionManager.shared.processCallInvitationP256(callerPublicKeyBase64: encryptedAESKeyBase64) {
                decryptSuccess = true
                debugLog("✅ P256 1-to-1 key derived for rejoin")
            }

        } else {
            // RSA format: encrypted AES key
            if let encryptedAESKeyData = Data(base64Encoded: encryptedAESKeyBase64),
               let privateKey = KeyStorage.shared.readPrivateKeyAsSecKey(),
               CallEncryptionManager.shared.processCallInvitation(
                encryptedAESKey: encryptedAESKeyData,
                calleeRSAPrivateKey: privateKey
               ) != nil {
                decryptSuccess = true
                debugLog("✅ RSA AES key decrypted for rejoin")
            }
        }

        guard decryptSuccess else {
            errorLog("❌ Cannot rejoin call: Failed to decrypt AES key for callId: \(callId)")
            DispatchQueue.main.async {
                ToastManager.shared.error(KeyLocalized.invalid_rejoin_room_information)
                onError?()
            }
            endRejoinCall()
            clearPendingRejoinRequest()
            return
        }

        // Store key for future attempts
        _ = CallKeyStorage.shared.storeEncryptedAESKey(encryptedAESKeyBase64, for: callId)

        debugLog("✅ Successfully decrypted AES key for rejoin callId: \(callId)")

        // Join the call via backend
        CallService.shared.rejoinGroupCall(callId: callId) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let record):
                    guard let janusRoomId = record.janusRoomId, janusRoomId > 0 else {
                        errorLog("Cannot join call: missing room ID")
                        ToastManager.shared.error(KeyLocalized.invalid_rejoin_room_information)
                        onError?()
                        return
                    }

                    // Initialize call session with existing call data
                    let callUUID = UUID()
                    let isVideo = record.callMediaType == .video

                    self.startCallSession(
                        uuid: callUUID,
                        callId: callId,
                        janusRoomId: janusRoomId,
                        participants: [], // Will be updated from server
                        isVideo: isVideo
                    )
                    self.callStatus = .connected
                    self.isRejoinFlow = true

                    // Configure audio session for the call
                    AudioSessionManager.shared.configureAudioSession()

                    // Start Janus flow to join the room
                    GroupCallManager.shared.startJanusFlowRejoinCall(for: callId, isVideo: isVideo)

                    WebRTCManager.publisher.resetConnection()
                    WebRTCManager.subscriber.resetConnection()

                    // b) Re‐build publisher/subscriber PeerConnections
                    WebRTCManager.publisher.setupPubPeerConnection()
                    WebRTCManager.subscriber.setupSubPeerConnection()

                    // Update participants and check if we should start key rotation timer
                    self.updateParticipants { [weak self] in
                        guard let self = self else { return }
                        // Start key rotation timer if this user is the key rotation host (rejoin scenario)
                        if self.isKeyRotationHost {
                            GroupCallManager.shared.startKeyRotationTimerIfHost()
                            debugLog("🔄 Key rotation timer started after rejoin (host confirmed)")
                        } else {
                            debugLog("ℹ️ Not key rotation host after rejoin")
                        }
                    }

                    debugLog("✅ Successfully joined active call \(callId)")
                    self.clearPendingRejoinRequest()
                case .failure(let error):
                    ToastManager.shared.error(error.content)
                    onError?()
                    self.endRejoinCall()
                    self.clearPendingRejoinRequest()
                }
            }
        }
    }

    func checkContinueCallState() {
        guard let currentCallId = currentCallId, callStatus == .connected else {return}

        GroupCallManager.shared.startJanusFlow(for: currentCallId)

        WebRTCManager.publisher.resetConnection()
        WebRTCManager.subscriber.resetConnection()

        // b) Re‐build publisher/subscriber PeerConnections
        WebRTCManager.publisher.setupPubPeerConnection()
        WebRTCManager.subscriber.setupSubPeerConnection()

        // Update participants and check if we should start key rotation timer
        updateParticipants { [weak self] in
            guard let self = self else { return }
            // Start key rotation timer if this user is the key rotation host (app restart scenario)
            if self.isKeyRotationHost {
                GroupCallManager.shared.startKeyRotationTimerIfHost()
                debugLog("🔄 Key rotation timer restarted after app resume (host confirmed)")
            } else {
                debugLog("ℹ️ Not key rotation host after app resume")
            }
        }
    }

    func updateMyConnectionStatus(_ status: ParticipantStatus) {
        guard let callId = currentCallId,
              let currentParticipant = getCurrentParticipant() else {
            debugLog("⚠️ Cannot update own status: missing user/call info")
            return
        }

        let currentUserId = currentParticipant.userId
        debugLog("📤 Sending MY connection status to server: \(status.rawValue)")

        updateParticipantStatus(userId: currentUserId, status: status)

        CallService.shared.updateParticipantInCall(
            id: currentParticipant.id,
            callId: callId,
            userId: currentUserId,
            status: status
        ) { participant in
            if let p = participant {
                debugLog("✅ Server confirmed my status: \(p.status?.rawValue ?? "nil")")
            }
        }
    }

    // MARK: - Participant Management
    func updateParticipants(completion: (() -> Void)? = nil) {
        let callID = currentCallId
        //        debugLog("🔄 Fetching participants for call ID: \(String(describing: callID))")
        CallService.shared.fetchCallParticipants(callId: callID ?? 0) { [weak self] response in
            guard let self = self else {
                completion?()
                return
            }
            DispatchQueue.main.async {
                var list = response?.participants ?? []
                let currentId = response?.currentUser.id ?? 0

                if let index = list.firstIndex(where: { $0.userId == currentId }) {
                    list[index].isLocal = true
                }
                self.participants = list

                // Log key rotation host information
                if let currentUserId = UInt64(KeyStorage.shared.readUserId() ?? ""),
                   let currentUser = list.first(where: { $0.userId == currentUserId }) {
                    if currentUser.isHostKey {
                        debugLog("👑 Current user is key rotation host (isHostKey=true)")
                    } else {
                        debugLog("📱 Current user is NOT key rotation host (isHostKey=false)")
                    }
                }

                debugLog("👤👤 Participants: \(list)")

                // Call completion callback after participants updated
                completion?()
            }
        }
    }

    func clearParticipants() {
        participants.removeAll()
    }

    // Reset the call session state when call ends
    func endCallSession() {
        debugLog("⚠️ Call session ending, clearing state.")
        DispatchQueue.main.async {
            self.currentCallUUID = nil
            self.currentCallId = nil
            self.janusRoomId = nil
            self.currentHost = nil
            self.participants.removeAll()
            self.isVideoCall = false
            self.isSpeakerOn = false
            self.callStatus = .ended
            self.isRejoinFlow = false
            self.clearPendingRejoinRequest()
        }
    }

    func getCurrentParticipant() -> Participant? {
        guard let userIdString = KeyStorage.shared.readUserId(),
              let currentUserId = UInt64(userIdString) else {return nil}
        return getParticipant(byUserId: currentUserId)
    }

    func getParticipant(byUserId userId: UInt64) -> Participant? {
        return participants.first { $0.userId == userId }
    }

    // MARK: - Update Feed IDs

    func updateFeedId(userId: UInt64, feedId: UInt64) {
        if let index = participants.firstIndex(where: { $0.userId == userId }), feedId > 0 {
            var participant = participants[index]
            participant.feedId = feedId

            participants[index] = participant

            debugLog("name: \(participant.displayName) - id: \(participant.id) - feedID: \(feedId)")

            if let callId = self.currentCallId {
                CallService.shared.updateParticipantInCall(id: participant.id, callId: callId, userId: userId, status: .connected, feedId: feedId) { _ in

                }
            }
        }
    }

    // MARK: - Update States

    @MainActor func updateMuteState(_ isMuted: Bool) {
        let currentUserId = UInt64(AppState.shared.userID) ?? 0
        if let index = participants.firstIndex(where: { $0.userId == currentUserId }) {
            var participant = participants[index]
            participant.isMuted = isMuted
            participants[index] = participant

            if let callId = self.currentCallId {
                CallService.shared.updateParticipantInCall(id: participant.id, callId: callId, userId: currentUserId, isMuted: isMuted) { _ in

                }
            }
        }
    }

    @MainActor func updateVideoEnabledState(_ isVideoEnabled: Bool) {
        let currentUserId = UInt64(AppState.shared.userID) ?? 0

        if let index = participants.firstIndex(where: { $0.userId == currentUserId }) {
            var participant = participants[index]
            participant.isVideoEnabled = isVideoEnabled
            participants[index] = participant

            if let callId = self.currentCallId {
                CallService.shared.updateParticipantInCall(id: participant.id, callId: callId, userId: currentUserId, isVideoEnabled: isVideoEnabled) { _ in

                }
            }
        }
    }

    // MARK: - Participant Status Management
    /// Get participants with specific status
    func getParticipantStatus(_ status: ParticipantStatus) -> [Participant] {
        return participants.filter({$0.status == status})
    }

    /// Update status for a specific participant
    func updateParticipantStatus(userId: UInt64, status: ParticipantStatus) {
        guard let index = participants.firstIndex(where: { $0.userId == userId }) else {
            debugLog("⚠️ Participant not found for status update: userId=\(userId)")
            return
        }
        participants[index].status = status
        debugLog("👤 Updated participant \(participants[index].displayName) status → \(status.rawValue)")
    }

    /// Get participants by status (for UI display)
    func participantCount(withStatus status: ParticipantStatus) -> Int {
        return participants.filter { $0.status == status }.count
    }

    /// Get invited participants (status == .inviting)
    func getInvitedParticipants() -> [Participant] {
        return participants.filter { $0.status == .inviting }
    }

    // MARK: - Remote Updates

    /// Update participant states by userId using values propagated from signaling
    func applyRemoteParticipantUpdate(_ message: SignalMessage) {
        let userId = message.participantId ?? message.calleeId ?? message.callerId ?? 0
        if userId == 0 { return }

        guard let index = participants.firstIndex(where: { $0.userId == userId }) else { return }

        if let data = message.status {
            participants[index].status = data
        }

        if let data = message.feedId {
            participants[index].feedId = data
        }

        if let data = message.isMuted {
            participants[index].isMuted = data
        }

        if let data = message.isVideoEnabled {
            participants[index].isVideoEnabled = data
        }
    }

    func applyRemoteParticipantFeedIdUpdate(_ message: SignalMessage) {
        updateParticipants()
    }
}
