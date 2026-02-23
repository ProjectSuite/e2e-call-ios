import Foundation

// MARK: - Connection State Machine
enum ConnectionState: Equatable, CustomStringConvertible {
    case idle
    case connecting(deviceID: String)
    case connected(deviceID: String)
    case disconnecting(pendingReconnect: String?)
    case refreshing(reason: String)
    case waitingToReconnect

    var isConnected: Bool {
        if case .connected = self { return true }
        return false
    }

    var isBusy: Bool {
        switch self {
        case .idle, .connected, .waitingToReconnect: return false
        default: return true
        }
    }

    var deviceID: String? {
        switch self {
        case .connecting(let id), .connected(let id): return id
        case .disconnecting(let pending): return pending
        default: return nil
        }
    }

    var description: String {
        switch self {
        case .idle: return "idle"
        case .connecting(let id): return "connecting(\(id))"
        case .connected(let id): return "connected(\(id))"
        case .disconnecting(let pending): return "disconnecting(pending:\(pending ?? "none"))"
        case .refreshing(let reason): return "refreshing(\(reason))"
        case .waitingToReconnect: return "waitingToReconnect"
        }
    }
}

// MARK: - STOMP Signaling Manager
final class StompSignalingManager {
    static let shared = StompSignalingManager()

    private var client: STOMPClient?

    // Single source of truth for connection state
    private let stateQueue = DispatchQueue(label: "com.app.stomp.state")
    private var _state: ConnectionState = .idle

    private var state: ConnectionState {
        get { stateQueue.sync { _state } }
        set {
            stateQueue.sync {
                let old = _state
                _state = newValue
                debugLog("🔄 State: \(old) → \(newValue)")
            }
        }
    }

    private var allowAutoReconnect = true
    weak var signalingDelegate: SignalingDelegate?

    // Token management
    private var tokenExpiresAt: Date?
    private var tokenRefreshTimer: Timer?

    // Config
    private let stompURL: URL = {
        let urlString = APIEndpoint.wss.fullSocketURL.absoluteString
        guard let url = URL(string: urlString) else {
            errorLog("❌ [CRITICAL] Invalid STOMP URL: \(urlString)")
            return URL(string: "wss://example.com/ws/")!
        }
        return url
    }()
    private var passcode = ""

    // Public computed
    var isConnected: Bool { state.isConnected }

    /// Called when app comes to foreground. Verifies connection and credentials.
    func verifyConnectionOnForeground() {
        guard allowAutoReconnect else { return }
        guard validDeviceId() != nil, KeyStorage.shared.readAccessToken() != nil else { return }

        // If not connected, attempt to reconnect
        if !isConnected && !state.isBusy {
            debugLog("🔄 App foreground: STOMP disconnected, reconnecting...")
            connect(force: true)
            return
        }

        // Check if token is expiring soon (within 60 seconds)
        if let expiresAt = tokenExpiresAt {
            let ttl = expiresAt.timeIntervalSince(Date())
            if ttl < 60 {
                debugLog("🔄 App foreground: Token expiring soon (ttl=\(Int(ttl))s), refreshing...")
                refreshCredentialsAndReconnect(reason: "foreground_expiry_check")
            }
        }
    }

    // MARK: - Helpers
    private func validDeviceId(_ s: String? = nil) -> String? {
        let id = s ?? KeyStorage.shared.readDeviceId()
        guard let trimmed = id?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty, trimmed != "0" else { return nil }
        return trimmed
    }

    // MARK: - Connect / Disconnect
    @discardableResult
    func connectIfReady(force: Bool = false) -> Bool {
        guard allowAutoReconnect else { return false }
        guard validDeviceId() != nil, KeyStorage.shared.readAccessToken() != nil else { return false }
        connect(force: force)
        return true
    }

    // MARK: - Sending
    func send(_ message: SignalMessage) {
        guard let c = client, state.isConnected else { return }

        var headers: [String: String] = [:]
        if let token = KeyStorage.shared.readAccessToken() {
            headers["authorization"] = "Bearer \(token)"
        }

        guard let data = try? JSONEncoder().encode(message),
              let obj = try? JSONSerialization.jsonObject(with: data) else { return }
        
        successLog("📦 Send signal: \(message.type) -- message: \(message)")

        c.sendJSON(to: "/exchange/ecall.signal.in", headers: headers, json: obj)
    }
    
