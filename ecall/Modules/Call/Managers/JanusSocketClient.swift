import Foundation
import WebRTC

/// Any error we can throw from our Janus client.
enum JanusError: Error {
    case serialization
    case missingField(String)
    case noSession
    case notReady
    case sessionFailed
    case attachFailed
}

/// A very light Janus event “envelope” parsed from a raw JSON dictionary.
struct JanusSignalMessage {
    let janus: String
    let session_id: UInt64?
    let handle_id: UInt64?
    let sender: UInt64?
    let plugindata: [String: Any]?
    let candidate: [String: Any]?
    let jsep: [String: Any]?
    let error: [String: Any]?
    /// Manually initialize from the raw JSON dictionary you got from the WS.
    init(from dict: [String: Any]) throws {
        guard let janus = dict["janus"] as? String else {
            throw JanusError.missingField("janus")
        }
        self.janus      = janus
        self.session_id = dict["session_id"] as? UInt64
        self.handle_id  = dict["handle_id"]  as? UInt64
        self.sender     = dict["sender"]  as? UInt64
        self.plugindata = dict["plugindata"] as? [String: Any]
        self.candidate  = dict["candidate"] as? [String: Any]
        self.jsep       = dict["jsep"]       as? [String: Any]
        self.error      = dict["error"]       as? [String: Any]
    }
}

/// Small box so we can remove the observer from inside the closure
private final class ObserverBox {
    var token: NSObjectProtocol?
}

/// Handy extension for converting Data→String
extension Data {
    var janusString: String? { String(data: self, encoding: .utf8) }
}

class JanusSocketClient {
    static let shared = JanusSocketClient()

    // Store room info for rejoining
    private var currentRoomId: UInt64?
    private var currentDisplay: String?
    private var wasPublisher = false
    private var wasSubscriber = false

    private var webSocket: URLSessionWebSocketTask?
    private var urlSession: URLSession?

    private let host: String

    let authToken: String = Endpoints.shared.janusApiSecret
    var sessionId: UInt64?
    var transactionId: String?
    var publisherHandleId: UInt64?
    var subscriberHandleId: UInt64?
    private(set) var isConnected = false

    // Add keepalive timer control
    private var keepaliveTimer: Timer?
    private let keepaliveInterval: TimeInterval = 30.0 // Janus recommends 30s

    /// Pending reply callbacks, keyed by `transaction`
    private var pending = [ String: (Result<[String: Any], Error>) -> Void ]()

    private init(host: String = APIEndpoint.janus.fullJanusSocketURL.absoluteString) {
        self.host = host
        
        let cfg = URLSessionConfiguration.default
        // Set timeout intervals for WebSocket connections
        cfg.timeoutIntervalForRequest = 30.0  // 30 seconds for individual request timeout
        cfg.timeoutIntervalForResource = 120.0  // 120 seconds for WebSocket connection timeout
        cfg.waitsForConnectivity = true  // Wait for network connectivity
        // Use SSLPinningManager for SSL certificate validation (prevents MITM attacks)
        self.urlSession = URLSession(
            configuration: cfg,
            delegate: SSLPinningManager.shared,
            delegateQueue: nil
        )
    }

    weak var signalingDelegate: JanusSignalingDelegate?
    private let janusQueue = DispatchQueue(label: "org.app.janusQueue")

    // MARK: —> Open & Listen

    func connect() {
        guard let url = URL(string: host) else {
            debugLog("🔴 Invalid URL: \(host)")
            return
        }
        guard let session = urlSession else {
            debugLog("🔴 No URL session available")
            return
        }
        webSocket = session.webSocketTask(with: url, protocols: ["janus-protocol"])
        webSocket?.resume()
        debugLog("🔗 Janus WS connected to \(host)")

        isConnected = true
        NotificationCenter.default.post(name: .janusSocketDidConnect, object: nil)

        listen()
    }

    /// Disconnect gracefully
    func disconnect() {
        debugLog("🔌 Disconnecting WebSocket")

        // Stop keepalive first
        stopSessionKeepalive()

        webSocket?.cancel(with: .normalClosure, reason: nil)
        webSocket = nil
        isConnected = false
    }

    func reset() {
        debugLog("🔄 Resetting JanusSocketClient")

        // Stop keepalive
        stopSessionKeepalive()

        // Close WebSocket
        webSocket = nil
        isConnected = false

        if sessionId != nil && publisherHandleId != nil && subscriberHandleId != nil {
            hangupPublisher()
            leaveSubscriber()
            destroySession { _ in }
        }

        sessionId = nil
        publisherHandleId = nil
        subscriberHandleId = nil
        pending.removeAll()
        subscribedFeeds.removeAll()
    }

