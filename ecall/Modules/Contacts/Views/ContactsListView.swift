import SwiftUI

struct ContactsListView: View {
    @ObservedObject var viewModel: ContactsViewModel
    let toggleFavorite: (UInt64) -> Void
    let deleteContact: (UInt64) -> Void
    @EnvironmentObject var languageManager: LanguageManager

    @State private var isStartingCall = false
    @State private var showDeleteConfirmation = false
    @State private var contactIdPendingDeletion: UInt64?

    var body: some View {
        List {

            friendRequestsSection

            if !viewModel.favoriteContactsFiltered.isEmpty {
                Section(header: favoriteHeader) {
                    contactsList(viewModel.favoriteContactsFiltered)
                }
            }

            if !viewModel.allContactsFiltered.isEmpty {
                Section(header: allHeader) {
                    contactsList(viewModel.allContactsFiltered)
                }
            }
        }
        .listStyle(PlainListStyle())
        .alert(KeyLocalized.confirm, isPresented: $showDeleteConfirmation) {
            Button(KeyLocalized.delete, role: .destructive) {
                if let id = contactIdPendingDeletion {
                    deleteContact(id)
                }
                contactIdPendingDeletion = nil
            }
            Button(KeyLocalized.cancel, role: .cancel) {
                contactIdPendingDeletion = nil
            }
        } message: {
            Text(KeyLocalized.delete_friend_message)
        }
    }

    private var friendRequestsSection: some View {
        Section {
            NavigationLink(destination: FriendRequestsView()) {
                HStack {
                    Image(systemName: "person.2.circle.fill")
                        .resizable()
                        .frame(width: 40, height: 40)
                        .foregroundColor(.blue)
                    Text(KeyLocalized.friend_requests)
                        .font(.subheadline)
                    Spacer()
                }
                .padding(.vertical, 8)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
        }
    }

    private func contactsList(_ contacts: [Contact]) -> some View {
        ForEach(contacts) { contact in
            ZStack {
                // Hidden NavigationLink for tap action
                //                NavigationLink(destination: ContactDetailView(contact: contact)) {
                //                    EmptyView()
                //                }
                //                .opacity(0)

                // Actual contact row content
                ContactRow(contact: contact, isStartingCall: $isStartingCall)
                    .padding(.vertical, 8)
            }
            // Swipe right (trailing) includes both delete and favorite/unfavorite
            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                deleteButton(for: contact)
                favoriteButton(for: contact)
            }
            .listRowSeparator(.hidden) // Hide separator
            .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16)) // Adjust padding
        }
    }

    private var favoriteHeader: some View {
        Text(KeyLocalized.favorites)
            .font(.subheadline)
            .padding(.bottom, 12)
    }

    private var allHeader: some View {
        Text(KeyLocalized.all_contacts)
            .font(.subheadline)
            .padding(.bottom, 12)
    }

    private func deleteButton(for contact: Contact) -> some View {
        Button(role: .destructive) {
            if let id = contact.id {
                contactIdPendingDeletion = id
                showDeleteConfirmation = true
            }
        } label: {
            Label(KeyLocalized.delete, systemImage: "trash")
        }
    }

    private func favoriteButton(for contact: Contact) -> some View {
        Button {
            if let id = contact.id {
                toggleFavorite(id)
            }
        } label: {
            Label(KeyLocalized.favorite, systemImage: contact.isFavorite ? "star.fill" : "star")
        }
        .tint(contact.isFavorite ? .gray : .yellow)
    }
}