    func connect(force: Bool = false) {
        guard let deviceID = validDeviceId() else {
            debugLog("⚠️ STOMP connect skipped: no valid deviceId")
            return
        }

        switch state {
        case .connected where !force:
            return // Already connected, no force requested
        case .connected, .connecting:
            // Force reconnect: disconnect first
            state = .disconnecting(pendingReconnect: deviceID)
            client?.disconnect()
        case .idle, .waitingToReconnect:
            doConnect(deviceID: deviceID)
        default:
            debugLog("⏳ Busy (\(state)), skip connect")
        }
    }

    // MARK: - Session Lifecycle
    func onLogout() {
        allowAutoReconnect = false
        tokenRefreshTimer?.invalidate()
        tokenRefreshTimer = nil
        tokenExpiresAt = nil
        state = .disconnecting(pendingReconnect: nil)
        client?.disconnect()
        client = nil
        state = .idle
    }

    func onLoginCompleted(deviceId: String?) {
        if let id = validDeviceId(deviceId) { KeyStorage.shared.saveDeviceId(id) }
        guard validDeviceId() != nil, KeyStorage.shared.readAccessToken() != nil else {
            debugLog("⚠️ Defer STOMP connect: deviceId/token not ready")
            return
        }
        allowAutoReconnect = true

        // Fetch RabbitMQ credentials first, then connect
        // This ensures credentials are available on first login
        CredentialsService.shared.fetchCredentials { [weak self] in
            self?.connect(force: true)
        }
    }

    func reset() {
        tokenRefreshTimer?.invalidate()
        tokenRefreshTimer = nil
        tokenExpiresAt = nil
        client?.disconnect()
        client = nil
        state = .idle
    }
    
    func disconnect() {
        allowAutoReconnect = false
        state = .disconnecting(pendingReconnect: nil)
        client?.disconnect()
        client = nil
        state = .idle
    }

    // MARK: - Private func
    
    private func doConnect(deviceID: String) {
        // Ensure RabbitMQ token is available before attempting STOMP CONNECT.
        // On fresh devices right after first login, credentials may not be cached yet.
        if !ensureRabbitMQTokenThenConnect(deviceID: deviceID) {
            return
        }

        startConnection(deviceID: deviceID)
    }

    private func startConnection(deviceID: String) {
        state = .connecting(deviceID: deviceID)
        let c = STOMPClient(url: stompURL, login: "device-\(deviceID)", passcode: passcode, vhost: "ecall")
        client = c
        setupCallbacks(client: c)
        c.connect()
    }

    // MARK: - Credentials

    /// Validates that RabbitMQ credentials are available and not expired.
    /// If credentials are missing or expired, fetches new ones and triggers connect afterwards.
    /// Returns true if credentials are valid and ready, false if async fetch is in progress.
    private func ensureRabbitMQTokenThenConnect(deviceID: String) -> Bool {
        guard let cre = CredentialsService.shared.loadCredentials() else {
            debugLog("⚠️ No cached RabbitMQ credentials, fetching...")
            fetchCredentialsAndConnect(deviceID: deviceID)
            return false
        }

        // Check if token exists and is not expired
        if let token = cre.rabbitmqToken, !token.isEmpty {
            if let expiresAt = cre.rabbitmqTokenExpiresAt {
                let expiry = Date(timeIntervalSince1970: expiresAt)
                if expiry <= Date() {
                    debugLog("⚠️ RabbitMQ token expired, refreshing...")
                    fetchCredentialsAndConnect(deviceID: deviceID)
                    return false
                }
            }
            // Token is valid
            loadCredentials()
            return true
        }

        // Fallback to password-based auth
        if let password = cre.rabbitmqPassword, !password.isEmpty {
            loadCredentials()
            return true
        }

        // No valid credentials found
        debugLog("⚠️ Empty RabbitMQ credentials, fetching...")
        fetchCredentialsAndConnect(deviceID: deviceID)
        return false
    }

