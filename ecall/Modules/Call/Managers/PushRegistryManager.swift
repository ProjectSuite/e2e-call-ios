import Foundation
import PushKit
import UserNotifications

/// VoIP push is now only used for call invitations
/// Friend requests and warnings are handled via APNs alert notifications

class PushRegistryManager: NSObject, PKPushRegistryDelegate {

    static let shared = PushRegistryManager()

    private override init() {
        super.init()
        let registry = PKPushRegistry(queue: DispatchQueue.main)
        registry.delegate = self
        registry.desiredPushTypes = [.voIP]

        // Log current token if exists
        if let currentToken = KeyStorage.shared.readVoipToken() {
            debugLog("📱 Current VoIP Token: \(currentToken)")
        } else {
            debugLog("📱 No VoIP Token found")
        }
    }

    // Called when the system has new push credentials (VoIP token) for the device
    func pushRegistry(_ registry: PKPushRegistry, didUpdate pushCredentials: PKPushCredentials, for type: PKPushType) {
        guard type == .voIP else { return }
        let deviceToken = pushCredentials.token.map { String(format: "%02x", $0) }.joined()
        debugLog("📱 New VoIP Token received: \(deviceToken)")
        KeyStorage.shared.storeVoipToken(voipToken: deviceToken)

        Task { @MainActor in
            if AppState.shared.isRegistered {
                // Register token with backend
                VoipService.shared.registerVoIPToken(deviceToken)
            }
        }
    }

    // Called if the push token is invalidated.
    func pushRegistry(_ registry: PKPushRegistry, didInvalidatePushTokenFor type: PKPushType) {
        errorLog(" Push token invalidated")
        // TODO: Inform your backend about token invalidation.
    }

    // Called when an incoming VoIP push is received
    // VoIP push is now ONLY used for call invitations
    func pushRegistry(_ registry: PKPushRegistry, didReceiveIncomingPushWith payload: PKPushPayload, for type: PKPushType, completion: @escaping () -> Void) {
        guard type == .voIP else {
            completion()
            return
        }

        debugLog("📱 Received VoIP Push (Call Only): \(payload.dictionaryPayload)")

        let payloadDict = payload.dictionaryPayload

        // VoIP push should only contain call invitation data
        handleCallInvitation(payloadDict)

        completion()
    }

    // MARK: - Notification Handlers

    private func handleCallInvitation(_ payloadDict: [AnyHashable: Any]) {
        debugLog("📱 Handling call invitation notification")

        if let callerId = payloadDict["callerId"] as? UInt64 {
            let callerDeviceId = payloadDict["callerDeviceId"] as? UInt64 ?? UInt64(0)
            let callerName = payloadDict["callerName"] as? String ?? KeyLocalized.unknown
            let encryptedAESKey = payloadDict["encryptedAESKey"] as? String ?? ""
            let isVideo = payloadDict["isVideo"] as? Bool ?? false
            let roomId = payloadDict["roomId"] as? UInt64 ?? UInt64(0)
            let isOnGoing = payloadDict["isOnGoing"] as? Bool ?? false
            let callUUID = UUID()  // generate a UUID for this incoming call
            GroupCallSessionManager.shared.currentCallUUID = callUUID

            // If callId is provided, store it for later use in signaling
            if let callIdNumber = payloadDict["callId"] as? UInt64 {
                GroupCallSessionManager.shared.currentCallId = callIdNumber
            }
            GroupCallSessionManager.shared.janusRoomId = roomId

            // Report the incoming call to CallKit (this will display the incoming call UI)
            GroupCallManager.shared.handleCallInvitation(SignalMessage(
                type: .call_invitation,
                callerId: callerId,
                callerDeviceId: callerDeviceId,
                callerName: callerName,
                encryptedAESKey: encryptedAESKey,
                callId: GroupCallSessionManager.shared.currentCallId,
                roomId: roomId,
                isVideo: isVideo,
                isOnGoing: isOnGoing
            ))
            CredentialsService.shared.fetchCredentials()
        }
    }

    // MARK: - Helper Functions

    /// Get current device token for testing
    func getCurrentDeviceToken() -> String? {
        return KeyStorage.shared.readVoipToken()
    }
}
