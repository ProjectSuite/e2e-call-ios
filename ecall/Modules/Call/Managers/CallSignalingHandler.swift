import Foundation

// Singleton handler implementing SignalingDelegate to process signaling messages
class CallSignalingHandler: SignalingDelegate {
    static let shared = CallSignalingHandler()
    private init() {}

    func didReceiveSignal(_ message: SignalMessage) {
        successLog("📦 Receive signal: \(message.type) -- message: \(message)")

        switch message.type {
        case .participant_joined:
            GroupCallSessionManager.shared.updateParticipants()

            if let participantId = message.participantId {
                // Get participant name for notification
                let participant = GroupCallSessionManager.shared.getParticipant(byUserId: participantId)
                let participantName = participant?.displayName ?? message.participantName ?? "User \(participantId)"

                // Post notification for CallView to show warning toast
                NotificationCenter.default.post(
                    name: .participantJoined,
                    object: nil,
                    userInfo: [
                        "participantId": participantId,
                        "participantName": participantName
                    ]
                )
            }

        case .participant_updated:
            GroupCallSessionManager.shared.applyRemoteParticipantUpdate(message)

        case .participant_left:
            GroupCallSessionManager.shared.updateParticipants()

            if let participantId = message.participantId {
                // Get participant name for notification
                let participant = GroupCallSessionManager.shared.getParticipant(byUserId: participantId)
                let participantName = participant?.displayName ?? "User \(participantId)"

                // Post notification for CallView to show warning toast
                NotificationCenter.default.post(
                    name: .participantLeft,
                    object: nil,
                    userInfo: [
                        "participantId": participantId,
                        "participantName": participantName
                    ]
                )
            }

        case .participant_feedId_updated:
            GroupCallSessionManager.shared.applyRemoteParticipantFeedIdUpdate(message)

        case .participant_invited:
            GroupCallSessionManager.shared.updateParticipants()

        case .participant_rejected:
            GroupCallSessionManager.shared.updateParticipants()

            if let participantId = message.participantId {
                // Get participant name for notification
                let participant = GroupCallSessionManager.shared.getParticipant(byUserId: participantId)
                let participantName = participant?.displayName ?? "User \(participantId)"

                // Post notification for CallView to show warning toast
                NotificationCenter.default.post(
                    name: .participantRejected,
                    object: nil,
                    userInfo: [
                        "participantId": participantId,
                        "participantName": participantName
                    ]
                )
            }

        case .call_ended:
            // The other party hung up or the call terminated
            GroupCallManager.shared.endCallImmediately(reason: .remoteEnded)

        case .call_cancelled:
            // The caller cancelled the call before it was answered (we were ringing)
            GroupCallManager.shared.endCallImmediately(reason: .answeredElsewhere)

        case .participant_request_rejoin:
            handleParticipantRequestRejoin(message)

        case .participant_accept_rejoin:
            handleParticipantAcceptRejoin(message)

        case .handover_host:
            handleHandoverHost(message)

        case .key_rotation:
            handleKeyRotation(message)

        case .request_aes_key:
            handleRequestAESKey(message)

        case .send_aes_key:
            handleSendAESKey(message)

        default:
            break
        }
    }

    // Stop any ringing UI locally when server says there's no active call.
    func didCancelAllRinging() {
        GroupCallManager.shared.endCallImmediately(reason: .remoteEnded, isSilent: true)
    }

    // Server says there IS a call and it's still ringing.
    func didSyncIncomingCall(_ callId: UInt?, participants: [Participant]?) {
        //        DispatchQueue.main.async {
        //            GroupCallSessionManager.shared.callStatus = .ringing
        //        }
        // Optional: update a participants store if you have one.
    }

    // Server says call is ongoing/connected.
    func didSyncOngoingCall(_ callId: UInt?, participants: [Participant]?) {
        DispatchQueue.main.async {
            GroupCallSessionManager.shared.callStatus = .connected
        }
    }

    // Helper to find a contact name for a given user ID (if available in contacts list)
    private func lookupName(for userId: String) -> String? {
        // In a real app, look up the user in the contacts or address book
        // Here we return nil to default to unknown name.
        return nil
    }

