import Foundation

@MainActor
final class PermissionsViewModel: ObservableObject {
    @Published private(set) var items: [PermissionItem] = []
    @Published private(set) var allPermissionsGranted: Bool = false

    private let service: PermissionsService

    init(service: PermissionsService = .shared) {
        self.service = service
    }

    func refresh() {
        Task {
            let items = await service.fetchAllStatuses()
            apply(items: items)
        }
    }

    private func apply(items: [PermissionItem]) {
        self.items = items
        allPermissionsGranted = items.allSatisfy { $0.status == .granted }
    }

    func openSettings() {
        service.openSystemSettings()
    }

    func requestPermission(for type: PermissionType) {
        Task {
            _ = await service.requestPermission(for: type)
            refresh()
        }
    }
}
