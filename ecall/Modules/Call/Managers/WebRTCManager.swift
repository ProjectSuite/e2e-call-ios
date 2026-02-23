import Foundation
import WebRTC

@available(iOS 13.0, *)
class WebRTCManager: NSObject, ObservableObject {

    // Instead of static publisher/subscriber singletons, we manage roles via instances:
    static let publisher = WebRTCManager(role: .publisher)
    static let subscriber = WebRTCManager(role: .subscriber)
    enum Role { case publisher, subscriber }

    // Factory for peer connections (shared encoder/decoder)
    static let factory: RTCPeerConnectionFactory = {
        RTCInitializeSSL()
        let defaultEnc = RTCDefaultVideoEncoderFactory()
        let defaultDec = RTCDefaultVideoDecoderFactory()

        let e2eeEnc = CustomVideoEncoderFactory()
        let e2eeDec = CustomVideoDecoderFactory()

        let f = RTCPeerConnectionFactory.initWithEncoderFactoryE2EE(e2eeEnc, decoderFactory: e2eeDec) // e2ee all
        return f
    }()

    // Published tracks for UI binding
    @Published var localVideoTrack: RTCVideoTrack?
    @Published var remoteVideoTracks: [UInt64: RTCVideoTrack] = [:]  // feedId -> RTCVideoTracks
    @Published var connectionState: RTCPeerConnectionState = .new

    @Published var localAudioTrack: RTCAudioTrack?
    @Published var remoteAudioTracks: [UInt64: RTCAudioTrack] = [:]  // feedId -> RTCAudioTracks

    private var peerConnection: RTCPeerConnection?
    private var videoCapturer: RTCCameraVideoCapturer?
    private var videoSource: RTCVideoSource?
    var currentCameraPosition: AVCaptureDevice.Position = .front
    private let role: Role

    // For multi-participant, we could maintain a map of feed IDs to tracks (optional)
    private var subscriberStreams: [Int: RTCVideoTrack] = [:]  // feed ID -> track
    private var lastIceState: RTCIceConnectionState = .new

    // ICE Connection timeout handling
    private var iceConnectionTimeout: Timer?
    private let iceConnectionTimeoutInterval: TimeInterval = 5.0

    // ICE Candidate buffering timeout
    private var candidateBufferTimeout: Timer?
    private let maxCandidateBufferTime: TimeInterval = 5.0

    // RTCP Keepalive
    private var rtcpKeepaliveTimer: Timer?
    private let rtcpKeepaliveInterval: TimeInterval = 30.0  // 30 seconds
    private var keepaliveDataChannel: RTCDataChannel?

    init(role: Role) {
        self.role = role
        super.init()
    }

    // MARK: - ICE Server Configuration
    private func getIceServers() -> [RTCIceServer] {
        var iceServers: [RTCIceServer] = [
            RTCIceServer(urlStrings: ["stun:stun.l.google.com:19302"]),
            RTCIceServer(urlStrings: ["stun:stun1.l.google.com:19302"]), // Backup STUN
            RTCIceServer(urlStrings: ["stun:stun2.l.google.com:19302"])  // Additional backup
        ]

        if let cre = CredentialsService.shared.loadCredentials() {
            debugLog("🔑 Loading TURN credentials for ICE servers")
            iceServers.append(RTCIceServer(urlStrings: [cre.noneTlsUrl], username: cre.turnUsername, credential: cre.turnPassword))
            if let tlsUrl = cre.tlsUrl {
                iceServers.append(RTCIceServer(urlStrings: [tlsUrl], username: cre.turnUsername, credential: cre.turnPassword))
            }
        } else {
            debugLog("⚠️ No TURN credentials available, using STUN only")
        }

        return iceServers
    }

    // MARK: - PeerConnection Setup
    private func getRTCConfiguration() -> RTCConfiguration {
        let config = RTCConfiguration()
        config.sdpSemantics = .unifiedPlan
        config.bundlePolicy = .balanced
        config.rtcpMuxPolicy = .require
        config.continualGatheringPolicy = .gatherContinually
        config.iceTransportPolicy = .all  // STUN + TURN for WiFi

        return config
    }

