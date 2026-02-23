import Foundation
import CallKit
import AVFoundation
import UIKit

class GroupCallManager: NSObject, CXProviderDelegate {
    static let shared = GroupCallManager()

    private let callController = CXCallController()
    private let provider: CXProvider
    private let callSessionManager = GroupCallSessionManager.shared
    private let encryptionManager = CallEncryptionManager.shared
    private let janusClient = JanusSocketClient.shared
    private let keystorage = KeyStorage.shared

    // Incoming call timeout handling
    private var incomingCallTimeoutTimer: Timer?
    private let incomingCallTimeoutInterval: TimeInterval = 60.0 // 60 seconds
    
    // Key rotation handling
    private var keyRotationTimer: Timer?
    private let keyRotationInterval: TimeInterval = 300.0 // 5 minutes
    private var delayTimeKeyRotationUpdate = 10.0 // seconds

    private override init() {
        let config = CXProviderConfiguration()

        // Call settings
        config.supportsVideo = true
        config.maximumCallsPerCallGroup = 10 // Allow multiple concurrent call participants
        config.supportedHandleTypes = [.generic]

        // Include calls in Phone app's Recents
        config.includesCallsInRecents = true

        // Optional: Add app icon to CallKit UI (40x40 points @2x)
        if let iconImage = UIImage(named: "AppIcon") {
            config.iconTemplateImageData = iconImage.pngData()
        }

        // Optional: Set ringtone sound for incoming calls
        // config.ringtoneSound = "ringtone.caf"

        provider = CXProvider(configuration: config)
        super.init()
        provider.setDelegate(self, queue: nil)
    }

    func startCall(to calleeNames: [String], calleeIDs: [UInt64], isVideo: Bool) {
        guard !calleeIDs.isEmpty else {
            debugLog("⚠️ No callees to invite – aborting.")
            return
        }
        // 1. Initialize local session and CallKit
        NotificationCenter.default.post(name: .didStartCall, object: nil)
        let callUUID = UUID()
        initializeCallSession(callUUID: callUUID, calleeIDs: calleeIDs, calleeNames: calleeNames, isVideo: isVideo)

        // 2. Request CallKit start transaction
        let handleValue = calleeNames.joined(separator: ", ")
        let handle = CXHandle(type: .generic, value: handleValue)
        let startAction = CXStartCallAction(call: callUUID, handle: handle)
        startAction.isVideo = isVideo
        let transaction = CXTransaction(action: startAction)
        callController.request(transaction) { [weak self] error in
            guard let self = self else { return }
            if let error = error {
                errorLog(" CallKit start error: \(error.localizedDescription)")
                self.endCallImmediately(reason: .failed)
                return
            }
            // CallKit transaction succeeded – proceed with call setup
            self.provider.reportOutgoingCall(with: callUUID, startedConnectingAt: Date())
            CredentialsService.shared.fetchCredentials()  // preload TURN config (async)

            // 3. Fetch public keys and encrypt invitations for all callees
            UserService.shared.fetchPublicKeys(userIds: calleeIDs) { [weak self] result in
                DispatchQueue.main.async {
                    guard let self = self else { return }
                    switch result {
                    case .failure(let err):
                        errorLog(" Public key fetch failed: \(err)")
                        self.endCall(uuid: callUUID)  // End call if we cannot proceed
                    case .success(let idToKeyMap):
                        let requestedIdStrings = Set(calleeIDs.map { String($0) })
                        let returnedUserIdStrings = Set(idToKeyMap.keys.compactMap { $0.split(separator: "_").first.map(String.init) })
                        let missingUserIdStrings = requestedIdStrings.subtracting(returnedUserIdStrings)

                        if !missingUserIdStrings.isEmpty && idToKeyMap.isEmpty { // only check nobody online
                            for (idx, id) in calleeIDs.enumerated() {
                                if missingUserIdStrings.contains(String(id)) {
                                    let name = idx < calleeNames.count ? calleeNames[idx] : ""
                                    ToastManager.shared.error(String(format: KeyLocalized.user_not_available_call, name))
                                }
                            }
                        }

                        // Only end call if we got no public keys at all
                        guard !idToKeyMap.isEmpty else {
                            self.endCall(uuid: callUUID)
                            return
                        }

                        // Encrypt a unique AES key for each callee
                        guard let encryptedKeys = self.prepareEncryptedInvitations(idToKeyMap) else {
                            self.endCall(uuid: callUUID)
                            return
                        }
                        // 4. Establish Janus session and create a room
                        self.setupJanusRoom(isVideo: isVideo) { [weak self] janusResult in
                            guard let self = self else { return }
                            switch janusResult {
                            case .failure(let err):
                                errorLog(" Janus setup failed: \(err)")
                                self.endCall(uuid: callUUID)
                            case .success(let roomID):
                                // 5. Notify backend to start group call and join it
                                self.startBackendCall(roomID: roomID, calleeIDs: calleeIDs, encryptedKeys: encryptedKeys, isVideo: isVideo)
                            }
                        }
                    }
                }
            }
        }
    }

