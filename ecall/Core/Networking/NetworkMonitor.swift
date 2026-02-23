import Foundation
import Network

/// A singleton that observes the device’s network path (Wi-Fi ↔ Cellular ↔ Offline).
/// Publishes three @Published properties any time something changes:
///   - isConnected  (Bool)
///   - isCellular   (Bool)
///   - isWiFi       (Bool)
final class NetworkMonitor: ObservableObject {

    /// Shared instance
    static let shared = NetworkMonitor()

    /// Underlying NWPathMonitor
    private let monitor = NWPathMonitor()
    /// Serial queue for the NWPathMonitor callback
    private let queue = DispatchQueue(label: "NetworkMonitorQueue")

    /// True if any network is available (path.status == .satisfied)
    @Published public private(set) var isConnected: Bool = false
    /// True if the active interface type includes Cellular
    @Published public private(set) var isCellular: Bool = false
    /// True if the active interface type includes Wi-Fi
    @Published public private(set) var isWiFi: Bool = false

    /// Expose the raw NWPath if you ever need it
    public var currentPath: NWPath? {
        return monitor.currentPath
    }

    /// Private init → enforce singleton
    private init() {
        startMonitoring()
    }

    deinit {
        stopMonitoring()
    }

    // MARK: - Start / Stop monitoring

    private func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            guard let self = self else { return }

            // Determine new values
            let newIsConnected = (path.status == .satisfied)
            let newIsCellular  = path.usesInterfaceType(.cellular)
            let newIsWiFi      = path.usesInterfaceType(.wifi)

            // Only publish if there is a real change
            DispatchQueue.main.async {
                if self.isConnected != newIsConnected {
                    self.isConnected = newIsConnected
                }
                if self.isCellular != newIsCellular {
                    self.isCellular = newIsCellular
                }
                if self.isWiFi != newIsWiFi {
                    self.isWiFi = newIsWiFi
                }
            }
        }
        monitor.start(queue: queue)
    }

    private func stopMonitoring() {
        monitor.cancel()
    }
}
