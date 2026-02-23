import SwiftUI

enum PermissionType: CaseIterable, Identifiable {
    case microphone
    case camera
    case notifications
    case photos

    var id: String { key }

    var key: String {
        switch self {
        case .microphone: return "microphone"
        case .camera: return "camera"
        case .notifications: return "notifications"
        case .photos: return "photos"
        }
    }

    var title: String {
        switch self {
        case .microphone: return KeyLocalized.permissions_microphone_title
        case .camera: return KeyLocalized.permissions_camera_title
        case .notifications: return KeyLocalized.permissions_notifications_title
        case .photos: return KeyLocalized.permissions_photos_title
        }
    }

    var subtitle: String {
        switch self {
        case .microphone: return KeyLocalized.permissions_microphone_subtitle
        case .camera: return KeyLocalized.permissions_camera_subtitle
        case .notifications: return KeyLocalized.permissions_notifications_subtitle
        case .photos: return KeyLocalized.permissions_photos_subtitle
        }
    }

    var systemImageName: String {
        switch self {
        case .microphone: return "mic.fill"
        case .camera: return "video.fill"
        case .notifications: return "bell.fill"
        case .photos: return "photo.on.rectangle"
        }
    }

    var gradient: LinearGradient {
        switch self {
        case .microphone:
            return LinearGradient(
                colors: [Color(red: 1.0, green: 0.46, blue: 0.55),
                         Color(red: 0.99, green: 0.30, blue: 0.39)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .camera:
            return LinearGradient(
                colors: [Color(red: 0.23, green: 0.83, blue: 0.75),
                         Color(red: 0.11, green: 0.76, blue: 0.87)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .notifications:
            return LinearGradient(
                colors: [Color(red: 1.0, green: 0.72, blue: 0.38),
                         Color(red: 0.99, green: 0.57, blue: 0.26)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .photos:
            return LinearGradient(
                colors: [Color(red: 0.33, green: 0.70, blue: 0.98),
                         Color(red: 0.18, green: 0.52, blue: 0.93)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
}

enum PermissionStatus {
    case granted
    case denied
    case notDetermined
}

struct PermissionItem: Identifiable {
    let id = UUID()
    let type: PermissionType
    let status: PermissionStatus
}
