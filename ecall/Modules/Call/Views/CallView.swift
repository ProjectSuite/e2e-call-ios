import SwiftUI
import Combine
import AVFoundation

enum CallMode {
    case normal
    case busy
}

struct CallView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var publisherRtc = WebRTCManager.publisher
    @StateObject private var contactViewModel = ContactsViewModel()
    @ObservedObject private var session = GroupCallSessionManager.shared

    let callHandleName: String
    let callHandleId: UInt64
    let isVideo: Bool

    @State private var isMuted: Bool = false
    @State private var isCameraOn: Bool = true
    @State private var isSpeakerOn: Bool = false
    @State private var showInviteSheet: Bool = false
    @State private var showControls: Bool = true
    @State private var showKeySheet = false
    @State private var callMode: CallMode = .normal

    // Store user info for busy mode when participants are cleared
    @State private var busyUserName: String = ""
    @State private var busyUserId: UInt64 = 0

    // Recall button state management
    @State private var isRecallDisabled: Bool = false
    @State private var recallCountdown: Int = 0
    private let recallDisableDuration: Int = 3 // 3 seconds

    // Timer
    @State private var callStartDate = Date()
    @State private var callDuration: TimeInterval = 0
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    @State private var isFrontCamera: Bool = true

    @State private var micPermissionDenied: Bool = false
    @State private var cameraPermissionDenied: Bool = false
    @State private var permissionWarning: String?

    // Computed properties
    private var participants: [Participant] {
        session.participants.filter({$0.status == .connected})
    }

    private var isTwoPersonCall: Bool {
        participants.count <= 2
    }

    private var otherParticipant: Participant? {
        participants.first { !$0.isLocal }
    }

    private var isAvailableShowTimer: Bool {
        session.callStatus == .connected
    }

    // Participant status helpers
    private var filterInvitingParticipants: [Participant] { // case
        let allInviting = session.getInvitedParticipants()
        let otherParticipantId = otherParticipant?.userId ?? callHandleId

        // Filter out current user and otherParticipant (connected user)
        let filteredInviting = allInviting.filter { participant in
            !participant.isLocal && participant.userId != otherParticipantId
        }

        return filteredInviting
    }

    private var hasInvitingParticipants: Bool {
        !filterInvitingParticipants.isEmpty
    }

    private var hasRejectedParticipants: Bool {
        session.participantCount(withStatus: .rejected) > 0
    }

    // MARK: - Multi-person call properties
    private var participantNamesText: String {
        let otherParticipants = participants.filter { !$0.isLocal }
        if otherParticipants.isEmpty {
            return ""
        } else if otherParticipants.count == 1 {
            return otherParticipants[0].displayName
        } else if otherParticipants.count <= 2 {
            return "\(KeyLocalized.You), " + otherParticipants.map { $0.displayName }.joined(separator: ", ")
        } else {
            let firstTwo = otherParticipants.prefix(2).map { $0.displayName }.joined(separator: ", ")
            let remainingCount = otherParticipants.count - 2
            return "\(KeyLocalized.You), \(firstTwo) & \(remainingCount) \(KeyLocalized.other_participant)"
        }
    }

    private var timeString: String {
        AppUtils.getTimeDisplay(callDuration: Int(callDuration))
    }

    var body: some View {
        NavigationView {
            ZStack {
                // Background gradient
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.clear,
                        Color.cyan
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                Group {
                    if callMode == .busy {
                        // Busy mode UI
                        CallBusyModeView(
                            name: busyUserName.isEmpty ? callHandleName : busyUserName,
                            isRecallDisabled: isRecallDisabled,
                            recallCountdown: recallCountdown,
                            onDismiss: {
                                dismiss()
                            },
                            onRecall: {
                                recallCall()
                            }
                        )
                    } else {
                        // Normal call mode
                        if isTwoPersonCall {
                            // Two person call (audio or video)
                            TwoPersonCallView(
                                isVideoCall: isVideo,
                                participantName: otherParticipant?.displayName ?? callHandleName,
                                callStatus: session.callStatus,
                                callDuration: callDuration,
                                isMuted: otherParticipant?.isMuted ?? false,
                                isVideoEnabled: otherParticipant?.isVideoEnabled ?? true,
                                isCameraOn: isVideo ? isCameraOn : nil,
                                isFrontCamera: isVideo ? isFrontCamera : nil,
                                isSpeakerOn: isVideo ? nil : isSpeakerOn,
                                feedId: otherParticipant?.feedId  // Pass the last feedId to get the correct video track when rejoining.
                            )
                        } else {
                            // Multi-person call
                            if isVideo {
                                MultiPersonVideoView(
                                    participants: participants,
                                    callStatus: session.callStatus,
                                    callDuration: callDuration,
                                    isMuted: isMuted
                                )
                                .padding(.top, 40) // under Inviting text
                            } else {
                                MultiPersonAudioView(
                                    participants: participants,
                                    callStatus: session.callStatus,
                                    callDuration: callDuration,
                                    isMuted: isMuted,
                                    isSpeakerOn: isSpeakerOn
                                )
                                .padding(.top, 40) // under Inviting text
                            }
                        }
                    }
                }

                // Inviting text at top-left corner
                if hasInvitingParticipants {
                    VStack {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                let names = filterInvitingParticipants.compactMap({$0.effectiveDisplayName}).joined(separator: ", ")

                                (
                                    Text(KeyLocalized.inviting + " ")
                                        .foregroundColor(Color.white.opacity(0.7))
                                        + Text(names)
                                        .underline()
                                        .foregroundColor(.white)
                                )
                                .font(.body)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(.ultraThinMaterial)
                                .background(Color.black.opacity(0.4))
                                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            }
                            Spacer()
                        }
                        .padding(.leading, 12)
                        .padding(.top, 6)
                        Spacer()
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                if callMode != .busy {
                    CallControlsView(
                        isMuted: $isMuted,
                        isCameraOn: $isCameraOn,
                        isSpeakerOn: $isSpeakerOn,
                        isVideoCall: isVideo,
                        onToggleMute: { newVal in
                            if micPermissionDenied {
                                showPermissionWarning(for: .microphone)
                                isMuted.toggle() // revert UI toggle
                                return
                            }
                            isMuted = newVal
                            GroupCallSessionManager.shared.updateMuteState(newVal)
                        },
                        onToggleCamera: { newVal in
                            if cameraPermissionDenied {
                                showPermissionWarning(for: .camera)
                                isCameraOn.toggle() // revert UI toggle
                                return
                            }
                            isCameraOn = newVal
                            toggleCamera()
                            GroupCallSessionManager.shared.updateVideoEnabledState(newVal)
                        },
                        onToggleSpeaker: { newVal in
                            isSpeakerOn = newVal
                        },
                        onEndCall: {
                            endCall()
                        },
                        onFlipCamera: {
                            toggleCamera()
                        }
                    )
                }
            }
            .toolbar {
                // Left side - Title for multiple participants
                if (!isTwoPersonCall || isTwoPersonCall && isVideo) && isAvailableShowTimer {
                    ToolbarItem(placement: .navigationBarLeading) {
                        VStack(alignment: .leading, spacing: 2) {
                            let displayTitle: String = {
                                let maxChars = 25
                                if participantNamesText.count > maxChars {
                                    return String(participantNamesText.prefix(maxChars)) + "…"
                                }
                                return participantNamesText
                            }()
                            Text(displayTitle)
                                .font(.subheadline.weight(.medium))
                                .foregroundColor(.black)
                                .lineLimit(1)
                                .fixedSize(horizontal: true, vertical: false)
                                .padding(.horizontal, 6)
                            // Show timer when connected, or participant status when inviting/rejected
                            if isAvailableShowTimer {
                                Text(timeString)
                                    .font(.footnote)
                                    .foregroundColor(.gray)
                                    .lineLimit(1)
                                    .fixedSize(horizontal: true, vertical: false)
                                    .padding(.horizontal, 6)
                            }
                        }
                    }
                }

                // Right side - Action buttons
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 12) {
                        // Key button
                        Button(action: { showKeySheet = true }, label: {
                            Image(systemName: "key.fill")
                                .foregroundColor(.blue)
                        })

                        // Add friend button
                        Button(action: { showInviteSheet = true }, label: {
                            Image(systemName: "person.crop.circle.badge.plus")
                                .foregroundColor(.blue)
                        })
                    }
                }
            }
            .sheet(isPresented: $showKeySheet) {
                KeyManagerSheetView(isPresented: $showKeySheet)
                    .presentationDetents([.medium, .fraction(0.45)])
            }
            .sheet(isPresented: $showInviteSheet) {
                SelectContactListView(isPresented: $showInviteSheet, contacts: contactViewModel.contacts)
            }
            .onReceive(NotificationCenter.default.publisher(for: .callDidEnd)) { _ in
                if callMode != .busy {
                    session.callStatus = .ended
                    dismiss()
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .callUserBusy)) { _ in
                // Store current user info before switching to busy mode
                if let otherParticipant = otherParticipant {
                    busyUserName = otherParticipant.displayName
                    busyUserId = otherParticipant.userId
                } else {
                    busyUserName = callHandleName
                    busyUserId = callHandleId
                }
                callMode = .busy
            }
            .onChange(of: session.callStatus) { callStatus in
                if callStatus == .connecting {
                    SFXManager.shared.playReconnect()
                }
                if callStatus == .connected {
                    if callDuration == 0 {
                        callStartDate = Date()
                    }
                    SFXManager.shared.stop()
                }
            }
            .onReceive(timer) { _ in
                if isAvailableShowTimer {
                    callDuration = Date().timeIntervalSince(callStartDate)
                }

                // Handle recall countdown
                if isRecallDisabled && recallCountdown > 0 {
                    recallCountdown -= 1
                    if recallCountdown <= 0 {
                        isRecallDisabled = false
                    }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .participantRejected)) { note in
                if let name = note.userInfo?["participantName"] as? String {
                    ToastManager.shared.warning(String(format: KeyLocalized.user_rejected_desc, name), position: .bottom, offset: 100, duration: 4)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .participantLeft)) { note in
                if let name = note.userInfo?["participantName"] as? String {
                    ToastManager.shared.warning(String(format: KeyLocalized.user_left_desc, name), position: .bottom, offset: 100)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .participantJoined)) { note in
                if let name = note.userInfo?["participantName"] as? String {
                    ToastManager.shared.info(String(format: KeyLocalized.user_joined_desc, name), position: .bottom, offset: 100)
                }
                // Sync audio track with current mute state when participant joins
                // Delay slightly to ensure audio track has been re-setup
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    publisherRtc.localAudioTrack?.isEnabled = !isMuted
                }
            }
            .onAppear {
                contactViewModel.loadContacts()
                if callDuration == 0 {
                    callStartDate = Date()
                }
                AudioSessionManager.shared.setKeepScreenOn(true)
                Task { await refreshPermissions() }
            }
            .onDisappear {
                AudioSessionManager.shared.setKeepScreenOn(false)
            }
            .onChange(of: isMuted) { newValue in
                publisherRtc.localAudioTrack?.isEnabled = !newValue
            }
            .onChange(of: isCameraOn) { publisherRtc.localVideoTrack?.isEnabled = $0 }
            .onChange(of: publisherRtc.localAudioTrack) { newTrack in
                // When the audio track is recreated, sync with the current mute state
                if let track = newTrack {
                    track.isEnabled = !isMuted
                }
            }
            .overlay(alignment: .bottom) {
                if let permissionWarning {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.yellow)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(permissionWarning)
                                .font(.footnote.weight(.semibold))
                                .foregroundColor(.white)
                            Button(KeyLocalized.permissions_open_settings_button) {
                                PermissionsService.shared.openSystemSettings()
                            }
                            .font(.footnote.weight(.semibold))
                            .foregroundColor(.cyan)
                        }
                        Spacer()
                    }
                    .padding()
                    .background(Color.black.opacity(0.6))
                    .cornerRadius(14)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 120)
                }
            }
        }
        .logViewName()
    }

    // MARK: - Helper Functions

    private func toggleCamera() {
        isFrontCamera.toggle()
        publisherRtc.toggleCamera(front: isFrontCamera)
    }

    private func endCall() {
        GroupCallManager.shared.endCall()
        dismiss()
    }

    private func recallCall() {
        // Prevent spam by disabling button for 3 seconds
        isRecallDisabled = true
        recallCountdown = recallDisableDuration

        callMode = .normal
        // Use stored user info if available, otherwise use original values
        let userName = busyUserName.isEmpty ? callHandleName : busyUserName
        let userId = busyUserId == 0 ? callHandleId : busyUserId
        GroupCallManager.shared.startCall(to: [userName], calleeIDs: [userId], isVideo: isVideo)
    }

    private func refreshPermissions() async {
        let mic = await PermissionsService.shared.status(for: .microphone)
        let cam = await PermissionsService.shared.status(for: .camera)
        await MainActor.run {
            micPermissionDenied = mic == .denied
            cameraPermissionDenied = cam == .denied
            updatePermissionWarning()
        }
    }

    private func showPermissionWarning(for type: PermissionType) {
        switch type {
        case .microphone:
            permissionWarning = String(format: "%@ - %@", KeyLocalized.permissions_microphone_title, KeyLocalized.permissions_info_body)
        case .camera:
            permissionWarning = String(format: "%@ - %@", KeyLocalized.permissions_camera_title, KeyLocalized.permissions_info_body)
        case .notifications, .photos:
            break
        }
    }

    private func updatePermissionWarning() {
        var parts: [String] = []
        if micPermissionDenied { parts.append(KeyLocalized.permissions_microphone_title) }
        if cameraPermissionDenied { parts.append(KeyLocalized.permissions_camera_title) }
        if parts.isEmpty {
            permissionWarning = nil
        } else {
            let joined = parts.joined(separator: " & ")
            permissionWarning = String(format: "%@ - %@", joined, KeyLocalized.permissions_info_body)
        }
    }
}
