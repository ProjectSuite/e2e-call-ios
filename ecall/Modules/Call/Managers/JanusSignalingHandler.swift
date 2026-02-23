import Foundation
import WebRTC

/// Delegate protocol for handling incoming group call signals.
protocol JanusSignalingDelegate: AnyObject {
    func didReceiveJanusSignal(_ message: JanusSignalMessage)
}

struct Publisher {
    let id: UInt64
    let display: String
    let audioCodec: String?
    let videoCodec: String?
}

class JanusSignalingHandler: JanusSignalingDelegate {
    static let shared = JanusSignalingHandler()
    private init() {}

    // MARK: - State
    private var currentPublishers: [Publisher] = []
    private var currentRoomID: UInt64?
    private var requestSubcribed = Set<String>()

    // MARK: - Delegate Method
    func didReceiveJanusSignal(_ message: JanusSignalMessage) {
        let janusType = message.janus
        switch janusType {
        case "event":
            handleEvent(message)

        case "trickle":
            handleTrickle(message)

        case "error":
            handleError(message)

        default:
            // debugLog("⚠️ Unhandled Janus type: \(janusType) — \(message)")
            ()
        }
    }

    // MARK: - Event Handling
    private func handleEvent(_ message: JanusSignalMessage) {
        guard let eventData = extractEventData(from: message) else { return }

        debugLog("🎥 videoroom event: \(eventData.videoroom)")
        handleVideoRoomEvent(eventData)
        handleJSEPIfPresent(message)
    }

    private struct EventData {
        let data: [String: Any]
        let videoroom: String
    }

    private func extractEventData(from message: JanusSignalMessage) -> EventData? {
        guard
            let pluginData = message.plugindata,
            let data = pluginData["data"] as? [String: Any],
            let videoroom = data["videoroom"] as? String
        else {
            debugLog("⚠️ Malformed <event> payload: \(message.plugindata ?? [:])")
            return nil
        }
        return EventData(data: data, videoroom: videoroom)
    }

    private func handleVideoRoomEvent(_ eventData: EventData) {
        switch eventData.videoroom {
        case "joined":
            onRoomJoined(eventData.data)
        case "event":
            handleEventType(eventData.data)
        case "updated":
            handleRoomUpdated()
        default:
            break
        }
    }

    private func handleEventType(_ data: [String: Any]) {
        handleParticipantLeaving(data)
        onPublisherUpdate(data)
    }

    private func handleParticipantLeaving(_ data: [String: Any]) {
        if let leavingID = data["leaving"] as? UInt64 {
            onParticipantLeft(leavingID)
        }
        if let unpublishedID = data["unpublished"] as? UInt64 {
            onParticipantLeft(unpublishedID)
        }
    }

    private func handleRoomUpdated() {
        GroupCallSessionManager.shared.callStatus = .connected
    }

    private func handleJSEPIfPresent(_ message: JanusSignalMessage) {
        guard let jsep = message.jsep,
              let senderHandle = message.sender,
              let sdp = jsep["sdp"] as? String,
              let type = jsep["type"] as? String else { return }

        switch type {
        case "offer":
            debugLog("📨 SDP OFFER received")
            WebRTCManager.subscriber.handleRemoteOffer(sdp: sdp)
        case "answer":
            handleSDPAnswer(senderHandle: senderHandle, sdp: sdp)
        default:
            debugLog("⚠️ Unhandled JSEP type: \(type)")
        }
    }

    private func handleSDPAnswer(senderHandle: UInt64, sdp: String) {
        debugLog("✅ SDP ANSWER received: \(senderHandle == JanusSocketClient.shared.publisherHandleId)")

        if senderHandle == JanusSocketClient.shared.publisherHandleId {
            WebRTCManager.publisher.handleRemoteAnswer(sdp: sdp)
        } else if senderHandle == JanusSocketClient.shared.subscriberHandleId {
            WebRTCManager.subscriber.handleRemoteAnswer(sdp: sdp)
        }
    }