    private func listen() {
        webSocket?.receive { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .failure(let err):
                debugLog("🔴 WS receive error:", err)
                self.scheduleReconnect()
            case .success(let msg):
                // debugLog("\(msg)")
                switch msg {
                case .string(let text):
                    self.handleReceivedText(text)
                case .data(let data):
                    if let text = String(data: data, encoding: .utf8) {
                        self.handleReceivedText(text)
                    }
                @unknown default:
                    break
                }
                // keep listening...
                self.listen()
            }
        }
    }

    private func scheduleReconnect() {
        disconnect()
        isConnected = false

        DispatchQueue.global().asyncAfter(deadline: .now() + 1.0) {
            debugLog("🔄 Reconnecting in 1s…")
            self.attemptReconnection()
        }
    }

    private func attemptReconnection() {
        // Store current session info for rejoin
        let previousSessionId = self.sessionId

        guard let url = URL(string: host) else {
            debugLog("🔴 Invalid URL: \(host)")
            return
        }

        guard let session = urlSession else {
            debugLog("🔴 No URL session available for reconnection")
            return
        }

        webSocket = session.webSocketTask(with: url, protocols: ["janus-protocol"])
        webSocket?.resume()
        debugLog("🔗 Janus WS reconnecting to \(host)")

        isConnected = true

        NotificationCenter.default.post(name: .janusSocketDidReconnect, object: nil)

        if let sid = previousSessionId {
            self.rejoinSession(sessionId: sid)
        }

        listen()
    }

    /// Start session keepalive with proper timer management
    func startSessionKeepalive() {
        // Stop existing timer first
        stopSessionKeepalive()

        guard sessionId != nil else {
            debugLog("⚠️ No session ID - cannot start keepalive")
            return
        }

        debugLog("🔄 Starting session keepalive (interval: \(keepaliveInterval)s)")

        keepaliveTimer = Timer.scheduledTimer(withTimeInterval: keepaliveInterval, repeats: true) { [weak self] _ in
            self?.sendKeepalive()
        }

        // Send first keepalive immediately
        sendKeepalive()
    }

    private func sendKeepalive() {
        guard let sid = sessionId, isConnected else {
            debugLog("⚠️ Cannot send keepalive - no session or disconnected")
            stopSessionKeepalive()
            return
        }

        debugLog("💓 Sending session keepalive for session \(sid)")

        send([
            "janus": "keepalive",
            "session_id": sid,
            "apisecret": authToken
        ]) { [weak self] result in
            switch result {
            case .success:
                debugLog("✅ Keepalive sent successfully")
            case .failure(let error):
                debugLog("❌ Keepalive failed: \(error)")
                // Stop keepalive on persistent failure
                self?.stopSessionKeepalive()
            }
        }
    }

    private func stopSessionKeepalive() {
        debugLog("🛑 Stopping session keepalive")
        keepaliveTimer?.invalidate()
        keepaliveTimer = nil
    }

    /// Ensure the socket is up before calling `completion`.
    /// If already connected, fires immediately; otherwise waits one shot.
    func connectIfNeededForCall(completion: @escaping () -> Void) {
        let box = ObserverBox()
        box.token = NotificationCenter.default.addObserver(
            forName: .janusSocketDidConnect,
            object: nil,
            queue: .main
        ) { _ in
            // tear down this one-shot observer
            if let t = box.token {
                NotificationCenter.default.removeObserver(t)
            }
            completion()
        }
        connect()
    }

    // MARK: —> Transactions

    /// Generates an 8‑byte hex string
    private func newTxn() -> String {
        let bytes = (0..<8).map { _ in UInt8.random(in: 0...255) }
        return Data(bytes).map { String(format: "%02x", $0) }.joined()
    }

    /// Sends a Janus request, tracks the completion by txn.
    private func send(
        _ payload: [String: Any],
        completion: @escaping (Result<[String: Any], Error>) -> Void
    ) {
        janusQueue.async { [weak self] in
            guard let self = self else { return }
            var msg = payload
            let txn = self.newTxn()
            msg["transaction"] = txn

            // Track the callback
            self.pending[txn] = completion

            // Serialize
            guard JSONSerialization.isValidJSONObject(msg),
                  let data = try? JSONSerialization.data(withJSONObject: msg),
                  let text = data.janusString
            else {
                self.pending.removeValue(forKey: txn)
                DispatchQueue.main.async {
                    completion(.failure(JanusError.serialization))
                }
                return
            }

            // Send over WebSocket
            self.webSocket?.send(.string(text)) { err in
                if let e = err {
                    // Cleanup on error
                    self.janusQueue.async {
                        self.pending.removeValue(forKey: txn)
                    }
                    DispatchQueue.main.async {
                        completion(.failure(e))
                    }
                }
            }
        }
    }

    private func handleReceivedText(_ text: String) {
        // debugLog("\(text)")
        janusQueue.async { [weak self] in
            guard let self = self else { return }

            // 2) Parse JSON
            guard
                let data = text.data(using: .utf8),
                let rawAny = try? JSONSerialization.jsonObject(with: data),
                let raw = rawAny as? [String: Any]
            else {
                return
            }

            // 3) If this is a transaction response, pop the callback
            if let txn = raw["transaction"] as? String,
               let cb  = self.pending.removeValue(forKey: txn) {
                DispatchQueue.main.async {
                    cb(.success(raw))
                }
                return
            }

            // 5) Otherwise it’s a server‐push event
            if let janus = raw["janus"] as? String,
               ["event", "webrtcup", "hangup", "trickle"].contains(janus) {
                do {
                    let msg = try JanusSignalMessage(from: raw)
                    // 6) Always notify delegate on main
                    DispatchQueue.main.async {
                        self.signalingDelegate?.didReceiveJanusSignal(msg)
                    }
                } catch {
                    debugLog("⚠️ decode signal error:", error)
                }
            }
        }
    }

    // MARK: —> High‑Level Janus API

    func createSession(completion: @escaping (Result<UInt64, Error>) -> Void) {
        debugLog("createSession")
        send(
            [
                "janus": "create",
                "apisecret": authToken
            ]) { res in
            switch res {
            case .failure(let e): completion(.failure(e))
            case .success(let dict):
                guard let d = dict["data"] as? [String: Any],
                      let id = d["id"] as? UInt64
                else { return completion(.failure(JanusError.missingField("data.id"))) }
                self.sessionId = id
                self.startSessionKeepalive()
                completion(.success(id))
            }
        }
    }

    func attachPublisher(completion: @escaping (Result<UInt64, Error>) -> Void) {
        debugLog("attachPlugin")
        guard let sid = sessionId else {
            return completion(.failure(JanusError.noSession))
        }
        send([
            "janus": "attach",
            "plugin": "janus.plugin.videoroom",
            "session_id": sid,
            "apisecret": authToken
        ]) { res in
            switch res {
            case .failure(let e): completion(.failure(e))
            case .success(let dict):
                guard let d = dict["data"] as? [String: Any],
                      let id = d["id"] as? UInt64
                else { return completion(.failure(JanusError.missingField("data.id"))) }
                self.publisherHandleId = id
                completion(.success(id))
            }
        }
    }

    func attachSubscriber(completion: @escaping (Result<UInt64, Error>) -> Void) {
        guard let sid = sessionId else { return }
        let payload: [String: Any] = [
            "janus": "attach",
            "plugin": "janus.plugin.videoroom",
            "session_id": sid,
            "transaction": newTxn(),
            "apisecret": authToken
        ]
        send(payload) { result in
            switch result {
            case .failure(let e): completion(.failure(e))
            case .success(let dict):
                guard let data = dict["data"] as? [String: Any],
                      let hid  = data["id"]   as? UInt64
                else { return completion(.failure(JanusError.missingField("data.id"))) }
                self.subscriberHandleId = hid
                completion(.success(hid))
            }
        }
    }

    func hangupPublisher() {
        guard let sid = sessionId, let hid = publisherHandleId else { return }
        let body: [String: Any] = ["request": "unpublish"]
        send([
            "janus": "message",
            "session_id": sid,
            "handle_id": hid,
            "body": body,
            "apisecret": authToken
        ]) { _ in }
    }

    func leaveSubscriber() {
        guard let sid = sessionId, let hid = subscriberHandleId else { return }
        let body: [String: Any] = ["request": "leave"]
        send([
            "janus": "message",
            "session_id": sid,
            "handle_id": hid,
            "body": body,
            "apisecret": authToken
        ]) { _ in }
    }

    func detach(handleId: UInt64, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let sid = sessionId else { return }
        send([
            "janus": "detach",
            "session_id": sid,
            "handle_id": handleId,
            "apisecret": authToken
        ]) { result in
            completion(result.map { _ in () })
        }
    }

    func destroySession(completion: @escaping (Result<Void, Error>) -> Void) {
        guard let sid = sessionId else { return completion(.failure(JanusError.noSession)) }
        send([
            "janus": "destroy",
            "session_id": sid,
            "apisecret": authToken
        ]) { result in
            completion(result.map { _ in () })
        }
    }

    func createRoom(completion: @escaping (Result<UInt64, Error>) -> Void) {
        debugLog("createRoom")
        guard let sid = sessionId, let hid = publisherHandleId else {
            return completion(.failure(JanusError.notReady))
        }
        let body: [String: Any] = [
            "request": "create",
            "video": true,
            "videocodec": "h264",
            "publishers": 200,
            "bitrate": 128_000,
            "bitrate_cap": true
            // "threads": 5,
            // "dummy_publisher": true,
            // "require_pvtid": true
            // "h264_profile": "640c1f",
            // "h264_profile": "4d0032",
            // "admin_key": adminKey
        ]
        send([
            "janus": "message",
            "session_id": sid,
            "handle_id": hid,
            "body": body,
            "apisecret": authToken
        ]) { res in
            switch res {
            case .failure(let e): completion(.failure(e))
            case .success(let dict):
                guard
                    let plug = dict["plugindata"] as? [String: Any],
                    let data = plug["data"]     as? [String: Any],
                    let room = data["room"]     as? UInt64
                else {
                    return completion(.failure(JanusError.missingField("plugindata.data.room")))
                }
                completion(.success(room))
            }
        }
    }

    func joinRoom(
        room: UInt64,
        display: String,
        completion: @escaping (Result<JanusSignalMessage, Error>) -> Void
    ) {
        debugLog("joinRoom")
        // 1) make sure we have a session & handle
        guard let sid = sessionId, let hid = publisherHandleId else {
            // explicitly tell Swift which Result.failure you mean:
            completion(Result<JanusSignalMessage, Error>.failure(JanusError.notReady))
            return
        }

        // 2) build the Janus \"join\" payload
        let body: [String: Any] = [
            "request": "join",
            "room": room,
            "ptype": "publisher",
            "display": display,
            "video": true,
            "videocodec": "h264"
            // "h264_profile": "4d0032",
        ]

        send([
            "janus": "message",
            "session_id": sid,
            "handle_id": hid,
            "body": body,
            "apisecret": authToken
        ]) { result in
            switch result {
            case .failure(let err):
                // again fully qualify the failure:
                completion(Result<JanusSignalMessage, Error>.failure(err))

            case .success(let dict):
                do {
                    // decode your JanusSignalMessage from the raw JSON dictionary
                    let msg = try JanusSignalMessage(from: dict)
                    completion(.success(msg))
                } catch {
                    // and failure here too:
                    completion(Result<JanusSignalMessage, Error>.failure(error))
                }
            }
        }
    }

    func sendJsep(_ jsep: [String: Any], _ body: [String: Any], _ handleId: UInt64,
                  completion: @escaping (Result<Void, Error>) -> Void) {
        debugLog("sendJsep")
        guard let sid = sessionId else {
            return completion(.failure(JanusError.notReady))
        }

        let payload = [
            "janus": "message",
            "transaction": newTxn(),
            "session_id": sid,
            "handle_id": handleId,
            "jsep": jsep,
            "body": body,
            "apisecret": authToken
        ] as [String: Any]
        // debugLog("sendJsep: \(payload)")
        send(payload) { result in
            completion(result.map { _ in () })

        }
    }

    func tricklePublisher(_ candidate: [String: Any],
                          completion: @escaping (Result<Void, Error>) -> Void) {
        // debugLog("tricklePublisher")
        guard let sid = sessionId, let hid = publisherHandleId else {
            return completion(.failure(JanusError.notReady))
        }
        send([
            "janus": "trickle",
            "session_id": sid,
            "handle_id": hid,
            "candidate": candidate,
            "apisecret": authToken
        ]) { result in
            completion(result.map { _ in () })
        }
    }

    func trickleSubscriber(_ candidate: [String: Any],
                           completion: @escaping (Result<Void, Error>) -> Void) {
        // debugLog("trickleSubscriber")
        guard let sid = sessionId, let hid = subscriberHandleId else {
            return completion(.failure(JanusError.notReady))
        }
        send([
            "janus": "trickle",
            "session_id": sid,
            "handle_id": hid,
            "candidate": candidate,
            "apisecret": authToken
        ]) { result in
            completion(result.map { _ in () })
        }
    }

    /// Send an SDP offer to Janus.
    /// - Parameters:
    ///   - sdp: The SDP offer string you generated via `createOffer`.
    ///   - completion: Called with `.success(())` or `.failure(error)`.
    func sendOffer(sdp: String, completion: @escaping (Result<Void, Error>) -> Void) {
        debugLog("sendOffer")
        guard sessionId != nil, publisherHandleId != nil else {
            return completion(.failure(JanusError.notReady))
        }
        let jsepDict: [String: Any] = [
            "type": "offer",
            "sdp": sdp
        ]

        let body: [String: Any] = [
            "request": "configure",
            "audio": true,
            "video": true,
            "videocodec": "h264"
            // "h264_profile": "4d0032",
            // "bitrate": 128_000,
            // "bitrate_cap": true
        ]
        guard let handleId = publisherHandleId else {
            completion(.failure(JanusError.notReady))
            return
        }
        sendJsep(jsepDict, body, handleId, completion: completion)
    }

    /// Send an SDP answer to Janus.
    /// - Parameters:
    ///   - sdp: The SDP answer string you generated via `createAnswer`.
    ///   - completion: Called with `.success(())` or `.failure(error)`.
    func sendAnswer(sdp: String, completion: @escaping (Result<Void, Error>) -> Void) {
        debugLog("sendAnswer")
        guard sessionId != nil, subscriberHandleId != nil else {
            return completion(.failure(JanusError.notReady))
        }
        let jsepDict: [String: Any] = [
            "type": "answer",
            "sdp": sdp
        ]
        let body: [String: Any] = [
            "request": "start",
            "audio": true,
            "video": true,
            "videocodec": "h264"
            // "h264_profile": "42e01f",
            // "bitrate": 128_000,
            // "bitrate_cap": true
        ]
        guard let handleId = subscriberHandleId else {
            completion(.failure(JanusError.notReady))
            return
        }
        sendJsep(jsepDict, body, handleId, completion: completion)
    }

    /// Keep track of every feed we’ve ever subscribed to.
    private var subscribedFeeds = Set<UInt64>()

    /// Subscribe (or re-subscribe) to the full set of feeds so none ever get torn down.
    /// Bulk‑subscribe to multiple feeds in one RTCPeerConnection.
    func subscribe(to feedIds: [UInt64], request: String, room: UInt64, offerSDP: String) {
        guard let sid = sessionId, let hid = subscriberHandleId else {
            debugLog("⚠️ Can't subscribe – no session or subscriber handle")
            return
        }

        // 1) Reset our feed list to exactly what was passed
        subscribedFeeds = Set(feedIds)

        // 2) Build a streams array containing *all* desired feeds
        let streams: [[String: Any]] = Array(subscribedFeeds).map { feedId in
            ["feed": feedId]
        }
        debugLog("📬 Bulk–subscribe streams:", streams)

        // 3) Send one join for the entire set, so Janus won't remove any old m= lines
        let body: [String: Any] = [
            "request": request,
            "room": room,
            "ptype": "subscriber",
            "streams": streams,
            "use_msid": true,
            "offer_audio": true,
            "offer_video": true
        ]
        let payload: [String: Any] = [
            "janus": "message",
            "transaction": newTxn(),
            "session_id": sid,
            "handle_id": hid,
            "body": body,
            "apisecret": authToken
        ]

        debugLog("▶️ Sending bulk-subscribe payload:\n\(payload)")
        send(payload) { result in
            switch result {
            case .failure(let e):
                errorLog(" bulk subscribe failed:", e)
            case .success:
                debugLog("✅ bulk subscribe succeeded for feeds:", Array(self.subscribedFeeds))
            }
        }
    }

    func rejoinSession(sessionId: UInt64) {
        // Re-establish session after reconnection
        let message: [String: Any] = [
            "janus": "claim",
            "session_id": sessionId,
            "transaction": newTxn(),
            "apisecret": authToken
        ]

        send(message) { [weak self] result in
            switch result {
            case .success:
                debugLog("✅ Session claim successful")
                // Restore sessionId and restart keepalive
                self?.sessionId = sessionId
                self?.startSessionKeepalive()
                GroupCallSessionManager.shared.checkContinueCallState()

            case .failure(let error):
                debugLog("❌ Session claim failed: \(error)")
            }
        }
    }
}
