import Foundation

/// A minimal STOMP-over-WebSocket client tailored for RabbitMQ.
/// Supports: CONNECT, SUBSCRIBE, SEND, heart-beats, auto-ack messages.
final class STOMPClient: NSObject, URLSessionWebSocketDelegate {
    struct Frame {
        let command: String
        let headers: [String: String]
        let body: Data?
    }

    // MARK: Public API
    var onConnected: (() -> Void)?
    var onDisconnected: ((Error?) -> Void)?
    var onMessage: (([String: String], Data?) -> Void)? // headers + body
    var onError: (([String: String]) -> Void)? // STOMP ERROR frame handler

    private(set) var isConnected = false

    // MARK: Config
    private let url: URL                      // e.g. wss://mq.example.com:15674/ws
    private let login: String                 // RabbitMQ username
    private let passcode: String              // RabbitMQ password
    private let vhost: String                 // RabbitMQ vhost ("/" if default)
    private let heartbeat: (client: Int, server: Int) // in ms

    // WS
    private var session: URLSession!
    private var ws: URLSessionWebSocketTask?
    private var hbTimer: Timer?
    private var connectionTimer: Timer?
    private var isClosing = false

    private func invalidateTimers() {
        hbTimer?.invalidate(); hbTimer = nil
        connectionTimer?.invalidate(); connectionTimer = nil
    }

    init(url: URL,
         login: String,
         passcode: String,
         vhost: String = "/",
         heartbeat: (client: Int, server: Int) = (10000, 10000)) {
        self.url = url
        self.login = login
        self.passcode = passcode
        self.vhost = vhost
        self.heartbeat = heartbeat
        super.init()

        let cfg = URLSessionConfiguration.default
        cfg.waitsForConnectivity = true
        // Set timeout intervals for WebSocket connections
        cfg.timeoutIntervalForRequest = 30.0  // 30 seconds for individual request timeout
        cfg.timeoutIntervalForResource = 120.0  // 120 seconds for WebSocket connection timeout

        session = URLSession(configuration: cfg, delegate: self, delegateQueue: .main)
    }

    // MARK: Connect / Disconnect
    func connect() {
        guard ws == nil else { return }
        debugLog("Connecting to WebSocket: \(url.absoluteString)")

        ws = session.webSocketTask(with: url, protocols: ["v12.stomp"])

        // Set up connection timeout
        connectionTimer?.invalidate()
        connectionTimer = Timer.scheduledTimer(withTimeInterval: 10, repeats: false) { [weak self] _ in
            guard let self = self, !self.isConnected else { return }
            self.closeAndNotify(NSError(domain: "STOMP", code: -1,
                                        userInfo: [NSLocalizedDescriptionKey: "Connection timeout"]))
        }
        ws?.resume()
    }

