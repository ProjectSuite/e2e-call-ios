import Foundation
import Combine
import Network

/// A singleton that watches for network‐path changes and drives reconnect logic for WebSocket, Janus, and WebRTC.
final class ConnectionCoordinator {

    static let shared = ConnectionCoordinator()
    private var cancellables = Set<AnyCancellable>()

    /// Prevent reconnect storms by debouncing rapid toggles.
    private let reconnectDebounceInterval: TimeInterval = 0.5
    private var lastNetworkChange: Date = .distantPast

    private init() {
        subscribeToNetworkChanges()
    }

    private func subscribeToNetworkChanges() {
        // Watch isConnected (and optionally isWiFi/isCellular) on the main queue
        NetworkMonitor.shared.$isConnected
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isConnected in
                guard let self = self else { return }

                // Debounce rapid on/off flaps
                let now = Date()
                if now.timeIntervalSince(self.lastNetworkChange) < self.reconnectDebounceInterval {
                    return
                }
                self.lastNetworkChange = now

                if isConnected {
                    // Came online (could be WiFi or Cellular). Reconnect everything.
                    self.handleDidGainConnection()
                } else {
                    // Went offline. Tear down connections.
                    self.handleDidLoseConnection()
                }
            }
            .store(in: &cancellables)

        // Optionally, if you want to detect Wi-Fi ↔ Cellular swaps (even when still connected):
        NetworkMonitor.shared.$isWiFi
            .combineLatest(NetworkMonitor.shared.$isCellular)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isWiFi, isCellular in
                guard let self = self else { return }
                // If still connected but the interface changed, trigger a “soft” reconnect.
                if NetworkMonitor.shared.isConnected {
                    self.handleInterfaceSwitch(isWiFi: isWiFi, isCellular: isCellular)
                }
            }
            .store(in: &cancellables)
    }

    // MARK: – Offline Handling

    private func handleDidLoseConnection() {
        debugLog("🔴 Network lost—tearing down connections.")

        // 1) Tear down WebSocket
        StompSignalingManager.shared.disconnect()
        JanusSocketClient.shared.disconnect()

        // 2) Tear down any RTCPeerConnections
        WebRTCManager.publisher.resetConnection()
        WebRTCManager.subscriber.resetConnection()

        // 3) Optionally notify UI so it can show “Reconnecting…” spinner
        NotificationCenter.default.post(name: .didLoseNetwork, object: nil)
    }

    // MARK: – Online Handling

    private func handleDidGainConnection() {
        debugLog("🟢 Network available—reconnecting pipelines.")

        // 1) Reconnect WebSocket for API signaling
        StompSignalingManager.shared.connectIfReady(force: true)

        // 2) Reconnect Janus WS if you’re using Janus mode
        JanusSocketClient.shared.connect()

        // 3) If you were in a call when you went offline, re‐create the RTCPeerConnection(s) and re‐negotiate:
        if GroupCallSessionManager.shared.currentCallId != nil {
            // a) Tear down old PeerConnections
            WebRTCManager.publisher.resetConnection()
            WebRTCManager.subscriber.resetConnection()

            // b) Re‐build publisher/subscriber PeerConnections
            WebRTCManager.publisher.setupPubPeerConnection()
            WebRTCManager.subscriber.setupSubPeerConnection()

            // c) Recreate the SDP offer:
            // WebRTCManager.publisher.createOffer()
            // d) If you are a callee, you may need to wait for a new offer from the other side.
            //    The incoming offer will arrive via your WebSocket/Janus delegate once WS is open.
        }

        // 4) Notify UI so any “Reconnecting…” HUD can dismiss
        NotificationCenter.default.post(name: .didRegainNetwork, object: nil)
    }

    // MARK: – Interface Switch (Wi-Fi ↔ Cellular)

    private func handleInterfaceSwitch(isWiFi: Bool, isCellular: Bool) {
        debugLog("🔄 Network interface changed. isWiFi=\(isWiFi), isCellular=\(isCellular). Soft‐reconnect.")

        // If you want to do a “soft” reconnect (e.g. just re‐ping WebSocket rather than a full tear‐down),
        // you could check isWiFi/isCellular to decide strategy. Below is a full‐reconnect approach:

        // Cancel existing timers / sessions briefly
        StompSignalingManager.shared.disconnect()
        JanusSocketClient.shared.disconnect()

        // Brief delay to let the new cellular/WiFi interface settle
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            // Reconnect on the new interface
            StompSignalingManager.shared.connectIfReady(force: true)
            JanusSocketClient.shared.connect()

            // If mid‐call, re‐negotiate PeerConnection (similar to above)
            if GroupCallSessionManager.shared.currentCallId != nil {
                WebRTCManager.publisher.resetConnection()
                WebRTCManager.subscriber.resetConnection()
                WebRTCManager.publisher.setupPubPeerConnection()
                WebRTCManager.subscriber.setupSubPeerConnection()

                // WebRTCManager.publisher.createOffer()
            }
        }
    }
}

// MARK: – Notification Names

extension Notification.Name {
    /// Posted when network is lost (isConnected flipped to false).
    static let didLoseNetwork    = Notification.Name("didLoseNetwork")
    /// Posted when network is regained (isConnected flipped to true).
    static let didRegainNetwork  = Notification.Name("didRegainNetwork")
}
