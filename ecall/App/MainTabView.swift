import SwiftUI

enum Tab: Int, CaseIterable {
    case history = 0
    case contacts = 1
    case settings = 2

    var title: String {
        switch self {
        case .history:
            return KeyLocalized.calls_title
        case .contacts:
            return KeyLocalized.contacts_title
        case .settings:
            return KeyLocalized.settings_title
        }
    }

    var icon: String {
        switch self {
        case .history:
            return "phone.fill"
        case .contacts:
            return "person.fill"
        case .settings:
            return "gearshape.fill"
        }
    }
}

struct MainTabView: View {
    @EnvironmentObject var languageManager: LanguageManager
    @EnvironmentObject var appState: AppState
    @StateObject private var appLockManager = AppLockManager.shared
    @State private var showCalleeView = false
    @State private var showCallerView = false
    @State private var selectedTab: Tab = .history
    @ObservedObject private var session = GroupCallSessionManager.shared

    var body: some View {
        Group {
            if appLockManager.isLocked {
                AppLockScreenView()
                    .transition(.opacity)
            } else {
                TabView(selection: $selectedTab) {
                    CallHistoryView()
                        .tabItem {
                            Image(systemName: Tab.history.icon)
                            Text(Tab.history.title)
                        }
                        .tag(Tab.history)

                    ContactsView()
                        .tabItem {
                            Image(systemName: Tab.contacts.icon)
                            Text(Tab.contacts.title)
                        }
                        .tag(Tab.contacts)

                    SettingsView()
                        .tabItem {
                            Image(systemName: Tab.settings.icon)
                            Text(Tab.settings.title)
                        }
                        .tag(Tab.settings)
                }
                .transition(.opacity)
                .id(appLockManager.isLocked ? "locked" : "unlocked")
                .onAppear {
                    // Apply any pending route set during cold start from notification
                    if let route = appState.pendingRoute {
                        switch route {
                        case .settings:
                            selectedTab = .settings
                            appState.pendingRoute = nil
                        case .contacts:
                            selectedTab = .contacts
                            appState.pendingRoute = nil
                        case .contactsFriendRequests:
                            selectedTab = .contacts
                            // Fallback: broadcast after slight delay so ContactsView can push
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                                NotificationCenter.default.post(name: .newFriendRequested, object: nil)
                            }
                            appState.pendingRoute = nil
                        }
                    }
                }
                .onChange(of: appState.pendingRoute) { newValue in
                    guard let route = newValue else { return }
                    switch route {
                    case .settings:
                        selectedTab = .settings
                    case .contacts:
                        selectedTab = .contacts
                    case .contactsFriendRequests:
                        selectedTab = .contacts
                        // Fallback: broadcast after slight delay so ContactsView can push
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                            NotificationCenter.default.post(name: .newFriendRequested, object: nil)
                        }
                        appState.pendingRoute = nil
                    }
                }
                .onChange(of: selectedTab) { newTab in
                    if newTab == .history {
                        NotificationCenter.default.post(name: .reloadCallHistory, object: nil)
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: .didStartCall)) { _ in
                    showCallerView = true
                }
                .onReceive(NotificationCenter.default.publisher(for: .didAnswerCall)) { _ in
                    showCalleeView = true
                }
                .onReceive(NotificationCenter.default.publisher(for: .switchToSettingsTab)) { _ in
                    // Switch to Settings tab when notification is received
                    selectedTab = .settings
                }
                .onReceive(NotificationCenter.default.publisher(for: .newFriendRequested)) { _ in
                    // Switch to Contacts tab when new friend request is received
                    selectedTab = .contacts
                }
                .onReceive(NotificationCenter.default.publisher(for: .acceptFriendRequested)) { _ in
                    // Only switch to Contacts tab if not already there
                    if selectedTab != .contacts {
                        selectedTab = .contacts
                    }
                }
                .fullScreenCover(isPresented: $showCalleeView) {
                    let callHandleName = session.currentHost?.displayName ?? KeyLocalized.unknown
                    let callHandleId = session.currentHost?.userId ?? 0
                    let isVideo = session.isVideoCall

                    CallView(callHandleName: callHandleName, callHandleId: callHandleId, isVideo: isVideo)
                        .environmentObject(languageManager)
                }
                .fullScreenCover(isPresented: $showCallerView) {
                    let callee = session.participants.first(where: { $0.isHost == false })
                    let callHandleName = callee?.displayName ?? KeyLocalized.unknown
                    let callHandleId = callee?.userId ?? 0
                    let isVideo = session.isVideoCall

                    CallView(callHandleName: callHandleName, callHandleId: callHandleId, isVideo: isVideo)
                        .environmentObject(languageManager)
                }
                .logViewName()
            }
        }
        .onAppear {
            // Check and lock app if needed when view appears (only if user is logged in)
            if appState.isRegistered {
                Task {
                    await appLockManager.checkAndLockIfNeeded()
                }
            }
        }
        .onChange(of: appState.isRegistered) { isRegistered in
            // If user logs out, ensure app is unlocked
            if !isRegistered {
                appLockManager.clearAppLockSettings()
            }
        }
    }
}

#Preview {
    MainTabView()
        .environmentObject(LanguageManager())
}