    private func handleParticipantRequestRejoin(_ message: SignalMessage) {
        guard GroupCallSessionManager.shared.callStatus == .connected,
              let callId = message.callId,
              let requesterId = message.participantId,
              let calleeDeviceId = message.calleeDeviceId else {
            return
        }

        if let currentUserId = UInt64(KeyStorage.shared.readUserId() ?? ""),
           requesterId == currentUserId {
            return
        }

        guard let aesKey = CallEncryptionManager.shared.originalAESKey ?? CallEncryptionManager.shared.sessionAESKey,
              !aesKey.isEmpty else {
            debugLog("⚠️ No AES key available to share for rejoin request.")
            return
        }

        let userIdAndDeviceId = "\(requesterId)_\(calleeDeviceId)"

        // Fetch public key of requester and encrypt AES key with RSA
        UserService.shared.fetchPublicKeys(userIds: [requesterId]) { result in
            switch result {
            case .success(let idToKeyMap):
                // Filter to get only the public key for this specific userId_deviceId
                guard let publicKeyString = idToKeyMap[userIdAndDeviceId] else {
                    errorLog("❌ No public key found for userId_deviceId: \(userIdAndDeviceId)")
                    return
                }

                // Create filtered map with only this entry for prepareEncryptedInvitations
                let filteredMap = [userIdAndDeviceId: publicKeyString]

                guard let encryptedKeys = GroupCallManager.shared.prepareEncryptedInvitations(filteredMap),
                      let encryptedKeyString = encryptedKeys[userIdAndDeviceId] else {
                    errorLog("❌ Failed to encrypt AES key for rejoin request from userId: \(requesterId), deviceId: \(calleeDeviceId)")
                    return
                }

                var response = message
                response.type = .participant_accept_rejoin
                response.participantId = requesterId
                response.encryptedAESKey = encryptedKeyString

                StompSignalingManager.shared.send(response)
                debugLog("📬 Sent participant_accept_rejoin for callId: \(callId) to userId: \(requesterId), deviceId: \(calleeDeviceId) with encrypted AES key")

            case .failure(let error):
                errorLog("❌ Failed to fetch public key for rejoin request from userId: \(requesterId), error: \(error)")
            }
        }
    }

    private func handleParticipantAcceptRejoin(_ message: SignalMessage) {
        guard let callId = message.callId,
              let encryptedAESKey = message.encryptedAESKey,
              let targetUserId = message.participantId,
              let currentUserId = UInt64(KeyStorage.shared.readUserId() ?? ""),
              targetUserId == currentUserId,
              let calleeDeviceId = message.calleeDeviceId,
              let currentDeviceId = UInt64(KeyStorage.shared.readDeviceId() ?? ""),
              calleeDeviceId == currentDeviceId
        else {
            return
        }

        guard GroupCallSessionManager.shared.tryConsumeRejoinAcceptance(for: callId) else {
            debugLog("ℹ️ Received rejoin acceptance for callId \(callId) but no pending request.")
            return
        }

        GroupCallSessionManager.shared.rejoinActiveCall(callId: callId, encryptedAESKeyBase64: encryptedAESKey)
    }

    private func handleHandoverHost(_ message: SignalMessage) {
        guard let newHostUserId = message.participantId,
              let currentUserId = UInt64(KeyStorage.shared.readUserId() ?? "") else {
            errorLog("❌ handover_host signal missing participantId")
            return
        }

        // Check if current user is the new key rotation host
        let isNewHost = (newHostUserId == currentUserId)

        DispatchQueue.main.async {
            if isNewHost {
                debugLog("👑 Received handover_host: I am now the key rotation host")
                // Update participant list to reflect backend's decision
                GroupCallSessionManager.shared.updateParticipants()
                // Start key rotation timer if call is active
                if GroupCallSessionManager.shared.callStatus == .connected {
                    GroupCallManager.shared.startKeyRotationTimerIfHost()
                }
            } else {
                debugLog("📱 Received handover_host: New key rotation host is userId \(newHostUserId)")
                // Update participant list to reflect backend's decision
                GroupCallSessionManager.shared.updateParticipants()
                // Stop key rotation timer if we're no longer the host
                GroupCallManager.shared.stopKeyRotationTimerIfNotHost()
            }
        }
    }
    
    private func handleKeyRotation(_ message: SignalMessage) {
        guard let _ = message.callId,
              let encryptedAESKey = message.encryptedAESKey,
              let keyRotationTimestamp = message.keyRotationTimestamp
        else {
            errorLog("key_rotation signal missing required fields (callId, encryptedAESKey, or keyRotationTimestamp)")
            return
        }
        
        // Verify this message is for current user
        guard let targetUserId = message.participantId,
              let currentUserId = UInt64(KeyStorage.shared.readUserId() ?? ""),
              targetUserId == currentUserId else {
            errorLog("key_rotation signal not for current user")
            return
        }
        
        // Decrypt the new group key first
        guard let decryptedKey = GroupCallManager.shared.decryptKeyRotationMessage(
            encryptedAESKey: encryptedAESKey
        ) else {
            errorLog("Failed to decrypt key rotation message")
            return
        }
        
        // Schedule key application at synchronized timestamp
        GroupCallManager.shared.scheduleKeyApplicationForParticipant(
            groupKey: decryptedKey,
            keyRotationTimestamp: keyRotationTimestamp
        )
    }

