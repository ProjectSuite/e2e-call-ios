import SwiftUI

struct CallHistoryContentView: View {
    @ObservedObject var viewModel: CallViewModel
    @EnvironmentObject var languageManager: LanguageManager
    @StateObject private var contactsViewModel = ContactsViewModel()
    @Binding var selection: Set<UInt64>
    @Environment(\.editMode) private var editMode
    @State private var isStartingCall = false
    @State private var callToAddFriend: CallRecord?
    @State private var activeCallID: UInt64?
    @State private var showDeleteConfirmation = false
    @State private var callToDelete: CallRecord?
    @State private var selectedCall: CallRecord?

    var body: some View {
        GeometryReader { _ in
            if viewModel.items.isEmpty && viewModel.loadingState == .idle {
                VStack(spacing: 16) {
                    CallMediaType.audio.icon
                        .font(.system(size: 50))
                        .foregroundColor(.gray)
                    Text(KeyLocalized.no_data)
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.top, 100)
            } else {
                List {
                    ForEach(Array(viewModel.items.enumerated()), id: \.1.id) { index, call in
                        let canCall = hasAnyFriend(participants: call.participants ?? [])
                        let showButtons = canCall && editMode?.wrappedValue != .active

                        if let callId = call.id {
                            CallHistoryRow(
                                call: call,
                                selection: $selection,
                                onJoinTap: {
                                    handleJoinActiveCall(call: call)
                                },
                                onCallTap: {
                                    handleCallHistoryTap(call: call)
                                },
                                isDisabled: isStartingCall,
                                showButtons: showButtons
                            )
                            .opacity(isStartingCall || !canCall ? 0.5 : 1)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                if editMode?.wrappedValue == .active {
                                    if selection.contains(callId) {
                                        selection.remove(callId)
                                    } else {
                                        selection.insert(callId)
                                    }
                                } else {
                                    selectedCall = call
                                }
                            }
                            .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                if editMode?.wrappedValue != .active {
                                    Button(role: .destructive) {
                                        callToDelete = call
                                        showDeleteConfirmation = true
                                    } label: {
                                        Label(KeyLocalized.delete, systemImage: "trash")
                                    }

                                    if !canCall {
                                        Button {
                                            callToAddFriend = call
                                        } label: {
                                            Label(KeyLocalized.add_friend_button, systemImage: "person.crop.circle.badge.plus")
                                        }
                                        .tint(.green)
                                    }
                                }
                            }
                            .onAppear {
                                // Load more when reaching near the end
                                if index >= viewModel.items.count - 3 {
                                    Task {
                                        await viewModel.loadMoreIfNeeded(at: index)
                                    }
                                }
                            }
                        } else {
                            // Fallback for calls without ID
                            CallHistoryRow(
                                call: call,
                                selection: $selection,
                                onJoinTap: {
                                    handleJoinActiveCall(call: call)
                                },
                                onCallTap: {
                                    handleCallHistoryTap(call: call)
                                },
                                isDisabled: isStartingCall,
                                showButtons: showButtons
                            )
                            .opacity(isStartingCall || !canCall ? 0.5 : 1)
                            .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                        }
                    }

                    if viewModel.loadingState == .loadingMore {
                        HStack {
                            Spacer()
                            ProgressView()
                            Spacer()
                        }
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets())
                    }
                }
                .listStyle(.plain)
                .listRowSeparatorTint(.clear, edges: .top)
                .refreshable {
                    await viewModel.refresh()
                }
                .overlay {
                    if viewModel.loadingState == .refreshing {
                        ProgressView()
                            .scaleEffect(1.5)
                    }
                }
                .navigationDestination(isPresented: Binding(
                    get: { selectedCall != nil },
                    set: { if !$0 { selectedCall = nil } }
                )) {
                    if let call = selectedCall {
                        CallHistoryDetailView(call: call, contactsViewModel: contactsViewModel)
                            .environmentObject(languageManager)
                    } else {
                        ProgressView()
                    }
                }
            }
        }
        .onAppear() {
            contactsViewModel.loadContacts()
        }
        .sheet(item: $callToAddFriend) { call in
            let user = (call.participants ?? []).first(where: { $0.userId != UInt64(KeyStorage.shared.readUserId() ?? "0") })

            AddFriendView(initialKey: String(describing: user?.userId ?? 0), displayName: user?.displayName)
                .environmentObject(languageManager)
        }
        .alert(KeyLocalized.confirm, isPresented: $showDeleteConfirmation) {
            Button(KeyLocalized.delete, role: .destructive) {
                if let call = callToDelete, let callId = call.id {
                    viewModel.deleteCalls(withIDs: [callId])
                }
                callToDelete = nil
            }
            Button(KeyLocalized.cancel, role: .cancel) {
                callToDelete = nil
            }
        } message: {
            Text(KeyLocalized.delete_selected_calls_message)
        }
        .logViewName()
    }

    private func hasAnyFriend(participants: [Participant]) -> Bool {
        // ContactsViewModel is now non-optional (@StateObject)
        let currentUserId = UInt64(KeyStorage.shared.readUserId() ?? "0") ?? 0
        let otherIds = participants.map { $0.userId }.filter { $0 != currentUserId }
        if otherIds.isEmpty { return false }
        let friendIds = Set(contactsViewModel.contacts.map { $0.contactId })
        // Return true if at least one participant is a friend
        return otherIds.contains { friendIds.contains($0) }
    }

    private func handleCallHistoryTap(call: CallRecord) {
        // Check if we're in edit mode or already starting a call
        guard editMode?.wrappedValue != .active,
              !isStartingCall else {
            let isEditing = (editMode?.wrappedValue == .active)
            debugLog("📱 [CallHistoryContentView] Cannot start call: editModeActive=\(isEditing), isStartingCall=\(isStartingCall)")
            return
        }

        // Check if at least one participant is a friend
        guard hasAnyFriend(participants: call.participants ?? []) else {
            let displayName = CallUtils.formatParticipantsDisplayNames(call.participants ?? [])
            debugLog("📱 [CallHistoryContentView] Cannot start call: no friends in participants \(displayName)")
            // TODO: Show toast message that no friends in participants
            return
        }

        let currentUserId = UInt64(KeyStorage.shared.readUserId() ?? "0") ?? 0
        let others = (call.participants ?? []).filter { $0.userId != currentUserId }
        if others.isEmpty {
            debugLog("📱 [CallHistoryContentView] Cannot start call: no other participants")
            return
        }

        let friendIds = Set(contactsViewModel.contacts.map { $0.contactId })
        let friendParticipants = others.filter { friendIds.contains($0.userId) }
        guard !friendParticipants.isEmpty else {
            debugLog("📱 [CallHistoryContentView] No friend participants available to start call")
            return
        }

        let names = friendParticipants.map { $0.effectiveDisplayName }
        let ids = friendParticipants.map { $0.userId }
        debugLog("📱 [CallHistoryContentView] Starting call to friends: \(names.joined(separator: ", ")) (IDs: \(ids))")

        isStartingCall = true
        GroupCallManager.shared.startCall(
            to: names,
            calleeIDs: ids,
            isVideo: call.isVideo
        )

        // Reset state after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            isStartingCall = false
        }
    }

    private func handleJoinActiveCall(call: CallRecord) {
        // Check if already joining
        guard !isStartingCall else {
            debugLog("📱 [CallHistoryContentView] Already joining a call")
            return
        }

        // Check if we have required data
        guard let callId = call.id else {
            debugLog("📱 [CallHistoryContentView] Cannot join call: missing call ID")
            ToastManager.shared.error(KeyLocalized.invalid_rejoin_room_information)
            return
        }

        isStartingCall = true

        GroupCallSessionManager.shared.requestRejoinCall(callId: callId, onError: {
            Task {
                await viewModel.refresh()
            }
        })

        // Reset state after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            isStartingCall = false
        }
    }
}
