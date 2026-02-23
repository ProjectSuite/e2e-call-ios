struct AppUtils {
    static func relativeTime(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        formatter.locale = LanguageManager.shared.locale
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    static func getTimeDisplay(callDuration: Int) -> String {
        let total = callDuration
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60

        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }

    static func validUrlApp(_ url: URL) -> Bool { // true is PASS
        // Deep link format: myapp://contact/{token}
        if url.scheme == AppConfig.schema && url.host == "contact" {
            return true
        }

        // Universal link: {domain}/share/contact/{token}
        if url.scheme == "https",
           AppUtils.isValidConfiguredHost(url.host),
           url.path.hasPrefix("/share/contact/") {
            return true
        }

        return false
    }

    /// Validate that the provided host matches the configured host from Endpoints.shared.shareURL
    static func isValidConfiguredHost(_ host: String?) -> Bool {
        guard let host = host,
              let expectedHost = URL(string: Endpoints.shared.shareURL)?.host else {
            return false
        }
        return host.caseInsensitiveCompare(expectedHost) == .orderedSame
    }

    static func formatPhoneNumber(_ raw: String) -> String {
        let phoneFormatterUtility = PhoneNumberUtility()

        guard !raw.isEmpty else { return "" }
        do {
            let phone = try phoneFormatterUtility.parse(raw)
            return phoneFormatterUtility.format(phone, toType: .international, withPrefix: true)
        } catch {
            return raw
        }
    }

    static func copy(_ text: String) {
        UIPasteboard.general.string = text
        ToastManager.shared.success(KeyLocalized.copied)
    }
    
    /// Get the app display name from Info.plist (CFBundleDisplayName)
    static var appDisplayName: String {
        if let displayName = Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String {
            return displayName
        }
        // Fallback to CFBundleName if CFBundleDisplayName is not set
        if let bundleName = Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String {
            return bundleName
        }
        // Final fallback
        return "MyApp"
    }
}