    /// Fetches credentials async and connects when ready
    private func fetchCredentialsAndConnect(deviceID: String) {
        state = .refreshing(reason: "missing_credentials")
        CredentialsService.shared.fetchCredentials { [weak self] in
            guard let self = self else { return }
            self.loadCredentials()

            // Validate credentials were actually fetched
            if self.passcode.isEmpty {
                errorLog("❌ Failed to fetch RabbitMQ credentials, will retry...")
                self.state = .waitingToReconnect
                DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in
                    guard let self = self, self.allowAutoReconnect else { return }
                    self.connect()
                }
                return
            }

            // Credentials ready, proceed with connection
            self.startConnection(deviceID: deviceID)
        }
    }

    private func loadCredentials() {
        guard let cre = CredentialsService.shared.loadCredentials() else { return }

        if let token = cre.rabbitmqToken {
            passcode = token
            if let expiresAt = cre.rabbitmqTokenExpiresAt {
                tokenExpiresAt = Date(timeIntervalSince1970: expiresAt)
                scheduleTokenRefresh()
            }
        } else {
            passcode = cre.rabbitmqPassword ?? ""
            tokenExpiresAt = nil
        }
    }

    private func scheduleTokenRefresh() {
        tokenRefreshTimer?.invalidate()
        guard let expiresAt = tokenExpiresAt else { return }

        let ttl = expiresAt.timeIntervalSince(Date())
        guard ttl > 0 else {
            refreshCredentialsAndReconnect(reason: "expired")
            return
        }

        let buffer = max(15.0, min(60.0, ttl * 0.10))
        let delay = expiresAt.addingTimeInterval(-buffer).timeIntervalSince(Date())

        guard delay > 1 else {
            refreshCredentialsAndReconnect(reason: "expiring_soon")
            return
        }

        debugLog("📅 Token refresh in \(Int(delay))s (ttl=\(Int(ttl))s)")
        tokenRefreshTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            self?.refreshCredentialsAndReconnect(reason: "timer")
        }
    }

    private func refreshCredentialsAndReconnect(reason: String) {
        guard !state.isBusy else {
            debugLog("ℹ️ Skip refresh (busy), reason=\(reason)")
            return
        }

        guard let deviceID = validDeviceId() else {
            debugLog("⚠️ No valid deviceId for refresh")
            return
        }

        state = .refreshing(reason: reason)
        debugLog("🔄 Refreshing credentials... reason=\(reason)")

        CredentialsService.shared.fetchCredentials { [weak self] in
            guard let self = self else { return }
            self.loadCredentials()
            self.state = .disconnecting(pendingReconnect: deviceID)
            self.tokenRefreshTimer?.invalidate()
            self.client?.disconnect()
        }
    }

    // MARK: - Callbacks
    private func setupCallbacks(client: STOMPClient) {
        client.onConnected = { [weak self] in self?.handleConnected(client: client) }
        client.onDisconnected = { [weak self] error in self?.handleDisconnected(error: error) }
        client.onMessage = { [weak self] _, body in self?.handleMessage(body: body) }
        client.onError = { [weak self] headers in self?.handleError(headers: headers) }
    }

    private func handleConnected(client: STOMPClient) {
        guard case .connecting(let deviceID) = state else { return }
        state = .connected(deviceID: deviceID)
        debugLog("✅ STOMP Connected - DeviceID: \(deviceID)")
        client.subscribe(destination: "/exchange/ecall.signal.out/\(deviceID)", id: "sub-\(deviceID)", ack: "auto")
    }

    private func handleDisconnected(error: Error? = nil) {
        let previousState = state
        client = nil

        if let error = error {
            errorLog("STOMP disconnected: \(error.localizedDescription)")
        }

        if case .connecting = previousState {
            debugLog("⚠️ Disconnected while connecting, refreshing credentials...")
            refreshCredentialsAndReconnect(reason: "disconnect_while_connecting")
            return
        }

        // Check for pending reconnect
        if case .disconnecting(let pending) = previousState, let deviceID = pending {
            doConnect(deviceID: deviceID)
            return
        }

        // Auto-reconnect if allowed
        if allowAutoReconnect {
            state = .waitingToReconnect
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in
                guard let self = self, self.allowAutoReconnect else { return }
                self.connect()
            }
        } else {
            state = .idle
        }
    }

    private func handleMessage(body: Data?) {
        guard let data = body else { return }
        do {
            let msg = try JSONDecoder().decode(SignalMessage.self, from: data)
            signalingDelegate?.didReceiveSignal(msg)
        } catch {
            debugLog("STOMP decode error:", error)
        }
    }

    private func handleError(headers: [String: String]) {
        let message = headers["message"] ?? ""
        errorLog("STOMP ERROR: \(message)")
        if message.contains("Bad CONNECT") {
            refreshCredentialsAndReconnect(reason: "bad_connect")
        }
    }
}
