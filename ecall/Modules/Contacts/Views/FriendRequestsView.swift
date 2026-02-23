import SwiftUI

struct FriendRequestsView: View {
    @EnvironmentObject var languageManager: LanguageManager
    @Environment(\.dismiss) private var dismiss
    @StateObject private var vm = FriendRequestsViewModel()
    @State private var selectedTab: Tab = .received
    @State private var showMyQRCode = false
    @State private var showAddFriend = false

    enum Tab: String, CaseIterable {
        case received
        case sent

        var title: String {
            switch self {
            case .received:
                return KeyLocalized.received
            case .sent:
                return KeyLocalized.sent
            }
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("", selection: $selectedTab) {
                    Text(Tab.received.title).tag(Tab.received)
                    Text(Tab.sent.title).tag(Tab.sent)
                }
                .pickerStyle(.segmented)
                .padding()

                if vm.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if !vm.errorMessage.isEmpty {
                    Text(vm.errorMessage)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.red)
                        .padding()
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                } else if selectedTab == .received {
                    if vm.received.isEmpty {
                        EmptyStateView(
                            icon: "envelope.open",
                            title: KeyLocalized.no_received_requests,
                            description: KeyLocalized.no_received_requests_description,
                            actionTitle: KeyLocalized.share_qr_code_to_add_friends,
                            action: { showMyQRCode = true }
                        )
                    } else {
                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 16) {
                                ForEach(groupedSections, id: \.id) { section in
                                    Text(section.title)
                                        .font(.subheadline).bold()
                                        .foregroundColor(.gray)
                                        .padding(.horizontal)
                                    ForEach(section.requests) { req in
                                        ReceivedRequestRow(
                                            request: req,
                                            onAccept: { vm.accept(req) },
                                            onDecline: { vm.decline(req) }
                                        )
                                        .padding(.horizontal)
                                    }
                                }
                            }
                            .padding(.vertical)
                        }
                    }
                } else {
                    if vm.sent.isEmpty {
                        EmptyStateView(
                            icon: "paperplane.fill",
                            title: KeyLocalized.no_sent_requests,
                            description: KeyLocalized.no_sent_requests_description,
                            actionTitle: KeyLocalized.add_new_friends,
                            action: { showAddFriend = true }
                        )
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 12) {
                                ForEach(vm.sent) { req in
                                    SentRequestRow(
                                        request: req,
                                        onCancel: { vm.cancel(req) }
                                    )
                                    .padding(.horizontal)
                                }
                            }
                            .padding(.vertical)
                        }
                    }
                }
            }
            .navigationBarTitle(KeyLocalized.friend_requests, displayMode: .inline)
            .sheet(isPresented: $showMyQRCode) {
                MyQRCodeView(showQRCodePopup: $showMyQRCode)
                    .presentationDetents([.large])
                    .interactiveDismissDisabled(false)
            }
            .sheet(isPresented: $showAddFriend) {
                AddFriendView()
                    .environmentObject(languageManager)
            }
        }
        .logViewName()
    }

    // MARK: – Grouping by month/year
    private struct SectionData { let id: String; let title: String; let requests: [FriendRequest] }
    private var groupedSections: [SectionData] {
        let items = (selectedTab == .received ? vm.received : vm.sent)
        let cal = Calendar.current

        // group by year-month string
        let dict = Dictionary(grouping: items) { req in
            if let date = DateFormatters.iso8601Fractional.date(from: req.date) ?? DateFormatters.iso8601.date(from: req.date) {
                let comps = cal.dateComponents([.year, .month], from: date)
                return String(format: "%04d-%02d", comps.year ?? 0, comps.month ?? 0)
            }
            return "0000-00" // Default for invalid dates
        }

        return dict
            .map { key, vals in
                let parts = key.split(separator: "-")
                let year = parts.first.map(String.init) ?? ""
                let month = parts.last.flatMap { Int($0) } ?? 0
                return SectionData(
                    id: key,
                    title: String(format: KeyLocalized.month_year_format, month, year),
                    requests: vals.sorted {
                        let date1 = DateFormatters.iso8601Fractional.date(from: $0.date) ?? DateFormatters.iso8601.date(from: $0.date) ?? Date.distantPast
                        let date2 = DateFormatters.iso8601Fractional.date(from: $1.date) ?? DateFormatters.iso8601.date(from: $1.date) ?? Date.distantPast
                        return date1 > date2
                    }
                )
            }
            .sorted { $0.id > $1.id }
    }
}