    // Helper: Initialize local session state and notify UI
    private func initializeCallSession(
        callUUID: UUID,
        calleeIDs: [UInt64],
        calleeNames: [String],
        isVideo: Bool
    ) {
        // 1) Build callee participants with IDs + names (initial status: inviting)
        let participants: [Participant] = zip(calleeIDs, calleeNames).map { id, name in
            Participant(
                userId: id,
                deviceId: 0,
                displayName: name,
                isHost: false,
                isLocal: false,
                feedId: 0,
                isMuted: false,
                isVideoEnabled: isVideo ? true : false,
                status: .inviting  // Initial status for new invites
            )
        }

        // 2) Kick off the session with temp IDs (0) until the backend replies
        callSessionManager.startCallSession(
            uuid: callUUID,
            callId: 0,
            janusRoomId: 0,
            participants: participants,
            isVideo: isVideo
        )
    }

    // MARK: - Common Encryption Logic (DRY)
    
    /// Encrypt group key for a single participant (reused by invite, rotation, and self-encryption)
    /// - Parameters:
    ///   - groupKey: The group AES key to encrypt
    ///   - participantPublicKeyBase64: Participant's public key (Base64 string)
    /// - Returns: Encrypted key string in format "publicKey:encryptedGroupKey" (P-256) or Base64 encrypted key (RSA)
    func encryptGroupKeyForParticipant(groupKey: Data, participantPublicKeyBase64: String) -> String? {
        let p256Service = P256SecureEnclaveService.shared
        
        // Detect key type by size: P-256 (~88 chars) vs RSA (~344+ chars)
        if participantPublicKeyBase64.count < 150 {
            // P-256 key detected - use ECDH
            do {
                let privateKey = try p256Service.loadPrivateKeyReference()
                
                // Encrypt group key for this participant
                guard let encryptedGroupKey = encryptionManager.encryptGroupKeyP256(
                    groupKey: groupKey,
                    participantPublicKeyBase64: participantPublicKeyBase64
                ) else {
                    errorLog("Failed to encrypt group key for P256 user")
                    return nil
                }
                
                // Get our public key
                let ourPublicKey = p256Service.getPublicKeyBase64(from: privateKey)
                
                // Format: "publicKey:encryptedGroupKey"
                return "\(ourPublicKey):\(encryptedGroupKey.base64EncodedString())"
                
            } catch {
                errorLog("Failed to process P256 key: \(error)")
                return nil
            }
        } else {
            // RSA key detected - use legacy RSA encryption
            guard let secKey = KeyStorage.shared.createSecKeyPublic(from: participantPublicKeyBase64),
                  let aesData = encryptionManager.encryptAESKeyForRejoin(aesKey: groupKey, with: secKey) else {
                errorLog("Failed to encrypt for RSA user")
                return nil
            }
            return aesData.base64EncodedString()
        }
    }
    
    /// Encrypt group key for self (used when storing key for rejoin)
    private func encryptGroupKeyForSelf(groupKey: Data) -> String? {
        guard let publicKeyString = KeyStorage.shared.readPublicKey() else {
            return nil
        }
        return encryptGroupKeyForParticipant(groupKey: groupKey, participantPublicKeyBase64: publicKeyString)
    }
    
    // MARK: - Invitation & Key Rotation Encryption
    
    /// Prepare encrypted invitations for multiple participants (used by invite and key rotation)
    /// - Parameters:
    ///   - idToKey: Map of userId_deviceId to public key
    ///   - groupKey: Group key to encrypt (if nil, uses existing sessionAESKey or generates new one)
    ///   - shouldGenerateNewKey: If true and groupKey is nil, generates new key
    /// - Returns: Map of userId_deviceId to encrypted key string
    func prepareEncryptedInvitations(_ idToKey: [String: String], groupKey: Data? = nil, shouldGenerateNewKey: Bool = true) -> [String: String]? {
        var encryptedKeys: [String: String] = [:]
        
        // Determine group key to use
        let keyToUse: Data
        if let providedKey = groupKey {
            keyToUse = providedKey
        } else if let existingKey = encryptionManager.sessionAESKey {
            keyToUse = existingKey
        } else if shouldGenerateNewKey {
            // Generate ONE group AES key for all participants (P256 group call requirement)
            let newKey = encryptionManager.randomAESKey()
            encryptionManager.originalAESKey = newKey
            encryptionManager.sessionAESKey = newKey
            encryptionManager.setUpAesKey(newKey)
            keyToUse = newKey
        } else {
            errorLog("No group key available and shouldGenerateNewKey is false")
            return nil
        }
        
        // Encrypt for each participant
        for (userIdDeviceId, publicKeyString) in idToKey {
            guard let encryptedKey = encryptGroupKeyForParticipant(
                groupKey: keyToUse,
                participantPublicKeyBase64: publicKeyString
            ) else {
                errorLog("Failed to encrypt group key for user \(userIdDeviceId)")
                // Continue with other participants instead of failing completely
                continue
            }
            encryptedKeys[userIdDeviceId] = encryptedKey
            debugLog("🔐 Encrypted group key for user \(userIdDeviceId)")
        }
        
        guard !encryptedKeys.isEmpty else {
            errorLog("No encrypted keys generated")
            return nil
        }
        
        return encryptedKeys
    }