    func setupPubPeerConnection() {
        let config = getRTCConfiguration()
        // Load TURN servers (if available) for robust NAT traversal
        // Use fetched TURN credentials if available, else fallback to default
        let iceServers = getIceServers()
        config.iceServers = iceServers

        let constraints = RTCMediaConstraints(mandatoryConstraints: nil, optionalConstraints: nil)
        peerConnection = WebRTCManager.factory.peerConnection(with: config, constraints: constraints, delegate: self)

        // Setup keepalive data channel
        setupKeepaliveDataChannel()

        // For a publisher, add media tracks
        if role == .publisher {
            addLocalMediaStreams()
        }
        // debugLog("✅ PeerConnection created for \(role == .publisher ? "publisher" : "subscriber")")
    }

    func setupSubPeerConnection() {
        let config = getRTCConfiguration()

        let iceServers = getIceServers()

        config.iceServers = iceServers

        let constraints = RTCMediaConstraints(mandatoryConstraints: nil, optionalConstraints: nil)
        peerConnection = WebRTCManager.factory.peerConnection(with: config, constraints: constraints, delegate: self)

        // Setup keepalive data channel
        setupKeepaliveDataChannel()
    }

    // MARK: - Local Media Management
    private func addLocalMediaStreams() {
        guard let pc = peerConnection else { return }

        // Add local audio track
        addLocalAudioTrack(to: pc)

        // Add local video track if video call
        if GroupCallSessionManager.shared.isVideoCall {
            addLocalVideoTrack(to: pc)
            startCaptureIfVideo()
        }
    }

    // MARK: - Audio Track Management
    private func addLocalAudioTrack(to peerConnection: RTCPeerConnection) {
        let audioTrack = createAudioTrack()
        peerConnection.add(audioTrack, streamIds: [AppConfig.schema])
        localAudioTrack = audioTrack
        localAudioTrack?.isEnabled = !(GroupCallSessionManager.shared.getCurrentParticipant()?.isMuted ?? false)
    }

    private func createAudioTrack() -> RTCAudioTrack {
        let audioSource = WebRTCManager.factory.audioSource(with: RTCMediaConstraints(mandatoryConstraints: nil, optionalConstraints: nil))
        let audioTrack = WebRTCManager.factory.audioTrack(with: audioSource, trackId: "audio0")
        audioTrack.isEnabled = true
        return audioTrack
    }

    // MARK: - Video Track Management
    private func addLocalVideoTrack(to peerConnection: RTCPeerConnection) {
        guard let videoTrack = createVideoTrack() else {
            errorLog("❌ Failed to create video track - video will not be available")
            return
        }
        peerConnection.add(videoTrack, streamIds: [AppConfig.schema])
        localVideoTrack = videoTrack
        localVideoTrack?.isEnabled = GroupCallSessionManager.shared.getCurrentParticipant()?.isVideoEnabled ?? true
    }

    // MARK: - Create and Configure Video Track
    private func createVideoTrack() -> RTCVideoTrack? {
        // Initialize the video source
        videoSource = WebRTCManager.factory.videoSource()
        guard let videoSource = videoSource else {
            errorLog("❌ [CRITICAL] Failed to initialize video source - video track creation failed")
            // Return nil instead of crashing - caller should handle this error
            return nil
        }

        // Initialize the video capturer with proper delegate
        // videoCapturer = RTCCameraVideoCapturer(delegate: self)
        videoCapturer = RTCCameraVideoCapturer(delegate: videoSource)

        // Create the video track using the video source
        let videoTrack = WebRTCManager.factory.videoTrack(with: videoSource, trackId: "video0")
        return videoTrack
    }

    // MARK: - Camera Capture Management
    func startCaptureIfVideo() {
        guard let capturer = videoCapturer else {
            errorLog(" Video capturer not initialized.")
            return
        }
        guard let captureDevice = getSelectedCameraDevice() else {
            errorLog(" No camera available.")
            return
        }

        // Try 720p first, else fall back to your original best-under-1080p picker
        let format = getBest480pFormat(for: captureDevice)
            ?? getBestFormat(for: captureDevice)

        let fps = getBestFPS(for: format)

        capturer.startCapture(with: captureDevice, format: format, fps: fps) { error in
            if let error = error {
                errorLog(" Camera capture start error: \(error)")
            } else {
                debugLog("✅ Camera capturing at \(CMVideoFormatDescriptionGetDimensions(format.formatDescription)) @\(fps)fps")
            }
        }
    }

    // MARK: - Camera Configuration
    private func getSelectedCameraDevice() -> AVCaptureDevice? {
        let frontCamera = RTCCameraVideoCapturer.captureDevices().first(where: { $0.position == .front })
        let backCamera = RTCCameraVideoCapturer.captureDevices().first(where: { $0.position == .back })
        return currentCameraPosition == .front ? frontCamera : backCamera
    }

