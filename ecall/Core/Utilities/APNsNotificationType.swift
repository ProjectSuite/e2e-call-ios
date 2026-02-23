import Foundation

/// APNs notification types for alert notifications (friend requests, warnings, etc.)
enum APNsNotificationType: String {
    case newFriendRequest
    case acceptFriendRequest
    case warningLogin
    case userInfoUpdate

    var title: String {
        switch self {
        case .userInfoUpdate:
            return KeyLocalized.notification_title
        case .newFriendRequest:
            return KeyLocalized.new_friend_request_title
        case .acceptFriendRequest:
            return KeyLocalized.friend_request_accepted_title // exist %@
        case .warningLogin:
            return KeyLocalized.warning_login_title
        }
    }

    var body: String {
        switch self {
        case .userInfoUpdate:
            return KeyLocalized.account_info_updated_message
        case .newFriendRequest:
            return KeyLocalized.new_friend_request_content // exist %@
        case .acceptFriendRequest:
            return KeyLocalized.friend_request_accepted_content // exist %@
        case .warningLogin:
            return KeyLocalized.warning_login_content
        }
    }
}