    // Helper: Set up Janus session, attach plugin, and create a room
    private func setupJanusRoom(isVideo: Bool, completion: @escaping (Result<UInt64, Error>) -> Void) {
        janusClient.connectIfNeededForCall { [weak self] in
            self?.janusClient.createSession { res in
                guard case .success = res else {
                    completion(.failure(JanusError.sessionFailed))
                    return
                }
                self?.janusClient.attachPublisher { res in
                    guard case .success = res else {
                        completion(.failure(JanusError.attachFailed))
                        return
                    }
                    // Create a new Janus video room (optionally using admin key/room config)
                    self?.janusClient.createRoom { roomRes in
                        switch roomRes {
                        case .failure(let error):
                            completion(.failure(error))
                        case .success(let roomID):
                            debugLog("✅ Janus room created with ID:", roomID)
                            completion(.success(roomID))
                        }
                    }
                }
            }
        }
    }

    // Helper: Inform backend of new call, join it, then join Janus room & start WebRTC
    private func startBackendCall(roomID: UInt64, calleeIDs: [UInt64], encryptedKeys: [String: String], isVideo: Bool) {
        CallService.shared.startGroupCall(roomId: roomID, calleeIds: calleeIDs, encryptedAESKeys: encryptedKeys, isVideo: isVideo) { [weak self] record in
            DispatchQueue.main.async {
                guard let self = self else { return }
                guard let record = record, let callId = record.id else {
                    errorLog(" Backend call start failed.")
                    self.endCall(uuid: self.callSessionManager.currentCallUUID)  // End call on failure
                    return
                }

                // Store encryptedAESKey for this callId (for rejoin)
                // Encrypt group key for ourselves using same method as for participants
                if let groupKey = self.encryptionManager.sessionAESKey,
                   let encryptedKeyForSelf = self.encryptGroupKeyForSelf(groupKey: groupKey) {
                    let success = CallKeyStorage.shared.storeEncryptedAESKey(encryptedKeyForSelf, for: callId)
                    if !success {
                        debugLog("⚠️ Failed to store encryptedAESKey for outgoing callId: \(callId)")
                    }
                } else {
                    debugLog("⚠️ Could not create encryptedAESKey for self to store for callId: \(callId)")
                }

                // Update session with real call/room IDs
                self.callSessionManager.currentCallId = callId
                self.callSessionManager.janusRoomId = roomID

                // Update participants from backend, then check if we should start key rotation timer
                self.callSessionManager.updateParticipants { [weak self] in
                    guard let self = self else { return }
                    // Start key rotation timer if this user is the key rotation host
                    if self.callSessionManager.isKeyRotationHost {
                        self.startKeyRotationTimer()
                        debugLog("🔄 Key rotation timer started (confirmed by backend)")
                    } else {
                        debugLog("ℹ️ Not key rotation host, timer not started")
                    }
                }
                
                // Use backend join to get additional info (e.g., contactName for display)
                CallService.shared.joinGroupCall(callId: callId) { jRecord in
                    guard jRecord != nil else {
                        debugLog("⚠️ Backend joinGroupCall returned no info.")
                        return
                        // Proceed anyway; perhaps participant is offline or no data returned
                    }
                    // Join Janus room as publisher for WebRTC
                    let displayName = (KeyStorage.shared.readUserId() ?? "0") + ":" + (KeyStorage.shared.readDisplayName() ?? "Unknown")
                    self.janusClient.joinRoom(room: roomID, display: displayName) { res in
                        switch res {
                        case .failure(let err):
                            errorLog(" Janus joinRoom failed: \(err)")
                            self.endCall(uuid: self.callSessionManager.currentCallUUID)
                        case .success:
                            debugLog("✅ Joined Janus room. Starting WebRTC offer...")
                            WebRTCManager.publisher.setupPubPeerConnection()
                            WebRTCManager.publisher.createPubOffer()
                            SFXManager.shared.playRingback()
                        }
                    }
                }
            }
        }
    }

    /// Invite a list of new contacts into the *current* call.
    func inviteParticipants(calleeNames: [String], calleeIDs: [UInt64]) {
        guard validateInvitePrerequisites(calleeIDs: calleeIDs) else { return }

        guard let callId = callSessionManager.currentCallId,
              let roomId = callSessionManager.janusRoomId else {
            debugLog("⚠️ No active call to invite to.")
            return
        }

        fetchPublicKeysAndInvite(calleeNames: calleeNames, calleeIDs: calleeIDs, callId: callId, roomId: roomId)
    }

    private func validateInvitePrerequisites(calleeIDs: [UInt64]) -> Bool {
        guard encryptionManager.sessionAESKey != nil else {
            errorLog(" No session AES key available.")
            return false
        }
        guard !calleeIDs.isEmpty else { return false }
        debugLog("calleeIDs: \(calleeIDs)")
        return true
    }