    private func getBestFormat(for device: AVCaptureDevice) -> AVCaptureDevice.Format {
        // Pick the highest resolution ≤ 720p (or your target)
        let formats = device.formats
            .filter { format in
                let desc = format.formatDescription
                let dims = CMVideoFormatDescriptionGetDimensions(desc)
                return dims.width <= 1280 && dims.height <= 720
            }
            .sorted { a, b in
                let da = CMVideoFormatDescriptionGetDimensions(a.formatDescription)
                let db = CMVideoFormatDescriptionGetDimensions(b.formatDescription)
                return (da.width * da.height) > (db.width * db.height)
            }
        return formats.first ?? device.formats[0]
    }

    func getBest1080pFormat(for device: AVCaptureDevice) -> AVCaptureDevice.Format? {
        let maxWidth = 1920
        let maxHeight = 1080

        // Filter out any format larger than 1080p
        let candidates = device.formats.filter { format in
            let dims = CMVideoFormatDescriptionGetDimensions(format.formatDescription)
            return dims.width  <= maxWidth
                && dims.height <= maxHeight
        }

        // Pick the one with the largest area (width×height)
        return candidates.max { a, b in
            let da = CMVideoFormatDescriptionGetDimensions(a.formatDescription)
            let db = CMVideoFormatDescriptionGetDimensions(b.formatDescription)
            return (da.width * da.height) < (db.width * db.height)
        }
    }

    private func getBest480pFormat(for device: AVCaptureDevice) -> AVCaptureDevice.Format? {
        let maxWidth = 854
        let maxHeight = 480

        let candidates = device.formats.filter { format in
            let dims = CMVideoFormatDescriptionGetDimensions(format.formatDescription)
            return dims.width <= maxWidth && dims.height <= maxHeight
        }

        return candidates.max { a, b in
            let da = CMVideoFormatDescriptionGetDimensions(a.formatDescription)
            let db = CMVideoFormatDescriptionGetDimensions(b.formatDescription)
            return (da.width * da.height) < (db.width * db.height)
        }
    }

    private func getBestFPS(for format: AVCaptureDevice.Format) -> Int {
        let maxFPS = format.videoSupportedFrameRateRanges.first?.maxFrameRate ?? 10
        return min(Int(maxFPS), 10)
    }

    // MARK: - Toggle Camera (Front/Back)
    func toggleCamera(front: Bool) {
        currentCameraPosition = front ? .front : .back
        startCaptureIfVideo()
    }

    // MARK: - Offer/Answer Handling

    var pendingSubscriberOffer: RTCSessionDescription?

    func handleRemoteOffer(sdp: String) {
        guard let pc = peerConnection else {
            debugLog("Peer connection not set up yet. Setting up now.")
            setupSubPeerConnection()
            handleRemoteOffer(sdp: sdp)
            return
        }
        let offerDesc = RTCSessionDescription(type: .offer, sdp: sdp)
        pendingSubscriberOffer = offerDesc
        pc.setRemoteDescription(offerDesc) { _ in
            guard self.pendingSubscriberOffer != nil else {
                debugLog("No offer pending – skip answer.")
                return
            }

            // Drain buffered candidates now that remote description is set
            self.drainPendingCandidates()

            let constraints = RTCMediaConstraints(
                mandatoryConstraints: nil,
                optionalConstraints: nil)
            pc.answer(for: constraints) { answerSDP, error in
                if let error = error {
                    debugLog("Error creating answer: \(error)")
                    return
                }
                guard let answerSDP = answerSDP else { return }
                pc.setLocalDescription(answerSDP, completionHandler: { _ in
                    JanusSocketClient.shared.sendAnswer(sdp: answerSDP.sdp) { result in
                        if case .failure(let e) = result {
                            errorLog(" sendAnswer failed:", e)
                        }
                    }
                    // clear the pending flag, so subsequent sendAnswer() calls no-op
                    self.pendingSubscriberOffer = nil
                })
            }
        }
    }

    func handleRemoteAnswer(sdp: String) {
        // Called on caller side when Janus (or callee) returns an answer SDP
        guard let pc = peerConnection else { return }
        let answerDesc = RTCSessionDescription(type: .answer, sdp: sdp)
        pc.setRemoteDescription(answerDesc) { [weak self] error in
            if let error = error {
                errorLog(" Error setting remote answer SDP: \(error)")
            } else {
                debugLog("✅ Remote answer applied, peer connection established.")
                self?.drainPendingCandidates()
            }
        }
    }

