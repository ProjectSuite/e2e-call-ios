import Foundation

struct VerifyResponse: Decodable {
    let accessToken: String?
    let refreshToken: String?
    let deviceId: UInt64?
    let deletedAt: Date?
}