    private func fetchPublicKeysAndInvite(calleeNames: [String], calleeIDs: [UInt64], callId: UInt64, roomId: UInt64) {
        UserService.shared.fetchPublicKeys(userIds: calleeIDs) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .failure(let err):
                errorLog(" Public key fetch failed: \(err)")
            case .success(let idToKeyMap):
                let requestedIdStrings = Set(calleeIDs.map { String($0) })
                let returnedUserIdStrings = Set(idToKeyMap.keys.compactMap { $0.split(separator: "_").first.map(String.init) })
                let missingUserIdStrings = requestedIdStrings.subtracting(returnedUserIdStrings)

                if !missingUserIdStrings.isEmpty {
                    for (idx, id) in calleeIDs.enumerated() {
                        if missingUserIdStrings.contains(String(id)) {
                            let name = idx < calleeNames.count ? calleeNames[idx] : ""
                            ToastManager.shared.error(String(format: KeyLocalized.user_not_available_call, name))
                        }
                    }
                }

                guard !idToKeyMap.isEmpty else {
                    return
                }

                // Invite only users that have a public key returned
                let availablePairs = zip(calleeNames, calleeIDs).filter { _, id in
                    returnedUserIdStrings.contains(String(id))
                }
                let filteredNames = availablePairs.map { $0.0 }
                let filteredIDs = availablePairs.map { $0.1 }

                self.processInvitation(calleeNames: filteredNames, calleeIDs: filteredIDs, callId: callId, roomId: roomId, idToKeyMap: idToKeyMap)
            }
        }
    }

    private func processInvitation(calleeNames: [String], calleeIDs: [UInt64], callId: UInt64, roomId: UInt64, idToKeyMap: [String: String]) {
        guard let encryptedKeys = prepareEncryptedInvitations(idToKeyMap) else {
            errorLog(" Failed to prepare invitations.")
            return
        }

        CallService.shared.inviteToGroupCall(
            callId: callId,
            roomId: roomId,
            calleeIds: calleeIDs,
            encryptedAESKeys: encryptedKeys,
            isVideo: callSessionManager.isVideoCall
        ) { [weak self] result in
            DispatchQueue.main.async {
                self?.handleInviteResult(result, calleeNames: calleeNames, calleeIDs: calleeIDs)
            }
        }
    }

    private func handleInviteResult(_ result: Result<InviteResponse, APIError>, calleeNames: [String], calleeIDs: [UInt64]) {
        callSessionManager.updateParticipants()

        switch result {
        case .success:
            successLog("Invited \(calleeNames)")

        case .failure(let error):
            ToastManager.shared.error(error.content)
        }
    }

    func handleCallInvitation(_ message: SignalMessage) {
        guard message.type == .call_invitation else {
            debugLog("🚫 Not a call‐invitation message; ignoring.")
            return
        }

        let callData = extractCallData(from: message)
        decryptAESKey(from: message)

        let update = createCallUpdate(callerName: callData.callerName, isVideo: callData.isVideo)
        let participants = createParticipants(from: callData)

        let callUUID = UUID()
        startCallSession(uuid: callUUID, callData: callData, participants: participants)

        reportIncomingCall(uuid: callUUID, update: update)
        saveCallState(uuid: callUUID, callId: callData.callId)
    }

    private struct CallData {
        let callerId: UInt64
        let callerName: String
        let callerDeviceId: UInt64
        let callId: UInt64
        let roomId: UInt64
        let isVideo: Bool
        let isOnGoing: Bool
    }

    private func extractCallData(from message: SignalMessage) -> CallData {
        return CallData(
            callerId: message.callerId ?? 0,
            callerName: message.callerName ?? KeyLocalized.unknown,
            callerDeviceId: message.callerDeviceId ?? 0,
            callId: message.callId ?? 0,
            roomId: message.roomId ?? 0,
            isVideo: message.isVideo ?? false,
            isOnGoing: message.isOnGoing ?? false
        )
    }

    private func decryptAESKey(from message: SignalMessage) {
        guard let keyB64 = message.encryptedAESKey,
              let callId = message.callId else {
            debugLog("⚠️ Failed to decrypt AES invitation key.")
            return
        }

        // Store encryptedAESKey (Base64 string) for rejoin
        let success = CallKeyStorage.shared.storeEncryptedAESKey(keyB64, for: callId)
        if !success {
            debugLog("⚠️ Failed to store encryptedAESKey for incoming callId: \(callId)")
        }

        // Reuse common decrypt logic
        decryptAESKeyCommon(keyB64: keyB64, isRotation: false)
    }
    
    /// Decrypt key rotation message and return decrypted key (for scheduled application)
    func decryptKeyRotationMessage(encryptedAESKey: String) -> Data? {
        // Reuse common decrypt logic to get the key
        // But don't apply it yet - return it for scheduled application
        if encryptedAESKey.contains(":") {
            // P-256 group call format: "publicKey:encryptedGroupKey"
            let components = encryptedAESKey.split(separator: ":")
            guard components.count == 2 else {
                debugLog("⚠️ Invalid P256 group call format")
                return nil
            }
            
            let callerPublicKey = String(components[0])
            let encryptedGroupKeyBase64 = String(components[1])
            
            guard let encryptedGroupKeyData = Data(base64Encoded: encryptedGroupKeyBase64),
                  let groupKey = encryptionManager.decryptGroupKeyP256(
                    encryptedGroupKey: encryptedGroupKeyData,
                    initiatorPublicKeyBase64: callerPublicKey
                  ) else {
                debugLog("⚠️ Failed to decrypt P256 group key")
                return nil
            }
            
            return groupKey
            
        } else if encryptedAESKey.count < 150 {
            // P-256 1-to-1 call format: just "publicKey"
            // This shouldn't happen in group call, but handle it
            if encryptionManager.processCallInvitationP256(callerPublicKeyBase64: encryptedAESKey) {
                return encryptionManager.sessionAESKey
            }
            return nil
            
        } else {
            // RSA format: encrypted AES key
            guard let keyData = Data(base64Encoded: encryptedAESKey),
                  let privateKey = KeyStorage.shared.readPrivateKeyAsSecKey(),
                  let aesKey = encryptionManager.processCallInvitation(
                    encryptedAESKey: keyData,
                    calleeRSAPrivateKey: privateKey
                  ) else {
                debugLog("⚠️ Failed to decrypt RSA AES key")
                return nil
            }
            
            return aesKey
        }
    }
    
    /// Schedule key application for participant at synchronized timestamp
    func scheduleKeyApplicationForParticipant(groupKey: Data, keyRotationTimestamp: Double) {
        let scheduledAt = Date().timeIntervalSince1970
        let delay = max(0, keyRotationTimestamp - scheduledAt)

        debugLog("⏰ [T=\(String(format: "%.3f", scheduledAt))] Scheduling participant key application in \(delay) seconds (apply at timestamp \(keyRotationTimestamp))")

        // Set future key immediately to handle early-arriving packets from other participants
        // who may apply the key slightly earlier due to clock skew or network timing
        encryptionManager.setFutureSessionKey(groupKey)

        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self = self else { return }

            // Verify call is still active
            guard self.callSessionManager.callStatus == .connected else {
                debugLog("⚠️ Key application cancelled: call ended")
                return
            }

            // Apply new key at synchronized time (with buffer)
            // setUpAesKey will preserve backup key for gap handling and clear future key
            // NOTE: Do NOT set sessionAESKey directly - setUpAesKey will set it thread-safely
            // Setting it directly would cause backup key to be saved incorrectly (as new key instead of old key)
            self.encryptionManager.originalAESKey = groupKey
            self.encryptionManager.setUpAesKey(groupKey)
        }
    }
    
    /// Common decrypt logic reused by both invite and key rotation
    private func decryptAESKeyCommon(keyB64: String, isRotation: Bool) {
        // Detect format and decrypt accordingly
        if keyB64.contains(":") {
            // P-256 group call format: "publicKey:encryptedGroupKey"
            let components = keyB64.split(separator: ":")
            guard components.count == 2 else {
                debugLog("⚠️ Invalid P256 group call format")
                return
            }

            let callerPublicKey = String(components[0])
            let encryptedGroupKeyBase64 = String(components[1])

            guard let encryptedGroupKeyData = Data(base64Encoded: encryptedGroupKeyBase64),
                  let groupKey = encryptionManager.decryptGroupKeyP256(
                    encryptedGroupKey: encryptedGroupKeyData,
                    initiatorPublicKeyBase64: callerPublicKey
                  ) else {
                debugLog("⚠️ Failed to decrypt P256 group key")
                return
            }

            // DEPRECATED: This method should NOT be used for key rotation!
            // Key rotation should use scheduleKeyApplicationForParticipant instead
            if isRotation {
                errorLog("❌ [BUG] decryptAESKeyCommon called with isRotation=true! This is deprecated!")
                return
            }

            // Set up session with group key (only for initial call invitation)
            // NOTE: setUpAesKey will set sessionAESKey thread-safely
            encryptionManager.originalAESKey = groupKey
            encryptionManager.setUpAesKey(groupKey)

            debugLog("🔓 P256 group key decrypted successfully\(isRotation ? " (rotation)" : "")")

        } else if keyB64.count < 150 {
            // P-256 1-to-1 call format: just "publicKey"
            guard encryptionManager.processCallInvitationP256(callerPublicKeyBase64: keyB64) else {
                debugLog("⚠️ Failed to process P256 1-to-1 call invitation")
                return
            }

            debugLog("🔓 P256 1-to-1 key derived successfully\(isRotation ? " (rotation)" : "")")

        } else {
            // RSA format: encrypted AES key
            guard let keyData = Data(base64Encoded: keyB64),
                  encryptionManager.processCallInvitation(
                    encryptedAESKey: keyData,
                    calleeRSAPrivateKey: KeyStorage.shared.readPrivateKeyAsSecKey()
                  ) != nil else {
                debugLog("⚠️ Failed to decrypt RSA AES invitation key")
                return
            }

            debugLog("🔓 RSA AES key decrypted successfully\(isRotation ? " (rotation)" : "")")
        }
    }

    private func createCallUpdate(callerName: String, isVideo: Bool) -> CXCallUpdate {
        let update = CXCallUpdate()
        update.remoteHandle = CXHandle(type: .generic, value: callerName)
        update.hasVideo = isVideo
        return update
    }

    private func createParticipants(from callData: CallData) -> [Participant] {
        return [
            Participant(
                userId: UInt64(callData.callerId),
                deviceId: UInt64(callData.callerDeviceId),
                displayName: callData.callerName,
                isHost: true,
                isLocal: false,
                feedId: 0,
                isMuted: false,
                isVideoEnabled: callData.isVideo
            )
        ]
    }

    private func startCallSession(uuid: UUID, callData: CallData, participants: [Participant]) {
        callSessionManager.startCallSession(
            uuid: uuid,
            callId: callData.callId,
            janusRoomId: callData.roomId,
            participants: participants,
            isVideo: callData.isVideo
        )
        GroupCallSessionManager.shared.updateParticipants()
    }

    private func reportIncomingCall(uuid: UUID, update: CXCallUpdate) {
        provider.reportNewIncomingCall(with: uuid, update: update) { [weak self] error in
            if let err = error {
                errorLog(" Error reporting incoming call: \(err.localizedDescription)")
                WebRTCManager.publisher.resetConnection()
                WebRTCManager.subscriber.resetConnection()
            } else {
                debugLog("✅ Incoming call reported to CallKit.")
                // Start timeout timer for incoming call
                self?.startIncomingCallTimeout(uuid: uuid)
            }
        }
    }

    // MARK: - Incoming Call Timeout

    /// Start timeout timer for incoming call. Auto-reject if not answered within timeout interval.
    private func startIncomingCallTimeout(uuid: UUID) {
        // Cancel existing timer if any
        stopIncomingCallTimeout()

        incomingCallTimeoutTimer = Timer.scheduledTimer(withTimeInterval: incomingCallTimeoutInterval, repeats: false) { [weak self] _ in
            guard let self = self else { return }

            // Check if call is still active (not answered yet)
            if self.callSessionManager.currentCallUUID == uuid {
                debugLog("⏰ Incoming call timeout - auto rejecting call \(uuid)")
                // Auto-reject with unanswered reason
                self.endCallImmediately(reason: .unanswered, isSilent: true)
                // Notify server that call was missed
                if let callId = self.callSessionManager.currentCallId {
                    CallService.shared.endCall(callId: callId) { _ in
                        debugLog("📞 Missed call logged to server")
                    }
                }
            }
        }
    }

    /// Stop and invalidate incoming call timeout timer
    private func stopIncomingCallTimeout() {
        incomingCallTimeoutTimer?.invalidate()
        incomingCallTimeoutTimer = nil
    }

    private func saveCallState(uuid: UUID, callId: UInt64) {
        callSessionManager.currentCallUUID = uuid
        callSessionManager.currentCallId = callId
    }

    // MARK: - End Call (unchanged logic with minor improvements)
    func endCall(uuid: UUID? = nil) {
        SFXManager.shared.playEndCall()

        // If this is a rejoin flow (not managed by CallKit), directly notify backend and cleanup
        if callSessionManager.isRejoinFlow {
            if let callId = callSessionManager.currentCallId {
                CallService.shared.endCall(callId: callId) { _ in
                    debugLog("📞 endCall API called for rejoin flow")
                }
            }
            // Local cleanup without relying on CallKit callbacks
            stopIncomingCallTimeout()
            stopKeyRotationTimer() // Stop key rotation timer
            callSessionManager.endCallSession()
            encryptionManager.sessionAESKey = nil
            JanusSocketClient.shared.reset()
            WebRTCManager.publisher.resetConnection()
            WebRTCManager.subscriber.resetConnection()
            NotificationCenter.default.post(name: .callDidEnd, object: nil)
            return
        }

        let uuidToEnd = uuid ?? callSessionManager.currentCallUUID

        guard let callUUID = uuidToEnd else { return }
        let endAction = CXEndCallAction(call: callUUID)
        let transaction = CXTransaction(action: endAction)

        callController.request(transaction) { error in
            if let error = error {
                errorLog("Error ending call: \(error.localizedDescription)")
            }
            debugLog("Call ended (CXEndCallAction submitted).")
        }
    }

    /// Immediately terminate call (used for remote hangup or errors)
    func endCallImmediately(reason: CXCallEndedReason, isSilent: Bool = false) {
        // Stop timeout timer when call ends
        stopIncomingCallTimeout()

        if !isSilent {
            SFXManager.shared.playEndCall()
        }
        guard let uuid = callSessionManager.currentCallUUID else { return }
        provider.reportCall(with: uuid, endedAt: Date(), reason: reason)

        DispatchQueue.main.async {
            self.callSessionManager.endCallSession()
        }
        stopKeyRotationTimer() // Stop key rotation timer
        encryptionManager.sessionAESKey = nil
        JanusSocketClient.shared.reset()
        // AudioSessionManager.shared.deactivateAudioSession()
        DispatchQueue.main.async {
            WebRTCManager.publisher.resetConnection()
            WebRTCManager.subscriber.resetConnection()
            NotificationCenter.default.post(name: .callDidEnd, object: nil)
        }
    }

    func startJanusFlow(for callId: UInt64) {
        janusClient.connectIfNeededForCall { [weak self] in
            // 5) Create session → attach publisher → join call
            self?.janusClient.createSession { res in
                guard case .success = res else {
                    errorLog(" createSession failed:", res)
                    return
                }
                self?.janusClient.attachPublisher { res in
                    guard case .success = res else {
                        errorLog(" attachPublisher failed:", res)
                        return
                    }

                    CallService.shared.joinGroupCall(callId: callId) { jRecord in
                        guard jRecord != nil else {
                            errorLog(" joinGroupCall returned nil record")
                            return
                        }
                        self?.janusClient.joinRoom(
                            room: self?.callSessionManager.janusRoomId ?? 0,
                            display: (self?.keystorage.readUserId() ?? "0") + ":" + (self?.keystorage.readDisplayName() ?? "Unknown")
                        ) { res in
                            switch res {
                            case .failure(let e):
                                errorLog(" joinRoom failed:", e)
                            case .success:
                                WebRTCManager.publisher.createPubOffer()
                            //                                StompSignalingManager.shared.sendParticipantAlerted(callId: GroupCallSessionManager.shared.currentCallId ?? 0)
                            }
                        }
                    }
                }
            }
        }
    }

    func startJanusFlowRejoinCall(for callId: UInt64, isVideo: Bool) {
        janusClient.connectIfNeededForCall {
            // 5) Create session → attach publisher → join call
            self.janusClient.createSession { res in
                guard case .success = res else {
                    errorLog(" createSession failed:", res)
                    return
                }
                self.janusClient.attachPublisher { res in
                    guard case .success = res else {
                        errorLog(" attachPublisher failed:", res)
                        return
                    }

                    let callerName = (self.keystorage.readUserId() ?? "0") + ":" + (self.keystorage.readDisplayName() ?? "Unknown")

                    self.janusClient.joinRoom(
                        room: self.callSessionManager.janusRoomId ?? 0,
                        display: callerName
                    ) { res in
                        switch res {
                        case .failure(let e):
                            errorLog(" joinRoom failed:", e)
                        case .success:
                            WebRTCManager.publisher.createPubOffer()
                        }
                    }
                }
            }
        }
    }

    // MARK: - CXProviderDelegate Methods

    func provider(_ provider: CXProvider, perform action: CXStartCallAction) {
        provider.reportOutgoingCall(with: action.callUUID, startedConnectingAt: Date())
        action.fulfill()
    }

    func provider(_ provider: CXProvider, perform action: CXAnswerCallAction) {
        // Cancel timeout when user answers
        stopIncomingCallTimeout()

        guard let callId = callSessionManager.currentCallId else {
            debugLog("⚠️ No call ID available")
            action.fail()
            return
        }

        NotificationCenter.default.post(name: .didAnswerCall, object: nil)

        startJanusFlow(for: callId)

        AudioSessionManager.shared.configureAudioSession()

        action.fulfill()
    }

    func provider(_ provider: CXProvider, perform action: CXEndCallAction) {
        // Cancel timeout when user rejects/hangup
        stopIncomingCallTimeout()

        // Notify the other party via signaling that the call is ended
        CallService.shared.endCall(callId: callSessionManager.currentCallId) { _ in
            GroupCallManager.shared.endCallImmediately(reason: .remoteEnded)
            NotificationCenter.default.post(name: .callDidEnd, object: nil)
        }
        // Clean up local call state
        stopKeyRotationTimer() // Stop key rotation timer
        self.callSessionManager.endCallSession()
        encryptionManager.sessionAESKey = nil
        JanusSocketClient.shared.reset()
        // AudioSessionManager.shared.deactivateAudioSession()
        WebRTCManager.publisher.resetConnection()
        WebRTCManager.subscriber.resetConnection()
        action.fulfill()
    }

    func providerDidReset(_ provider: CXProvider) {
        // System reset or crash - stop all timers and cleanup
        stopKeyRotationTimer()
        stopIncomingCallTimeout()
        debugLog("🔄 CallKit provider reset - stopped all timers")
    }
    
    // MARK: - Key Rotation
    
    /// Start key rotation timer (only if user is key rotation host)
    private func startKeyRotationTimer() {
        stopKeyRotationTimer() // Stop any existing timer
        
        guard callSessionManager.isKeyRotationHost else {
            debugLog("⚠️ Cannot start key rotation: not the key rotation host")
            return
        }

        debugLog("🔄 Starting key rotation timer (interval: \(keyRotationInterval)s)")
        
        keyRotationTimer = Timer.scheduledTimer(withTimeInterval: keyRotationInterval, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.performKeyRotation()
        }
    }
    
    /// Start key rotation timer if user is host (public method for external calls)
    func startKeyRotationTimerIfHost() {
        startKeyRotationTimer()
    }
    
    /// Stop key rotation timer
    private func stopKeyRotationTimer() {
        keyRotationTimer?.invalidate()
        keyRotationTimer = nil
        debugLog("🛑 Key rotation timer stopped")
    }
    
    /// Stop key rotation timer if user is not host (public method for external calls)
    func stopKeyRotationTimerIfNotHost() {
        guard !callSessionManager.isKeyRotationHost else { return }
        stopKeyRotationTimer()
    }
    
    /// Perform key rotation: generate new key, encrypt for all participants, and broadcast
    private func performKeyRotation() {
        guard callSessionManager.isKeyRotationHost else {
            debugLog("⚠️ Key rotation: Only key rotation host can perform rotation")
            stopKeyRotationTimer()
            return
        }
        
        guard let callId = callSessionManager.currentCallId,
              callSessionManager.callStatus == .connected else {
            debugLog("⚠️ Key rotation: Call not active or not connected")
            return
        }
        
        // Generate new group key (but don't apply yet - wait for synchronized timing)
        let newGroupKey = encryptionManager.randomAESKey()
        
        // Calculate synchronized timestamp: current time + seconds delay
        // All participants (including host) will apply key at this exact time
        let keyRotationTimestamp = Date().timeIntervalSince1970 + delayTimeKeyRotationUpdate
        
        // Get all participants (excluding self)
        let participants = callSessionManager.participants.filter { participant in
            guard let currentUserId = UInt64(KeyStorage.shared.readUserId() ?? "") else { return false }
            return participant.userId != currentUserId
        }
        
        guard !participants.isEmpty else {
            debugLog("⚠️ Key rotation: No other participants to send key to")
            return
        }
        
        // Fetch public keys for all participants
        let participantIds = participants.map { $0.userId }
        UserService.shared.fetchPublicKeys(userIds: participantIds) { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .failure(let error):
                errorLog("❌ Key rotation failed to fetch public keys: \(error)")
                
            case .success(let idToKeyMap):
                // Encrypt new group key for each participant (reuse same logic as invite)
                // idToKeyMap format: ["userId_deviceId": "publicKey"]
                guard let encryptedKeys = self.prepareEncryptedInvitations(
                    idToKeyMap,
                    groupKey: newGroupKey,
                    shouldGenerateNewKey: false
                ) else {
                    errorLog("❌ Key rotation failed to encrypt keys for participants")
                    return
                }
                
                // Send key rotation signal to each participant with synchronized timestamp
                self.sendKeyRotationSignals(
                    callId: callId,
                    encryptedKeys: encryptedKeys,
                    participants: participants,
                    keyRotationTimestamp: keyRotationTimestamp
                )
                
                // Schedule host to apply key at synchronized time (delay 5 seconds)
                self.scheduleKeyApplication(
                    groupKey: newGroupKey,
                    keyRotationTimestamp: keyRotationTimestamp
                )
            }
        }
    }
    
    /// Send key rotation signals to participants (reuses same format and flow as invite)
    private func sendKeyRotationSignals(
        callId: UInt64,
        encryptedKeys: [String: String],
        participants: [Participant],
        keyRotationTimestamp: Double
    ) {
        debugLog("📤 Sending key rotation signals to \(participants.count) participants (scheduled for \(keyRotationTimestamp))")
        
        // Send key rotation signal to each participant (same format as invite)
        for participant in participants {
            let userIdAndDeviceId = "\(participant.userId)_\(participant.deviceId)"
            
            guard let encryptedKey = encryptedKeys[userIdAndDeviceId] else {
                errorLog("⚠️ No encrypted key found for participant \(userIdAndDeviceId)")
                continue
            }
            
            // Create key rotation signal message (same format as invite)
            var signal = SignalMessage(type: .key_rotation)
            signal.callId = callId
            signal.participantId = participant.userId
            signal.participantDeviceId = participant.deviceId
            signal.participantName = participant.displayName
            signal.encryptedAESKey = encryptedKey // Same format as invite: "publicKey:encryptedGroupKey"
            signal.keyRotationTimestamp = keyRotationTimestamp // Synchronized timestamp for all participants
            
            // Send via STOMP (same as invite)
            StompSignalingManager.shared.send(signal)
            
            successLog("📬 Sent key rotation to participant \(participant.displayName) (userId: \(participant.userId), apply at: \(keyRotationTimestamp))")
        }
    }
    
    /// Schedule key application at synchronized timestamp (for host)
    private func scheduleKeyApplication(groupKey: Data, keyRotationTimestamp: Double) {
        let now = Date().timeIntervalSince1970
        let delay = max(0, keyRotationTimestamp - now)

        debugLog("⏰ [HOST] Scheduling key application in \(delay) seconds (at timestamp \(keyRotationTimestamp))")

        // Set future key immediately (same as participant) to handle early-arriving packets
        // Host may receive video from participants who apply key slightly earlier
        encryptionManager.setFutureSessionKey(groupKey)

        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self = self else { return }

            // Verify we're still the key rotation host and call is still active
            guard self.callSessionManager.isKeyRotationHost,
                  self.callSessionManager.callStatus == .connected else {
                debugLog("⚠️ Key application cancelled: no longer host or call ended")
                return
            }

            // Apply new key at synchronized time (with buffer)
            // setUpAesKey will preserve backup key for gap handling
            // NOTE: Do NOT set sessionAESKey directly - setUpAesKey will set it thread-safely
            // Setting it directly would cause backup key to be saved incorrectly (as new key instead of old key)
            self.encryptionManager.originalAESKey = groupKey
            self.encryptionManager.setUpAesKey(groupKey)
        }
    }

    func provider(_ provider: CXProvider, didActivate audioSession: AVAudioSession) {
        //        AudioSessionManager.shared.configureAudioSession()
    }
    func provider(_ provider: CXProvider, didDeactivate audioSession: AVAudioSession) {
        // AudioSessionManager.shared.deactivateAudioSession()
    }
}