    // MARK: - ICE Candidate Handling
    func addRemoteIceCandidate(candidate: RTCIceCandidate) {
        guard let pc = peerConnection else {
            bufferCandidate(candidate)
            return
        }
        // Only add if remote description is already set, otherwise queue it
        guard pc.remoteDescription != nil else {
            bufferCandidate(candidate)
            return
        }
        pc.add(candidate) { error in
            if let err = error {
                errorLog(" Failed to add ICE candidate: \(err.localizedDescription)")
            } else {
                //                debugLog("✅ Remote ICE candidate added.")
            }
        }
    }

    private var pendingCandidates: [RTCIceCandidate] = []
    private func bufferCandidate(_ candidate: RTCIceCandidate) {
        debugLog("ℹ️ Buffering ICE candidate until SDP is set.")
        pendingCandidates.append(candidate)

        // Only set timeout if we don't have one already
        if candidateBufferTimeout == nil {
            candidateBufferTimeout = Timer.scheduledTimer(withTimeInterval: maxCandidateBufferTime, repeats: false) { [weak self] _ in
                self?.flushBufferedCandidates()
            }
        }
    }

    private func drainPendingCandidates() {
        pendingCandidates.forEach { addRemoteIceCandidate(candidate: $0) }
        pendingCandidates.removeAll()
        candidateBufferTimeout?.invalidate()
        candidateBufferTimeout = nil
    }

    private func flushBufferedCandidates() {
        debugLog("⏰ Candidate buffer timeout - flushing \(pendingCandidates.count) candidates")

        // Only flush if we have remote description set
        guard let pc = peerConnection, pc.remoteDescription != nil else {
            debugLog("⚠️ Cannot flush candidates - no remote description set yet")
            return
        }

        drainPendingCandidates()
    }

    func resetConnection() {
        debugLog("ℹ️ Resetting \(role == .publisher ? "publisher" : "subscriber") connection.")

        // Stop keepalive
        stopRtcpKeepalive()

        // Cleanup timeouts
        iceConnectionTimeout?.invalidate()
        iceConnectionTimeout = nil
        candidateBufferTimeout?.invalidate()
        candidateBufferTimeout = nil

        videoCapturer?.stopCapture(completionHandler: nil)
        peerConnection?.close()
        peerConnection = nil
        self.localVideoTrack = nil
        // Remove all remote tracks and notify UI
        self.remoteVideoTracks.removeAll()
        pendingCandidates.removeAll()
    }

    func createPubOffer() {
        guard let pc = peerConnection else {
            debugLog("Peer connection not set up yet. Setting up now.")
            setupPubPeerConnection()
            createPubOffer()
            return
        }
        let constraints = RTCMediaConstraints(
            mandatoryConstraints: nil,
            optionalConstraints: nil)
        pc.offer(for: constraints) { sdp, error in
            if let error = error {
                debugLog("Error creating offer: \(error)")
                return
            }
            guard let sdp = sdp else { return }

            pc.setLocalDescription(sdp, completionHandler: { error in
                DispatchQueue.main.async {
                    // Now send SDP to Janus
                    if let error = error {
                        debugLog("Error setting local description: \(error)")
                    } else {
                        debugLog("Local description set. ICE gathering state: \(pc.iceGatheringState)")
                        JanusSocketClient.shared.sendOffer(sdp: sdp.sdp) { result in
                            if case .failure(let err) = result {
                                errorLog(" sendOffer failed:", err)
                            }
                            if case .success = result {
                                debugLog("✅ Offer sent to Janus successfully.")
                            }
                        }
                    }
                }
            })
        }
    }

    private func sendTrickle(_ candidate: RTCIceCandidate) {
        let dict: [String: Any] = [
            "candidate": candidate.sdp,
            "sdpMid": candidate.sdpMid ?? "",
            "sdpMLineIndex": candidate.sdpMLineIndex
        ]
        JanusSocketClient.shared.trickleSubscriber(dict) { _ in }
    }
}

// MARK: - RTCPeerConnectionDelegate

extension WebRTCManager: RTCPeerConnectionDelegate {
    func peerConnection(_ peerConnection: RTCPeerConnection, didChange stateChanged: RTCSignalingState) {}