    private func onRoomJoined(_ data: [String: Any]) {
        debugLog("🎉 onRoomJoined")
        requestSubcribed.removeAll()
        currentRoomID = data["room"] as? UInt64
        let pubs = (data["publishers"] as? [[String: Any]] ?? []).compactMap { dict -> Publisher? in
            guard let id = dict["id"] as? UInt64 else { return nil }
            let display = (dict["display"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? "Guest \(id)"
            let userId = UInt64(extractUserId(from: display)) ?? 0
            let displayName = extractDisplayName(from: display)
            let hasAudio = dict["audio"] as? Bool ?? true
            let hasVideo = dict["video"] as? Bool ?? true

            if GroupCallSessionManager.shared.getParticipant(byUserId: userId) != nil {
                // Update feed IDs for existing participant
                if hasAudio || hasVideo {
                    debugLog("🔄 Updating feedId \(id) for existing participant \(displayName) (userId: \(userId))")
                    GroupCallSessionManager.shared.updateFeedId(userId: userId, feedId: id)
                }
                debugLog("🔄 Updated existing participant: \(display)")
            }

            return Publisher(
                id: id,
                display: display,
                audioCodec: dict["audio_codec"] as? String,
                videoCodec: dict["video_codec"] as? String
            )
        }
        currentPublishers = pubs
    }

    private func onPublisherUpdate(_ data: [String: Any]) {
        // 1) Handle the initial “configured = ok” event and attach subscriber once
        guard let newArray = data["publishers"] as? [[String: Any]] else {
            if let room = currentRoomID,
               data["configured"] as? String == "ok" {
                let ids = currentPublishers.map { $0.id }
                JanusSocketClient.shared.attachSubscriber { _ in
                    if !ids.isEmpty {
                        let request = self.requestSubcribed.isEmpty ? "join" : "subscribe"
                        self.requestSubcribed.insert(request)
                        JanusSocketClient.shared.subscribe(to: ids, request: request, room: room, offerSDP: "")
                    }
                }
            }
            return
        }

        // 2) Build the new Publisher list, merge into currentPublishers
        let newPubs = newArray.compactMap { dict -> Publisher? in
            guard let id = dict["id"] as? UInt64 else { return nil }
            let display = (dict["display"] as? String).flatMap { $0.isEmpty ? nil : $0 }
                ?? "Guest \(id)"
            let userId = UInt64(extractUserId(from: display)) ?? 0
            let displayName = extractDisplayName(from: display)
            let hasAudio = dict["audio"] as? Bool ?? true
            let hasVideo = dict["video"] as? Bool ?? true

            if GroupCallSessionManager.shared.getParticipant(byUserId: userId) != nil {
                // Update feed IDs for existing participant
                if hasAudio || hasVideo {
                    debugLog("🔄 Updating feedId \(id) for existing participant \(displayName) (userId: \(userId))")
                    GroupCallSessionManager.shared.updateFeedId(userId: userId, feedId: id)
                }
                debugLog("🔄 Updated existing participant: \(display)")
            }

            return Publisher(
                id: id,
                display: display,
                audioCodec: dict["audio_codec"] as? String,
                videoCodec: dict["video_codec"] as? String
            )
        }
        // Merge, avoiding dupes
        for pub in newPubs where !currentPublishers.contains(where: { $0.id == pub.id }) {
            currentPublishers.append(pub)
        }

        let newIDs = newPubs.map { $0.id }

        // 3) Re-subscribe *all* feeds in one go (no re-attach!)
        if let room = currentRoomID {
            let request = self.requestSubcribed.isEmpty ? "join" : "subscribe"
            self.requestSubcribed.insert(request)
            JanusSocketClient.shared.subscribe(to: newIDs, request: request, room: room, offerSDP: "")
        }
    }

    private func onParticipantLeft(_ id: UInt64) {
        if let idx = currentPublishers.firstIndex(where: { $0.id == id }) {
            currentPublishers.remove(at: idx)
        }

        // 4) notify your session manager / delegate / UI
        GroupCallSessionManager.shared.updateParticipants()
    }

    // MARK: - Trickle
    private func handleTrickle(_ message: JanusSignalMessage) {
        //        debugLog("🧊 handleTrickle - Sender: \(message.sender ?? 0)")
        guard
            let candDict = message.candidate,
            let sdp = candDict["candidate"] as? String,
            let sdpMid = candDict["sdpMid"] as? String,
            let idx = candDict["sdpMLineIndex"] as? Int
        else {
            if let completed = message.candidate as? [String: Bool], completed["completed"] == true {
                //                debugLog("✅ ICE gathering completed")
                return
            }
            debugLog("⚠️ Malformed trickle: \(message.candidate ?? [:])")
            return
        }

        let ice = RTCIceCandidate(sdp: sdp, sdpMLineIndex: Int32(idx), sdpMid: sdpMid)
        guard let senderHandle = message.sender else {
            debugLog("⚠️ No sender handle in trickle message")
            return
        }

        if senderHandle == JanusSocketClient.shared.publisherHandleId {
            WebRTCManager.publisher.addRemoteIceCandidate(candidate: ice)
        } else if senderHandle == JanusSocketClient.shared.subscriberHandleId {
            WebRTCManager.subscriber.addRemoteIceCandidate(candidate: ice)
        } else {
            debugLog("⚠️ Unknown sender handle \(senderHandle)")
        }
    }

    // MARK: - Error
    private func handleError(_ message: JanusSignalMessage) {
        if let err = message.error,
           let code = err["code"] as? Int,
           let reason = err["reason"] as? String {
            errorLog(" Janus error [\(code)]: \(reason)")
        } else {
            errorLog(" Janus error, no details: \(message)")
        }
    }

    private func extractUserId(from display: String) -> String {
        let components = display.components(separatedBy: ":")
        if components.count >= 2 {
            return components[0]
        }
        return "0" // fallback
    }

    private func extractDisplayName(from display: String) -> String {
        let components = display.components(separatedBy: ":")
        if components.count >= 2 {
            return components[1]
        }
        return "Unknown" // fallback
    }
}
