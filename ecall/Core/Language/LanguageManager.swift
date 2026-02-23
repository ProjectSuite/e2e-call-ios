import SwiftUI

/// Supported application languages
enum Language: String, CaseIterable, Identifiable {
    case en, vi, es, hi, ar, pt, ru, ja, ko, th, fr, de, it
    case zhHans = "zh-Hans"
    case kh = "km-KH"

    var id: String { rawValue }

    /// Locale for SwiftUI environment
    var locale: Locale {
        Locale(identifier: rawValue)
    }

    /// Human-readable name for display in picker
    var displayName: String {
        // Uses Foundation to get the language's own name, falling back to raw value
        Locale(identifier: rawValue)
            .localizedString(forLanguageCode: rawValue)?.capitalized
            ?? rawValue
    }

    /// All languages the app actually has localization files for
    static var available: [Language] {
        Bundle.main
            .localizations
            .compactMap(Language.init)
    }
}

class LanguageManager: ObservableObject {
    static let shared = LanguageManager()

    // Persist the language code, defaulting to device's setting
    @AppStorage("selectedLanguage") private var selectedLanguageCode: String = Locale.current.language.languageCode?.identifier ?? "en" {
        didSet {
            objectWillChange.send()
            updateLanguageBundle()
        }
    }

    // Cache bundles for performance
    private var bundleCache: [String: Bundle] = [:]
    private var currentBundle: Bundle = .main

    var currentLanguageCode: String {
        selectedLanguageCode
    }

    /// All your supported cases
    var currentLanguage: Language {
        Language(rawValue: selectedLanguageCode) ?? .en
    }

    /// A Locale for SwiftUI's environment
    var locale: Locale {
        Locale(identifier: selectedLanguageCode)
    }

    init() {
        updateLanguageBundle()
    }

    /// Change language
    func setLanguage(_ lang: Language) {
        selectedLanguageCode = lang.rawValue

        // Pre-load and cache the new language bundle immediately
        let langCode = lang.rawValue
        if let path = Bundle.main.path(forResource: langCode, ofType: "lproj"),
           let bundle = Bundle(path: path) {
            bundleCache[langCode] = bundle
            currentBundle = bundle
        }
    }

    /// Get localized string for current language
    func localizedString(_ key: String) -> String {
        let langCode = selectedLanguageCode

        // Check cache first for performance
        if let cachedBundle = bundleCache[langCode] {
            // Update currentBundle if needed
            if currentBundle != cachedBundle {
                currentBundle = cachedBundle
            }
            return cachedBundle.localizedString(forKey: key, value: nil, table: nil)
        }

        // Create new bundle and cache it
        guard let path = Bundle.main.path(forResource: langCode, ofType: "lproj"),
              let bundle = Bundle(path: path) else {
            return key
        }

        // Cache the bundle and update currentBundle
        bundleCache[langCode] = bundle
        currentBundle = bundle

        return bundle.localizedString(forKey: key, value: nil, table: nil)
    }

    /// Get localized string with arguments
    func localizedString(_ key: String, _ args: CVarArg...) -> String {
        let format = localizedString(key)
        return String(format: format, arguments: args)
    }

    /// Resolve localized message for API error codes (e.g., ECS_Feature_ErrorCase).
    /// - If localization for `code` exists, returns it. Otherwise, returns `defaultMessage`.
    func localizedAPIError(code: String?, defaultMessage: String) -> String {
        guard let code = code, !code.isEmpty else {
            return defaultMessage
        }
        let localized = localizedString(code)
        if localized != code { return localized }
        return defaultMessage
    }

    /// Update the bundle for current language
    private func updateLanguageBundle() {
        guard let path = Bundle.main.path(forResource: selectedLanguageCode, ofType: "lproj"),
              let bundle = Bundle(path: path) else {
            currentBundle = .main
            return
        }
        currentBundle = bundle
    }
}

extension String {
    func localized() -> String {
        return LanguageManager.shared.localizedString(self)
    }

    func localized(with arguments: CVarArg...) -> String {
        return LanguageManager.shared.localizedString(self, arguments)
    }
}
