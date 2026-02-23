import SwiftUI

struct AppConfig {
    /// Bundle URL scheme - read from Info.plist (BUNDLE_URL_SCHEME) or default to "yourapp"
    static var schema: String {
        return Bundle.main.object(forInfoDictionaryKey: "BUNDLE_URL_SCHEME") as? String ?? "yourapp"
    }

    static let maximumNameLength = 50

    enum PageSize {
        static let small = 10
        static let medium = 20
        static let large = 50
        static let extraLarge = 100
    }
}