    func peerConnection(_ pc: RTCPeerConnection, didChange newState: RTCPeerConnectionState) {
        debugLog("*** Current peer state: \(newState) - isSubscriber: \(self === WebRTCManager.subscriber)")

        DispatchQueue.main.async {
            if self === WebRTCManager.subscriber {
                self.connectionState = newState

                // Map WebRTC state to ParticipantStatus
                let participantStatus: ParticipantStatus? = {
                    switch newState {
                    case .connected:
                        return .connected
                    case .disconnected, .failed:
                        return nil
                    case .connecting, .new:
                        return nil // .accepted  // Connecting after accepting
                    case .closed:
                        return nil // .left
                    @unknown default:
                        return nil
                    }
                }()

                if let status = participantStatus {
                    GroupCallSessionManager.shared.updateMyConnectionStatus(status)
                }

                switch newState {
                case .new, .connecting, .disconnected, .failed:
                    GroupCallSessionManager.shared.callStatus = .connecting
                case .connected:
                    GroupCallSessionManager.shared.callStatus = .connected
                case .closed:
                    GroupCallSessionManager.shared.callStatus = .ended
                @unknown default:
                    debugLog("Unknown state: \(newState)")
                }
            }
        }
    }

    func peerConnection(_ peerConnection: RTCPeerConnection, didAdd stream: RTCMediaStream) {
    }

    // Unified Plan API: called when a new track is added via RTCRtpReceiver
    func peerConnection(_ pc: RTCPeerConnection,
                        didAdd receiver: RTCRtpReceiver,
                        streams: [RTCMediaStream]) {
        DispatchQueue.main.async {
            debugLog("✅ \(self === WebRTCManager.publisher ? "📤 publisher" : "📥 subscriber") didAdd Unified stream")
            let track = receiver.track
            // Get streamId as UInt64
            let streamId: UInt64
            if let firstStream = streams.first {
                // Try to extract feedId from stream
                if let extractedId = self.extractFeedIdFromStream(firstStream) {
                    streamId = extractedId
                } else {
                    debugLog("⚠️ Could not extract feedId from stream, using 0")
                    streamId = 0
                }
            } else {
                debugLog("⚠️ No stream provided, using 0")
                streamId = 0
            }
            // Extract feedId from receiver parameters or stream
            let extractedFeedId = self.extractFeedIdFromReceiver(receiver, streamId: streamId)
            debugLog("🔍 Final extracted feedId: \(extractedFeedId ?? 0)")

            let finalFeedId = extractedFeedId ?? streamId
            switch track {
            case let audio as RTCAudioTrack:
                debugLog("✅ didAdd audio track:", audio.trackId)
                // Store audio track with feedId as key
                if finalFeedId > 0 {
                    self.remoteAudioTracks[finalFeedId] = audio
                    debugLog("🎵 Stored audio track with feedId: \(finalFeedId), total tracks: \(self.remoteAudioTracks.count)")
                } else {
                    debugLog("⚠️ Invalid feedId (0), cannot store audio track")
                }
            case let video as RTCVideoTrack:
                debugLog("✅ didAdd video track:", video.trackId)
                // Store video track with feedId as key
                if finalFeedId > 0 {
                    self.remoteVideoTracks[finalFeedId] = video
                    debugLog("📹 Stored video track with feedId: \(finalFeedId), total tracks: \(self.remoteVideoTracks.count)")
                } else {
                    debugLog("⚠️ Invalid feedId (0), cannot store video track")
                }

            default:
                break
            }
            AudioSessionManager.shared.configureAudioSession()
        }
    }

    func peerConnection(_ peerConnection: RTCPeerConnection, didGenerate candidate: RTCIceCandidate) {
        // debugLog("🧊 Local ICE cand: \(candidate.sdp)")

        // Only send candidates if remote description is set
        let candDict: [String: Any] = [
            "candidate": candidate.sdp,
            "sdpMid": candidate.sdpMid ?? "",
            "sdpMLineIndex": candidate.sdpMLineIndex
        ]

        // 1) Is this the *publisher* connection?
        if peerConnection === WebRTCManager.publisher.peerConnection {
            JanusSocketClient.shared.tricklePublisher(candDict) { result in
                if case .failure(let err) = result {
                    errorLog(" publisher ICE trickle failed:", err)
                }
            }
        }
        // 2) Or is it the *subscriber* connection?
        else if peerConnection === WebRTCManager.subscriber.peerConnection {
            JanusSocketClient.shared.trickleSubscriber(candDict) { result in
                if case .failure(let err) = result {
                    errorLog("Subscriber ICE trickle failed:", err)
                }
            }
        } else {
            debugLog("⚠️ ICE from unknown connection:", candDict)
        }
    }

