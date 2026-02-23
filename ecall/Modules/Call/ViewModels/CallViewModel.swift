import SwiftUI

@MainActor
class CallViewModel: ObservableObject {
    @Published var navigationPath = NavigationPath()
    // Full dataset currently loaded (paged)
    @Published var items: [CallRecord] = []
    @Published var selectedSegment: Int = 0  // 0: All, 1: Missed
    @Published var query: String = ""
    @Published var selectedCalls: Set<UInt64> = []      // track multi‐selection

    enum LoadingState {
        case idle
        case refreshing
        case loadingMore
    }
    @Published var loadingState: LoadingState = .idle

    // Pagination
    private(set) var page: Int = 0
    private(set) var size: Int = AppConfig.PageSize.medium
    private(set) var total: Int = 0
    private var hasLoadedInitialInternal = false
    var hasLoadedInitial: Bool { hasLoadedInitialInternal }

    // Computed property to determine if we should filter by missed
    private var isMissed: Bool {
        selectedSegment == 1
    }

    init() {
        // Don't load in init, let view handle it with .task
    }

    func updateSearch(query: String) {
        self.query = query
        // Reset to page 0 and reload when search changes
        Task {
            await loadInitial(page: 0, size: size, name: query.isEmpty ? nil : query)
        }
    }

    func fetchCalls() {
        Task {
            await refresh()
        }
    }

    func loadInitialIfNeeded() async {
        guard !hasLoadedInitialInternal else { return }
        await loadInitial(page: 0, size: size, name: query.isEmpty ? nil : query)
    }

    func forceReload() async {
        hasLoadedInitialInternal = false
        await loadInitial(page: 0, size: size, name: query.isEmpty ? nil : query)
    }

    func loadInitial(page: Int = 0, size: Int = AppConfig.PageSize.medium, name: String? = nil) async {
        self.page = page
        self.size = size
        await MainActor.run {
            loadingState = .refreshing
        }
        // Use query from state if name not provided
        let searchName = name ?? (query.isEmpty ? nil : query)
        CallService.shared.fetchCallHistory(page: page, size: size, name: searchName, isMissed: isMissed) { [weak self] records, total in
            guard let self = self else { return }
            DispatchQueue.main.async {
                self.total = total
                self.items = records
                self.loadingState = .idle
                self.hasLoadedInitialInternal = true
                self.cleanupEncryptedAESKeys(for: records)
            }
        }
    }

    func refresh() async {
        await loadInitial(page: 0, size: size)
    }

    func loadMore() {
        guard loadingState == .idle else { return }
        guard items.count < total else { return }
        loadingState = .loadingMore
        let nextPage = page + 1
        let searchName = query.isEmpty ? nil : query
        CallService.shared.fetchCallHistory(page: nextPage, size: size, name: searchName, isMissed: isMissed) { [weak self] records, total in
            guard let self = self else { return }
            DispatchQueue.main.async {
                self.page = nextPage
                self.total = total
                self.items.append(contentsOf: records)
                self.loadingState = .idle
                self.cleanupEncryptedAESKeys(for: self.items)
            }
        }
    }

    func loadMoreIfNeeded(at index: Int) async {
        // Only load more if we're near the end and not already loading
        guard loadingState == .idle else { return }
        guard items.count < total else { return }
        loadMore()
    }

    /// Clean up encryptedAESKeys for calls that are no longer active
    /// If a callId appears multiple times and all have status != "active", remove the key
    private func cleanupEncryptedAESKeys(for calls: [CallRecord]) {
        // Group calls by callId
        let callsByCallId = Dictionary(grouping: calls) { $0.id }

        // For each callId, check if all records have status != "active"
        for (callId, callRecords) in callsByCallId {
            guard let callId = callId else { continue }

            // Check if all records for this callId have status != "active"
            let allInactive = callRecords.allSatisfy { $0.status != .active }

            if allInactive {
                // Remove encryptedAESKey for this callId
                _ = CallKeyStorage.shared.removeEncryptedAESKey(for: callId)
            }
        }
    }

    func deleteCalls(withIDs ids: Set<UInt64>) {
        let idArray = Array(ids)
        guard !idArray.isEmpty else { return }

        // Clean up encryptedAESKeys for deleted calls
        for callId in idArray {
            _ = CallKeyStorage.shared.removeEncryptedAESKey(for: callId)
        }

        // If your backend supports bulk deletes, you can call that:
        CallService.shared.deleteCallHistories(ids: idArray) { [weak self] success in
            DispatchQueue.main.async {
                if success {
                    // clear selection, then re‐fetch
                    self?.selectedCalls.removeAll()
                    Task {
                        await self?.refresh()
                    }
                } else {
                    ToastManager.shared.error(KeyLocalized.unknown_error_try_again)
                }
            }
        }
    }
}
