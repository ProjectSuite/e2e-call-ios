import Foundation

final class CryptoLogger: ObservableObject {
    static let shared = CryptoLogger()
    @Published private(set) var entries: [String] = []
    private let capacity = 500

    func add(_ line: String) {
        DispatchQueue.main.async {
            if self.entries.count >= self.capacity {
                self.entries.removeFirst(self.entries.count - self.capacity + 1)
            }
            self.entries.append(line)
            NotificationCenter.default.post(name: .cryptoLogAppended, object: nil)
        }
    }

    func clear() {
        DispatchQueue.main.async { self.entries.removeAll() }
    }
}
