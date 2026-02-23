import Foundation

extension Bundle {
    var releaseVersionNumber: String? {
        return infoDictionary?["CFBundleShortVersionString"] as? String
    }

    var buildVersionNumber: String? {
        return infoDictionary?["CFBundleVersion"] as? String
    }

    var displayVersion: String {
        let version = releaseVersionNumber ?? "1.0"
        let build = buildVersionNumber ?? "1"
        return "\(version) (\(build))"
    }
}
