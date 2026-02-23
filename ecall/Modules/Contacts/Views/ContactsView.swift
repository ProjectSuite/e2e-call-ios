import SwiftUI

struct ContactsView: View {
    @EnvironmentObject var languageManager: LanguageManager
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel = ContactsViewModel()
    @State private var showAddFriend = false
    @State private var showCalleeView = false
    @State private var navigateToFriendRequests = false

    @FocusState private var isSearchFocused: Bool

    var body: some View {
        NavigationStack {
            VStack {
                searchBar

                content
            }
            .padding(.top, 16)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        showAddFriend = true
                    } label: {
                        Image(systemName: "person.fill.badge.plus")
                    }
                }
                ToolbarItem(placement: .principal) {
                    Text(KeyLocalized.contacts_title)
                        .font(.headline)
                }
            }
            .sheet(isPresented: $showAddFriend) {
                AddFriendView()
                    .environmentObject(languageManager)
            }
            .onAppear {
                viewModel.loadContacts()
                // Handle cold start deep-link to Friend Requests
                if appState.pendingRoute == .contactsFriendRequests {
                    navigateToFriendRequests = true
                    appState.pendingRoute = nil
                }
            }
            .onChange(of: appState.pendingRoute) { newValue in
                guard let route = newValue else { return }
                if route == .contactsFriendRequests {
                    navigateToFriendRequests = true
                    appState.pendingRoute = nil
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .newFriendRequested)) { _ in
                // Navigate to FriendRequestsView when new friend request is received
                navigateToFriendRequests = true
            }
            .onReceive(NotificationCenter.default.publisher(for: .acceptFriendRequested)) { _ in
                // Always reload contacts when friend request is accepted
                viewModel.loadContacts()
            }
            .navigationDestination(isPresented: $navigateToFriendRequests) {
                FriendRequestsView()
                    .environmentObject(languageManager)
            }
        }
        .logViewName()
    }

    private var searchBar: some View {
        HStack {
            // 1) The actual text field + clear button
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.gray)

                TextField(KeyLocalized.search_contacts, text: $viewModel.searchText)
                    .focused($isSearchFocused)
                    .disableAutocorrection(true)
                    .autocapitalization(.none)

                if !viewModel.searchText.isEmpty {
                    Button {
                        viewModel.searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                    }
                }
            }
            .padding(8)
            .background(Color(.systemGray6))
            .cornerRadius(8)

            // 2) The Cancel button, only when focused
            if isSearchFocused {
                Button(KeyLocalized.cancel) {
                    viewModel.searchText = ""
                    isSearchFocused = false
                    // Dismiss keyboard
                    UIApplication.shared.sendAction(
                        #selector(UIResponder.resignFirstResponder),
                        to: nil, from: nil, for: nil
                    )
                }
                .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .padding(.horizontal)
        // animate the Cancel button appearing/disappearing
        .animation(.default, value: isSearchFocused)
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading {
            VStack {
                Spacer()
                ProgressView(KeyLocalized.loading_contacts)
                Spacer()
            }
        } else {
            ContactsListView(
                viewModel: viewModel,
                toggleFavorite: { id in viewModel.toggleFavorite(contactID: id) },
                deleteContact: { id in viewModel.deleteContact(contactID: id) }
            )
        }
    }
}

struct ContactsView_Previews: PreviewProvider {
    static var previews: some View {
        ContactsView()
            .environmentObject(LanguageManager())
    }
}
