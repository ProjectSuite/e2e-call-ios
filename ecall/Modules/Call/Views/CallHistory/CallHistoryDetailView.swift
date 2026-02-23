import SwiftUI

struct CallHistoryDetailView: View {
    let call: CallRecord

    @EnvironmentObject var languageManager: LanguageManager
    @ObservedObject var contactsViewModel: ContactsViewModel
    @State private var isJoiningActiveCall = false

    private var isGroup: Bool {
        call.callCategory == .group
    }

    var participants: [Participant] {
        call.availableParticipants
    }

    private var participantsExcludingCurrent: [Participant] {
        let currentUserId = UInt64(KeyStorage.shared.readUserId() ?? "0") ?? 0
        return participants.filter { $0.userId != currentUserId }
    }

    private var callMediaType: CallMediaType {
        call.callMediaType ?? .defaultCase
    }

    private var headerTitle: String {
        if isGroup {
            return String(format: "%@ (%d)", KeyLocalized.group_call, participants.count + 1)
        } else {
            return CallUtils.formatParticipantsDisplayNames(participants, maxCharactersPerName: 0)
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                headerSection

                actionBar

                historySection

                if isGroup {
                    participantsSection
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 20)
        }
        .background(Color(.systemGroupedBackground))
        .navigationBarTitleDisplayMode(.inline)
        .onReceive(NotificationCenter.default.publisher(for: .callDidEnd)) { _ in
            if call.status == .active {
                isJoiningActiveCall = false
            }
        }
        .logViewName()
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 12) {
            if isGroup {
                Image(systemName: "person.2.circle.fill")
                    .resizable()
                    .frame(width: 84, height: 84)
                    .foregroundColor(.gray.opacity(0.8))
            } else {
                SmartAvatarView(
                    url: nil,
                    name: CallUtils.formatParticipantsDisplayNames(participants, maxCharactersPerName: 0),
                    size: 84
                )
            }

            Text(headerTitle)
                .font(.title2).bold()
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Actions

    @ViewBuilder
    private var actionBar: some View {
        if call.status == .active {
            activeCallButton
        } else if isGroup {
            // Group call: only show buttons if at least one participant is a friend
            let hasAnyFriend = participantsExcludingCurrent.contains { isFriend(userId: $0.userId) }

            if hasAnyFriend {
                HStack(spacing: 12) {
                    Button {
                        startCall(isVideo: false)
                    } label: {
                        HStack {
                            CallMediaType.audio.icon
                            Text(KeyLocalized.call_all)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(PrimaryCapsuleButtonStyle())

                    Button {
                        startCall(isVideo: true)
                    } label: {
                        HStack {
                            CallMediaType.video.icon
                            Text(KeyLocalized.video_all)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(SecondaryCapsuleButtonStyle())
                }
            } else {
                // No friends in group: hide all buttons
                EmptyView()
            }
        } else {
            // Personal call: check if friend
            let currentUserId = UInt64(KeyStorage.shared.readUserId() ?? "0") ?? 0
            let otherParticipant = participants.first { $0.userId != currentUserId }
            let isFriendParticipant = otherParticipant.map { isFriend(userId: $0.userId) } ?? false

            if isFriendParticipant {
                // Friend: show audio/video buttons
                HStack(spacing: 12) {
                    Button {
                        startCall(isVideo: false)
                    } label: {
                        HStack {
                            CallMediaType.audio.icon
                            Text(KeyLocalized.audio_call)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(PrimaryCapsuleButtonStyle())

                    Button {
                        startCall(isVideo: true)
                    } label: {
                        HStack {
                            CallMediaType.video.icon
                            Text(KeyLocalized.video_call)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(SecondaryCapsuleButtonStyle())
                }
            } else if let participant = otherParticipant {
                // Not friend: show Add Friend button
                Button {
                    sendFriendRequest(to: participant.userId)
                } label: {
                    Text(KeyLocalized.add_friend_button)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
            } else {
                // Fallback: no participant found
                EmptyView()
            }
        }
    }

    private var activeCallButton: some View {
        Button {
            joinActiveCall()
        } label: {
            HStack(spacing: 8) {
                callMediaType.icon
                    .font(.headline)
                Text(KeyLocalized.join)
                    .font(.headline)
                    .fontWeight(.semibold)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
        }
        .background(Color.green)
        .cornerRadius(12)
        .opacity(isJoiningActiveCall ? 0.7 : 1.0)
        .disabled(isJoiningActiveCall)
    }

    // MARK: - Participants (Group only)

    private var participantsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(String(format: "%@ (%d)", KeyLocalized.participants, participants.count))
                .font(.headline)

            VStack(spacing: 0) {
                ForEach(Array(participantsExcludingCurrent.enumerated()), id: \.1.userId) { index, p in
                    participantRow(p)

                    if index < participantsExcludingCurrent.count - 1 {
                        Divider().padding(.leading, 56)
                    }
                }
            }
            .padding(12)
            .background(Color(.systemBackground))
            .cornerRadius(16)
            .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 4)
        }
    }

    private func participantRow(_ p: Participant) -> some View {
        HStack(spacing: 12) {
            SmartAvatarView(url: nil, name: p.effectiveDisplayName, size: 44)

            VStack(alignment: .leading, spacing: 4) {
                Text(p.effectiveDisplayName)
                    .font(.subheadline).bold()

                if !isFriend(userId: p.userId) {
                    Text(KeyLocalized.not_friends)
                        .foregroundColor(.gray)
                        .font(.caption)
                }
            }

            Spacer()

            // Show missed tag for participants with status not connected
            if p.status != .connected {
                Text(KeyLocalized.missed)
                    .foregroundColor(.red)
                    .font(.caption).fontWeight(.semibold)
            }

            if isFriend(userId: p.userId) {
                HStack(spacing: 20) {
                    Button {
                        startDirectCall(to: p, isVideo: false)
                    } label: {
                        CallMediaType.audio.icon
                            .font(.title3)
                            .foregroundColor(.cyan)
                    }
                    .buttonStyle(PlainButtonStyle())

                    Button {
                        startDirectCall(to: p, isVideo: true)
                    } label: {
                        CallMediaType.video.icon
                            .font(.title3)
                            .foregroundColor(.cyan)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            } else {
                Button {
                    sendFriendRequest(to: p.userId)
                } label: {
                    Image(systemName: "person.crop.circle.badge.plus")
                        .font(.title3)
                        .tint(.green)
                }
            }
        }
        .padding(.vertical, 8)
    }

    // MARK: - History (single list, first item is the selected call)

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(KeyLocalized.call_history)
                .font(.headline)

            VStack(alignment: .leading, spacing: 8) {
                VStack(spacing: 8) {
                    HStack {
                        Image(systemName: call.callIconName)
                            .foregroundColor(call.iconColor)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(historyTitle(for: call))
                                .font(.subheadline).bold()

                            Text(historySubtitle(for: call))
                                .font(.subheadline)
                                .foregroundColor(.secondary)

                            if let duration = call.duration, call.status == .completed || call.status == .active {
                                Text(formatDuration(duration))
                                    .font(.subheadline).fontWeight(.semibold)
                                    .foregroundColor(.primary)

                            } else if call.status == .missed {
                                Text(KeyLocalized.missed)
                                    .font(.subheadline).fontWeight(.semibold)
                                    .foregroundColor(.red)
                            }
                        }

                        Spacer()
                    }
                }
                .padding(12)
                .background(Color(.systemBackground))
                .cornerRadius(16)
                .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 4)
            }
        }
    }

    private func historyTitle(for call: CallRecord) -> String {
        let callType = call.callType ?? .defaultCase
        let callMediaType = call.callMediaType ?? .defaultCase

        return callType.title + " " + callMediaType.title.lowercased()
    }

    private func historySubtitle(for call: CallRecord) -> String {
        let dateText = "\(call.formattedDateWithRelativeDay), \(call.formattedTime)"
        return dateText
    }

    private func formatDuration(_ totalSeconds: Int) -> String {
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60

        if hours > 0 {
            return "\(hours) \(KeyLocalized.hours) \(minutes) \(KeyLocalized.minutes) \(seconds) \(KeyLocalized.seconds)"
        } else if minutes > 0 {
            return "\(minutes) \(KeyLocalized.minutes) \(seconds) \(KeyLocalized.seconds)"
        } else {
            return "\(seconds) \(KeyLocalized.seconds)"
        }
    }

    // MARK: - Helpers

    private func isFriend(userId: UInt64) -> Bool {
        let friendIds = Set(contactsViewModel.contacts.map { $0.contactId })
        return friendIds.contains(userId)
    }

    private func startCall(isVideo: Bool) {
        if isGroup {
            // Only call friends in group
            let friendParticipants = participantsExcludingCurrent.filter { isFriend(userId: $0.userId) }
            guard !friendParticipants.isEmpty else { return }

            let ids = friendParticipants.map { $0.userId }
            GroupCallManager.shared.startCall(
                to: friendParticipants.map { $0.effectiveDisplayName },
                calleeIDs: ids,
                isVideo: isVideo
            )
        } else {
            let currentUserId = UInt64(KeyStorage.shared.readUserId() ?? "0") ?? 0
            let others = participants.filter { $0.userId != currentUserId }
            guard let callee = others.first, isFriend(userId: callee.userId) else { return }
            startDirectCall(to: callee, isVideo: isVideo)
        }
    }

    private func startDirectCall(to participant: Participant, isVideo: Bool) {
        GroupCallManager.shared.startCall(
            to: [participant.effectiveDisplayName],
            calleeIDs: [participant.userId],
            isVideo: isVideo
        )
    }

    private func sendFriendRequest(to userId: UInt64) {
        ContactsAPIService.shared.sendFriendRequest(to: userId) { result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    ToastManager.shared.success(KeyLocalized.friend_request_sent_success)
                case .failure(let error):
                    ToastManager.shared.error(error.content)
                }
            }
        }
    }

    private func joinActiveCall() {
        guard !isJoiningActiveCall else { return }
        guard let callId = call.id else {
            ToastManager.shared.error(KeyLocalized.invalid_rejoin_room_information)
            return
        }

        isJoiningActiveCall = true
        GroupCallSessionManager.shared.requestRejoinCall(
            callId: callId,
            onSuccess: { isJoiningActiveCall = false },
            onError: {
                DispatchQueue.main.async {
                    isJoiningActiveCall = false
                }
            }
        )
    }
}

// MARK: - Button Styles

private struct PrimaryCapsuleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(.white)
            .padding(.vertical, 12)
            .background(Color.blue)
            .cornerRadius(12)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
    }
}

private struct SecondaryCapsuleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(.primary)
            .padding(.vertical, 12)
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
    }
}
