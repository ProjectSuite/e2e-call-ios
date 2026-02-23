import SwiftUI

/// A view for calling contacts directly from the contact list.
/// Each contact has a call button that initiates a call immediately.
struct SelectContactListView: View {
    @ObservedObject private var callSessionManager = GroupCallSessionManager.shared

    // MARK: - Models

    enum ContactCallStatus {
        case notInvited
        case inviting
        case rejected
        case joined
    }

    // MARK: - Properties
    @Binding var isPresented: Bool
    let contacts: [Contact]

    @State private var searchText: String = ""
    @State private var isStartingCall = false

    var filteredContacts: [Contact] {
        if searchText.trimmingCharacters(in: .whitespaces).isEmpty {
            contacts
        } else {
            contacts.filter {
                $0.contactName.localizedCaseInsensitiveContains(searchText)
            }
        }
    }

    // MARK: - Helper Methods
    private func getParticipantStatus(for contact: Contact) -> ContactCallStatus {
        // Check participant status from session
        if let participant = callSessionManager.participants.first(where: { $0.userId == contact.contactId }) {
            switch participant.status {
            case .inviting:
                return .inviting
            case .rejected:
                return .rejected
            case .accepted, .connected:
                return .joined
            case .left, .reconnecting, .none:
                return .notInvited
            }
        }

        // Check if participant is inviting (for pending invites)
        if let participant = callSessionManager.participants.first(where: { $0.userId == contact.contactId }),
           participant.status == .inviting {
            return .inviting
        }

        return .notInvited
    }

    // MARK: - Body
    var body: some View {
        NavigationView {
            List(filteredContacts) { contact in
                ContactRowWithStatus(
                    contact: contact,
                    status: getParticipantStatus(for: contact),
                    isStartingCall: $isStartingCall
                ) {
                    handleContactAction(for: contact)
                }
            }
            .navigationBarTitle(KeyLocalized.call_contacts, displayMode: .inline)
            .navigationBarItems(
                leading: Button(KeyLocalized.cancel) {
                    isPresented = false
                }
            )
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: KeyLocalized.search_contacts)
        }
        .logViewName()
    }

    // MARK: - Helpers
    private func handleContactAction(for contact: Contact) {
        let status = getParticipantStatus(for: contact)

        switch status {
        case .notInvited, .rejected:
            ringContact(contact)
        case .inviting:
            // Do nothing - already inviting
            break
        case .joined:
            // Already joined - should not appear
            break
        }
    }

    private func ringContact(_ contact: Contact) {
        guard !isStartingCall else { return }
        isStartingCall = true

        // Invite this contact to the current group call
        // (GroupCallManager will add to invitedParticipants on success)
        GroupCallManager.shared.inviteParticipants(
            calleeNames: [contact.contactName],
            calleeIDs: [contact.contactId]
        )

        // Re-enable after 2 seconds to throttle taps
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            isStartingCall = false
        }
    }
}

// MARK: - Row View
private struct ContactRowWithStatus: View {
    let contact: Contact
    let status: SelectContactListView.ContactCallStatus
    @Binding var isStartingCall: Bool
    let onAction: () -> Void

    var body: some View {
        HStack {
            SmartAvatarView(
                url: nil,
                name: contact.contactName,
                size: 40
            )

            Text(contact.contactName)
                .font(.subheadline)
                .bold()

            Spacer()

            // Action button based on status
            actionButton
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private var actionButton: some View {
        switch status {
        case .notInvited:
            Button(action: onAction) {
                Text(KeyLocalized.call)
                    .font(.caption)
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.blue)
                    .cornerRadius(8)
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(isStartingCall)
            .opacity(isStartingCall ? 0.6 : 1)

        case .rejected:
            Button(action: onAction) {
                HStack(spacing: 8) {
                    HStack(spacing: 4) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.red)
                            .font(.caption)
                        Text(KeyLocalized.rejected)
                            .font(.caption)
                            .foregroundColor(.red)
                    }

                    Text(KeyLocalized.call)
                        .font(.caption)
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.blue)
                        .cornerRadius(8)
                }
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(isStartingCall)
            .opacity(isStartingCall ? 0.6 : 1)

        case .inviting:
            HStack(spacing: 4) {
                Image(systemName: "phone.arrow.up.right")
                    .foregroundColor(.orange)
                    .font(.caption)
                Text(KeyLocalized.calling)
                    .font(.caption)
                    .foregroundColor(.orange)
            }

        case .joined:
            HStack(spacing: 4) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.caption)
                Text(KeyLocalized.joined)
                    .font(.caption)
                    .foregroundColor(.green)
            }
        }
    }
}
