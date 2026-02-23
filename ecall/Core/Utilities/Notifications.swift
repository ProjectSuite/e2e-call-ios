import Foundation

extension Notification.Name {
    // Call notifications
    static let callDidEnd = Notification.Name("callDidEnd")
    static let callUserBusy = Notification.Name("callUserBusy")
    static let didAnswerCall = Notification.Name("didAnswerCall")
    static let didStartCall = Notification.Name("didStartCall")

    // Socket notifications
    static let janusSocketDidConnect = Notification.Name("janusSocketDidConnect")
    static let janusSocketDidReconnect = Notification.Name("janusSocketDidReconnect")
    static let janusSocketDidDisconnect = Notification.Name("janusSocketDidDisconnect")

    // System notifications
    static let webRTCRestartRequired = Notification.Name("webRTCRestartRequired")
    static let sessionExpiredRestartRequired = Notification.Name("sessionExpiredRestartRequired")
    static let networkPathDidChange = Notification.Name("networkPathDidChange")
    static let cryptoLogAppended = Notification.Name("cryptoLogAppended")

    // Tab switching notification
    static let switchToSettingsTab = Notification.Name("switchToSettingsTab")
    static let reloadCallHistory = Notification.Name("reloadCallHistory")

    // Profile change notification
    static let profileDidChange = Notification.Name("profileDidChange")

    // Friend Request change notification
    static let newFriendRequested = Notification.Name("newFriendRequested")
    static let acceptFriendRequested = Notification.Name("acceptFriendRequested")

    // Warning Login notification
    static let warningLoginNotificationTapped = Notification.Name("warningLoginNotificationTapped")

    // Participant call notifications
    static let participantRejected = Notification.Name("participantRejected")
    static let participantLeft = Notification.Name("participantLeft")
    static let participantJoined = Notification.Name("participantJoined")

}

/// Small box so we can remove the observer from inside the closure
private final class ObserverBox {
    var token: NSObjectProtocol?
}