    func peerConnection(_ pc: RTCPeerConnection, didRemove receiver: RTCRtpReceiver) {
        // Unified Plan may call didRemove for individual tracks
        DispatchQueue.main.async {
            if let videoTrack = receiver.track as? RTCVideoTrack {
                // More robust removal by track ID and reference
                let trackId = videoTrack.trackId

                // Find and remove by track reference
                let feedIdsToRemove = self.remoteVideoTracks.filter { $0.value === videoTrack }.map { $0.key }

                // Also try to remove by trackId matching
                for (feedId, track) in self.remoteVideoTracks {
                    if track.trackId == trackId {
                        self.remoteVideoTracks.removeValue(forKey: feedId)
                        debugLog("🗑 Removed video track for feedId: \(feedId) by trackId match")
                    }
                }

                for feedId in feedIdsToRemove {
                    self.remoteVideoTracks.removeValue(forKey: feedId)
                    debugLog("🗑 Removed video track for feedId: \(feedId)")
                }

                debugLog("🗑 Remaining video tracks: \(self.remoteVideoTracks.count)")
            }
        }
    }

    func peerConnection(_ peerConnection: RTCPeerConnection, didRemove stream: RTCMediaStream) {
        DispatchQueue.main.async {
            // Extract feedId from stream
            if let feedId = self.extractFeedIdFromStream(stream) {
                if self.remoteVideoTracks.removeValue(forKey: feedId) != nil {
                    debugLog("🗑 Removed video track for feedId: \(feedId)")
                }
            }

            debugLog("🗑 Remote media stream removed. Remaining video tracks: \(self.remoteVideoTracks.count)")
        }
    }