    // MARK: - Emergency Key Redistribution

    /// Handle request_aes_key signal (Host side)
    /// Participant requests current key when decrypt fails
    private func handleRequestAESKey(_ message: SignalMessage) {
        // Only host should process this
        guard GroupCallSessionManager.shared.isKeyRotationHost else {
            debugLog("⚠️ [Key Request] Received request_aes_key but not host - ignoring")
            return
        }

        guard let requesterId = message.senderId else {
            errorLog("❌ [Key Request] request_aes_key missing senderId")
            return
        }
        
        guard let requesterDeviceId = message.senderDeviceId else {
            errorLog("❌ [Key Request] request_aes_key missing participantDeviceId")
            return
        }

        debugLog("🔑 [Key Request] Received key request from userId: \(requesterId)")

        // Fetch public key of requester
        UserService.shared.fetchPublicKeys(userIds: [requesterId]) { [weak self] result in
            guard let self = self else { return }

            switch result {
            case .success(let idToKeyMap):
                // Find requester's public key
                guard let publicKeyString = idToKeyMap.values.first else {
                    errorLog("❌ [Key Request] No public key found for userId: \(requesterId)")
                    return
                }

                // Get current key
                guard let currentKey = CallEncryptionManager.shared.sessionAESKey else {
                    errorLog("❌ [Key Request] No current key to redistribute")
                    return
                }

                // Encrypt key for requester (reuse existing encryption logic)
                let base64PublicKey = publicKeyString
                guard let encryptedKey = self.encryptKeyForRedistribution(
                    groupKey: currentKey,
                    publicKeyBase64: base64PublicKey
                ) else {
                    errorLog("❌ [Key Request] Failed to encrypt key for userId: \(requesterId)")
                    return
                }

                // Send back to requester - use positional arguments
                let responseSignal = SignalMessage(
                    type: .send_aes_key,
                    encryptedAESKey: encryptedKey,
                    participantId: requesterId,
                    participantDeviceId: requesterDeviceId,
                    callId: GroupCallSessionManager.shared.currentCallId
                )
                
                StompSignalingManager.shared.send(responseSignal)
                debugLog("📤 [Key Request] Sent emergency key to userId: \(requesterId)")

            case .failure(let error):
                errorLog("❌ [Key Request] Failed to fetch public key for userId: \(requesterId), error: \(error)")
            }
        }
    }

    /// Handle send_aes_key signal (Participant side)
    /// Host sends encrypted current key in response to request
    private func handleSendAESKey(_ message: SignalMessage) {
        guard let encryptedAESKey = message.encryptedAESKey else {
            errorLog("❌ [Key Request] send_aes_key missing encryptedAESKey")
            return
        }

        // Verify this is for current user
        guard let targetUserId = message.participantId,
              let currentUserId = UInt64(KeyStorage.shared.readUserId() ?? ""),
              targetUserId == currentUserId else {
            debugLog("ℹ️ [Key Request] send_aes_key not for current user")
            return
        }

        debugLog("🔑 [Key Request] Received emergency key from host")

        // Decrypt key (reuse existing method)
        guard let newKey = GroupCallManager.shared.decryptKeyRotationMessage(
            encryptedAESKey: encryptedAESKey
        ) else {
            errorLog("❌ [Key Request] Failed to decrypt emergency key")
            // Allow retry by marking request complete
            CallEncryptionManager.shared.markKeyRequestComplete()
            return
        }

        // Apply immediately (emergency key, skip scheduled time)
        CallEncryptionManager.shared.setUpAesKey(newKey)

        // Mark request complete
        CallEncryptionManager.shared.markKeyRequestComplete()

        debugLog("✅ [Key Request] Emergency key applied successfully")
    }

    /// Helper: Encrypt key for redistribution to participant
    private func encryptKeyForRedistribution(groupKey: Data, publicKeyBase64: String) -> String? {
        // Use GroupCallManager's encryption method
        return GroupCallManager.shared.encryptGroupKeyForParticipant(
            groupKey: groupKey,
            participantPublicKeyBase64: publicKeyBase64
        )
    }
}
