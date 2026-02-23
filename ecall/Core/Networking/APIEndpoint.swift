import Foundation

enum APIEndpoint {
    case wss
    case janus
    case appConfig
    case verifyUser
    case resendOTP
    case login
    case verifyLogin
    case appleLogin
    case logout
    case refreshToken
    case terminateSession(deviceId: String) // target terminate device
    case terminateOthers // case all device(without this device)
    case contact
    case friendRequest
    case friendRequestAccept
    case friendRequestCancel
    case friendRequestDecline
    case friendRequestSent
    case friendRequestReceived
    case contacts
    case devices
    case calls
    case callHistories
    case startCall
    case inviteToCall(id: String)
    case joinCall(id: String)
    case rejoinCall(id: String)
    case requestRejoinCall(id: String)
    case credentials
    case acceptCall
    case endCall
    case registerDevice
    case publicKeys
    case currentUser
    case updateUser
    case participants(id: String)
    case activeCall
    case deleteAccount
    case cancelDeleteAccount

    var path: String {
        switch self {
        case .wss: return "/ws/"
        case .janus: return "/janus"
        case .appConfig: return "/app/api/app-config"
        case .verifyUser: return "/app/api/verify"
        case .verifyLogin: return "/app/api/verify-login"
        case .resendOTP: return "/app/api/resend-otp"
        case .login: return "/app/api/login"
        case .appleLogin: return "/app/api/apple-login"
        case .logout: return "/app/api/logout"
        case .refreshToken: return "/app/api/refresh-token"
        case .terminateSession(let deviceId): return "/app/api/terminate-session/\(deviceId)"
        case .terminateOthers: return "/app/api/terminate-others"
        case .friendRequest: return "/app/api/friend-request"
        case .friendRequestAccept: return "/app/api/friend-request/accept"
        case .friendRequestCancel: return "/app/api/friend-request/cancel"
        case .friendRequestDecline: return "/app/api/friend-request/decline"
        case .friendRequestSent: return "/app/api/friend-request-sent"
        case .friendRequestReceived: return "/app/api/friend-request-received"
        case .contact: return "/app/api/contact"
        case .contacts: return "/app/api/contacts"
        case .devices: return "/app/api/devices"
        case .calls: return "/app/api/calls"
        case .callHistories: return "/app/api/calls/histories"
        case .startCall: return "/app/api/call/start"
        case .activeCall: return "/app/api/call/active"
        case .inviteToCall(let id): return "/app/api/call/\(id)/invite"
        case .joinCall(let id): return "/app/api/call/\(id)/join"
        case .rejoinCall(let id): return "/app/api/call/\(id)/rejoin"
        case .requestRejoinCall(let id): return "/app/api/call/\(id)/request-rejoin"
        case .participants(let id): return "/app/api/call/\(id)/participants"
        case .credentials: return "/app/api/credentials"
        case .acceptCall: return "/app/api/call/accept"
        case .endCall: return "/app/api/call/end"
        case .registerDevice: return "/app/api/register_device"
        case .publicKeys: return "/app/api/user/publicKeys"
        case .currentUser: return "/app/api/user"
        case .updateUser: return "/app/api/user"
        case .deleteAccount: return "/app/api/user"
        case .cancelDeleteAccount: return "/app/api/user/cancel-delete"
        }
    }

    var fullURLString: String {
        return Endpoints.shared.baseURL + path
    }

    var fullURL: URL {
        let urlString = Endpoints.shared.baseURL + path
        guard let url = URL(string: urlString) else {
            errorLog("❌ [CRITICAL] Invalid URL: \(urlString)")
            // Return a safe default URL to prevent crash
            return URL(string: "https://example.com") ?? URL(fileURLWithPath: "/")
        }
        return url
    }

    var fullSocketURL: URL {
        let urlString = Endpoints.shared.baseSocketURL + path
        guard let url = URL(string: urlString) else {
            errorLog("❌ [CRITICAL] Invalid Socket URL: \(urlString)")
            // Return a safe default URL to prevent crash
            return URL(string: "wss://example.com") ?? URL(fileURLWithPath: "/")
        }
        return url
    }

    var fullJanusSocketURL: URL {
        let urlString = Endpoints.shared.baseJanusSocketURL + path
        guard let url = URL(string: urlString) else {
            errorLog("❌ [CRITICAL] Invalid Janus Socket URL: \(urlString)")
            // Return a safe default URL to prevent crash
            return URL(string: "wss://example.com") ?? URL(fileURLWithPath: "/")
        }
        return url
    }
}