    func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceConnectionState) {
        debugLog("*** 🧊 ICE connection state changed to: \(newState) - isSubscriber: \(self === WebRTCManager.subscriber)")

        // Cancel timeout if already connected
        if newState == .connected || newState == .completed {
            iceConnectionTimeout?.invalidate()
            iceConnectionTimeout = nil

            // ✅ Start RTCP keepalive when ICE connected
            startRtcpKeepalive()

            if lastIceState == .disconnected || lastIceState == .failed {
                // ▶️ Call-level reconnect sound
                SFXManager.shared.playReconnect()
            }
        }

        // Stop keepalive when disconnected
        if newState == .disconnected || newState == .failed {
            stopRtcpKeepalive()
        }

        // Set timeout for checking state
        if newState == .checking {
            iceConnectionTimeout?.invalidate()

            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.iceConnectionTimeout = Timer.scheduledTimer(withTimeInterval: self.iceConnectionTimeoutInterval, repeats: false) { [weak self] _ in
                    debugLog("⏰ ICE connection timeout triggered!")
                    self?.handleIceConnectionTimeout()
                }
            }
            debugLog("✅ ICE timeout timer created successfully")
        }

        // Handle ICE connection failure
        if newState == .failed {
            errorLog("ICE connection failed - attempting recovery")
            handleIceConnectionFailure()
        }

        lastIceState = newState
    }

    private func handleIceConnectionTimeout() {
        debugLog("⚠️ ICE connection timeout - attempting restart")

        // Unified approach: Always check pendingCandidates first
        if !pendingCandidates.isEmpty {
            debugLog("🔄 Flushing \(pendingCandidates.count) buffered candidates before restart")
            drainPendingCandidates()
        }

        // Network-aware delay (shorter for cellular)
        let delay = NetworkMonitor.shared.isCellular ? 0.5 : 1.0
        debugLog("⏱️ Using \(delay)s delay for \(NetworkMonitor.shared.isCellular ? "4G" : "WiFi")")

        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            self?.restartIceGathering()
        }
    }

    private func restartIceGathering() {
        guard let pc = peerConnection else { return }

        debugLog("🔄 Restarting ICE gathering...")
        // Force restart ICE gathering
        pc.restartIce()

        // Clear timeout
        iceConnectionTimeout?.invalidate()
        iceConnectionTimeout = nil
    }

    private func handleIceConnectionFailure() {
        debugLog("🔄 Attempting ICE connection recovery...")

        // First, try to flush any remaining buffered candidates
        if !pendingCandidates.isEmpty {
            debugLog("🔄 Flushing \(pendingCandidates.count) remaining candidates")
            drainPendingCandidates()
        }

        // Network-aware delay (shorter for cellular)
        let delay = NetworkMonitor.shared.isCellular ? 0.5 : 1.0
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            self?.restartIceGathering()
        }
    }

    func peerConnection(_ peerConnection: RTCPeerConnection, didOpen dataChannel: RTCDataChannel) {}

    func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceGatheringState) {
        if newState == .complete {
            // Send empty candidate to signal end-of-candidates
            // let endCand: [String:Any] = [:]
            // Signal end-of-candidates correctly
            let endCand: [String: Any] = ["completed": true]
            if peerConnection === WebRTCManager.publisher.peerConnection {
                JanusSocketClient.shared.tricklePublisher(endCand) { _ in }
            } else {
                JanusSocketClient.shared.trickleSubscriber(endCand) { _ in }
            }
        }
    }

    func peerConnection(_ peerConnection: RTCPeerConnection, didStartReceivingOn transceiver: RTCRtpTransceiver) {}

    func peerConnectionShouldNegotiate(_ peerConnection: RTCPeerConnection) {

    }

    func peerConnection(_ peerConnection: RTCPeerConnection, didRemove candidates: [RTCIceCandidate]) {}

    private func extractFeedIdFromReceiver(_ receiver: RTCRtpReceiver, streamId: UInt64) -> UInt64? {
        let trackId = receiver.track?.trackId ?? ""

        debugLog("🔍 Attempting to extract feedId from:")
        debugLog("  - streamId (UInt64): \(streamId)")
        debugLog("  - trackId: '\(trackId)'")
        debugLog("  - transactionId: '\(receiver.parameters.transactionId)'")
        debugLog("  - rtcp.cname: '\(receiver.parameters.rtcp.cname)'")

        // Method 1: Use streamId if it's valid
        if streamId > 0 {
            debugLog("✅ Using streamId as feedId: \(streamId)")
            return streamId
        }

        // Method 2: Try trackId
        if let feedId = extractFeedIdFromString(trackId) {
            debugLog("✅ Extracted feedId \(feedId) from trackId")
            return feedId
        }

        // Method 3: Try RTCP cname (Janus often puts feedId here)
        if let feedId = extractFeedIdFromString(receiver.parameters.rtcp.cname) {
            debugLog("✅ Extracted feedId \(feedId) from RTCP cname")
            return feedId
        }

        // Method 4: Try transaction ID
        if let feedId = extractFeedIdFromString(receiver.parameters.transactionId) {
            debugLog("✅ Extracted feedId \(feedId) from transactionId")
            return feedId
        }

        // Method 5: Check for rid in encodings
        let encodings = receiver.parameters.encodings
        for encoding in encodings {
            if let rid = encoding.rid,
               let feedId = UInt64(rid) {
                debugLog("✅ Extracted feedId \(feedId) from rid")
                return feedId
            }
        }

        debugLog("⚠️ Could not extract feedId from any source")
        return nil
    }

    private func extractFeedIdFromString(_ string: String) -> UInt64? {
        // Try direct parsing
        if let feedId = UInt64(string), feedId > 0 {
            return feedId
        }

        // Extract numbers from string pattern
        let numbers = string.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
        if let feedId = UInt64(numbers), feedId > 0 {
            return feedId
        }

        return nil
    }

    private func extractFeedIdFromStream(_ stream: RTCMediaStream) -> UInt64? {
        let streamId = stream.streamId

        // Try to parse streamId directly if it's numeric
        if let feedId = UInt64(streamId) {
            return feedId
        }

        // Try to extract numbers from string pattern like "janus12345" or "stream-12345"
        let numbers = streamId.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
        if let feedId = UInt64(numbers), feedId > 0 {
            return feedId
        }

        return nil
    }

    private func setupKeepaliveDataChannel() {
        guard let pc = peerConnection else { return }

        let config = RTCDataChannelConfiguration()
        config.isOrdered = true
        config.channelId = 99

        keepaliveDataChannel = pc.dataChannel(forLabel: "keepalive", configuration: config)
        keepaliveDataChannel?.delegate = self

        debugLog("✅ Keepalive data channel setup")
    }

    // MARK: - RTCP Keepalive Management

    private func startRtcpKeepalive() {
        guard rtcpKeepaliveTimer == nil else { return }

        rtcpKeepaliveTimer = Timer.scheduledTimer(
            withTimeInterval: rtcpKeepaliveInterval,
            repeats: true
        ) { [weak self] _ in
            self?.sendRtcpKeepalive()
        }

        debugLog("✅ RTCP keepalive started (interval: \(rtcpKeepaliveInterval)s)")
    }

    private func stopRtcpKeepalive() {
        rtcpKeepaliveTimer?.invalidate()
        rtcpKeepaliveTimer = nil
        debugLog("🛑 RTCP keepalive stopped")
    }

    private func sendRtcpKeepalive() {
        guard let pc = peerConnection else { return }

        let iceState = pc.iceConnectionState
        let connectionState = pc.connectionState

        // Only send if connected
        guard (iceState == .connected || iceState == .completed) &&
                connectionState == .connected else {
            debugLog("⚠️ Skip keepalive - not connected (ICE: \(iceState), Peer: \(connectionState))")
            return
        }

        // Send ping via data channel
        sendDataChannelPing()

        debugLog("💓 RTCP keepalive ping sent")
    }

    private func sendDataChannelPing() {
        guard let dataChannel = keepaliveDataChannel,
              dataChannel.readyState == .open else {
            return
        }

        let timestamp = Date().timeIntervalSince1970
        let message = "ping:\(timestamp)"
        let buffer = RTCDataBuffer(
            data: message.data(using: .utf8)!,
            isBinary: false
        )
        dataChannel.sendData(buffer)
    }

    func flipCamera() {
        guard let capturer = videoCapturer else { return }
        guard let currentDevice = capturer.captureSession.inputs.compactMap({ $0 as? AVCaptureDeviceInput }).first?.device else { return }

        let position: AVCaptureDevice.Position = (currentDevice.position == .front) ? .back : .front

        guard let newDevice = RTCCameraVideoCapturer.captureDevices().first(where: { $0.position == position }) else { return }

        let formats = RTCCameraVideoCapturer.supportedFormats(for: newDevice)
        guard let format = formats.first else { return }

        let fps = format.videoSupportedFrameRateRanges.first?.maxFrameRate ?? 30

        capturer.stopCapture {
            capturer.startCapture(with: newDevice, format: format, fps: Int(fps))
        }
    }
}