    func disconnect() {
        guard !isClosing else { return }
        isClosing = true
        invalidateTimers()
        isConnected = false

        // Send STOMP DISCONNECT frame for graceful close
        if ws != nil {
            sendFrame(command: "DISCONNECT", headers: ["receipt": "disconnect-receipt"], body: nil)
        }

        // Delay to ensure DISCONNECT frame sent before WebSocket close
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            guard let self = self else { return }
            self.ws?.cancel(with: .goingAway, reason: nil)
            self.ws = nil
            self.onDisconnected?(nil)
            self.isClosing = false
        }
    }

    private func closeAndNotify(_ error: Error?) {
        guard !isClosing else { return }
        isClosing = true
        invalidateTimers()
        isConnected = false
        ws?.cancel(with: .goingAway, reason: nil)
        ws = nil
        onDisconnected?(error)
        isClosing = false
    }

    // MARK: Subscribe / Send
    func subscribe(destination: String, id: String, ack: String = "auto") {
        sendFrame(command: "SUBSCRIBE", headers: [
            "id": id,
            "destination": destination,
            "ack": ack
        ], body: nil)
    }

    func sendJSON(to destination: String, headers extra: [String: String] = [:], json: Any) {
        guard let data = try? JSONSerialization.data(withJSONObject: json, options: []) else { return }
        var headers = ["destination": destination, "content-type": "application/json"]
        extra.forEach { headers[$0.key] = $0.value }
        sendFrame(command: "SEND", headers: headers, body: data)
    }

    // MARK: Internal: STOMP wire format
    private func sendConnect() {
        let headers = [
            "accept-version": "1.2",
            "host": vhost,
            "login": login,
            "passcode": passcode,
            "heart-beat": "\(heartbeat.client),\(heartbeat.server)"
        ]

        // debugLog("Sending STOMP CONNECT with headers: \(headers)")
        sendFrame(command: "CONNECT", headers: headers, body: nil)
    }

    private func sendFrame(command: String, headers: [String: String], body: Data?) {
        var lines: [String] = [command]
        for (k, v) in headers {
            lines.append("\(k):\(v)")
        }
        lines.append("") // blank line before body
        var frame = lines.joined(separator: "\n") + "\n"
        if let b = body, let bodyText = String(data: b, encoding: .utf8) {
            frame += bodyText
        }
        frame += "\u{0000}" // NUL terminator
//        debugLog("Raw STOMP frame:", frame.replacingOccurrences(of: "\u{0000}", with: "NULL")) 
        ws?.send(.string(frame)) { error in
            if let e = error {
                debugLog("STOMP send error:", e)
            } else {
                debugLog("STOMP \(command) sent successfully")
            }
        }
    }

    private func startHeartbeat() {
        hbTimer?.invalidate()
        hbTimer = Timer.scheduledTimer(withTimeInterval: TimeInterval(Double(heartbeat.client) / 1000.0),
                                       repeats: true) { [weak self] _ in
            // STOMP heart-beat is an LF (\n) frame with no command.
            self?.ws?.send(.string("\n")) { err in
                if let e = err { debugLog("STOMP heartbeat error:", e) }
            }
        }
    }

    private func listen() {
        ws?.receive { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .failure(let err):
                self.closeAndNotify(err)
            case .success(let msg):
                var data: Data?
                switch msg {
                case .string(let s): data = s.data(using: .utf8)
                case .data(let d):   data = d
                @unknown default:    data = nil
                }
                if let d = data { self.processFrames(buffer: d) }
                self.listen() // keep listening
            }
        }
    }

    private func processFrames(buffer: Data) {
        if isHeartbeat(buffer) { return }
        let frames = buffer.split(separator: 0)
        for raw in frames {
            guard let text = normalizeFrame(raw) else { continue }
            let frameData = parseFrame(text)
            guard let command = frameData.command else { continue }
            handleCommand(command, headers: frameData.headers, body: frameData.body)
        }
    }

    private func isHeartbeat(_ buffer: Data) -> Bool {
        return !buffer.isEmpty && buffer.allSatisfy({ $0 == 0x0A })
    }

    private func normalizeFrame(_ raw: Data) -> String? {
        guard var text = String(data: raw, encoding: .utf8) else { return nil }
        text = text.replacingOccurrences(of: "\r", with: "")
        if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return nil }
        return text
    }

    private struct FrameData {
        let command: String?
        let headers: [String: String]
        let body: Data?
    }

    private func parseFrame(_ text: String) -> FrameData {
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false)
        guard let firstLine = lines.first else { return FrameData(command: nil, headers: [:], body: nil) }
        let command = String(firstLine).trimmingCharacters(in: .whitespacesAndNewlines)
        var headers: [String: String] = [:]
        var bodyStartIndex = 1
        if lines.count > 1 {
            for i in 1..<lines.count {
                let line = lines[i]
                if line.isEmpty {
                    bodyStartIndex = i + 1
                    break
                }
                if let idx = line.firstIndex(of: ":") {
                    let key = String(line[..<idx])
                    let val = String(line[line.index(after: idx)...])
                    headers[key] = val
                }
            }
        }
        let bodyLines = lines.suffix(from: bodyStartIndex)
        let body = bodyLines.joined(separator: "\n").data(using: .utf8)
        return FrameData(command: command.isEmpty ? nil : command, headers: headers, body: body)
    }

    private func handleCommand(_ command: String, headers: [String: String], body: Data?) {
        switch command {
        case "CONNECTED":
            handleConnected()
        case "MESSAGE":
            handleMessage(headers: headers, body: body)
        case "RECEIPT":
            break
        case "ERROR":
            let msg = headers["message"] ?? "(no message)"
            errorLog(" STOMP ERROR: \(msg)")
            onError?(headers) // Notify manager to handle error (e.g., refresh credentials)
        default:
            debugLog("Received unknown STOMP command: \(command)")
        }
    }

    private func handleConnected() {
        debugLog("✅ STOMP CONNECTED received")
        connectionTimer?.invalidate()
        isConnected = true
        startHeartbeat()
        onConnected?()
    }

    private func handleMessage(headers: [String: String], body: Data?) {
        debugLog("📨 STOMP MESSAGE received")
        onMessage?(headers, body)
    }

    // MARK: URLSessionDelegate - SSL Certificate Validation
    // Forward SSL challenges to SSLPinningManager for proper validation
    func urlSession(_ session: URLSession,
                    didReceive challenge: URLAuthenticationChallenge,
                    completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        // Use SSLPinningManager for SSL validation (prevents MITM attacks)
        SSLPinningManager.shared.urlSession(
            session,
            didReceive: challenge,
            completionHandler: completionHandler
        )
    }

    // MARK: URLSessionWebSocketDelegate
    func urlSession(_ session: URLSession,
                    webSocketTask: URLSessionWebSocketTask,
                    didOpenWithProtocol protocol: String?) {
        debugLog("WebSocket connection opened successfully")
        sendConnect()
        listen()
    }

    func urlSession(_ session: URLSession,
                    webSocketTask: URLSessionWebSocketTask,
                    didCloseWith closeCode: URLSessionWebSocketTask.CloseCode,
                    reason: Data?) {
        closeAndNotify(nil)
    }

    // Handle connection errors
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error { closeAndNotify(error) }
    }
}