extension RTCPeerConnectionState: @retroactive CustomStringConvertible {
    public var description: String {
        switch self {
        case .new: return "🔹 New"
        case .connecting: return "🔹 Connecting"
        case .connected: return "✅ Connected"
        case .disconnected: return "❌ Disconnected"
        case .failed: return "❌ Failed"
        case .closed: return "❌ Closed"
        @unknown default: return "❌ Unknown"
        }
    }
}

extension RTCIceConnectionState: @retroactive CustomStringConvertible {
    public var description: String {
        switch self {
        case .new: return "Ice🔹 New"
        case .checking: return "Ice🔹 Checking"
        case .connected: return "Ice✅ Connected"
        case .disconnected: return "Ice❌ Disconnected"
        case .failed: return "Ice❌ Failed"
        case .closed: return "Ice❌ Closed"
        case .completed: return "Ice✅ Completed"
        case .count: return "Ice🔹 Count"
        @unknown default: return "Ice❌ Unknown"
        }
    }
}

// MARK: - RTCDataChannelDelegate

extension WebRTCManager: RTCDataChannelDelegate {
    func dataChannelDidChangeState(_ dataChannel: RTCDataChannel) {
        debugLog("📡 Data channel state: \(dataChannel.readyState.rawValue)")

        if dataChannel.readyState == .open {
            debugLog("✅ Data channel opened")
        } else if dataChannel.readyState == .closed {
            debugLog("🛑 Data channel closed")
        }
    }

    func dataChannel(_ dataChannel: RTCDataChannel, didReceiveMessageWith buffer: RTCDataBuffer) {
        if let message = String(data: buffer.data, encoding: .utf8) {
            if message.hasPrefix("ping:") {
                // Extract timestamp and respond with pong
                let timestamp = message.replacingOccurrences(of: "ping:", with: "")
                let pong = "pong:\(timestamp)"
                let responseBuffer = RTCDataBuffer(
                    data: pong.data(using: .utf8)!,
                    isBinary: false
                )
                dataChannel.sendData(responseBuffer)
                debugLog("💓 Keepalive pong sent")
            } else if message.hasPrefix("pong:") {
                // Calculate RTT
                let timestampStr = message.replacingOccurrences(of: "pong:", with: "")
                if let sentTime = Double(timestampStr) {
                    let rtt = (Date().timeIntervalSince1970 - sentTime) * 1000 // ms
                    debugLog("💓 Keepalive pong received (RTT: \(String(format: "%.2f", rtt))ms)")
                }
            }
        }
    }
}
