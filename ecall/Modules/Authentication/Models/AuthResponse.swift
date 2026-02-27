struct AuthResponse: Decodable {
    let userId: UInt64?
    let deviceId: UInt64?
    let email: String?
    let phoneNumber: String?
    let displayName: String?
    let accessToken: String?
    let refreshToken: String?
    let deletedAt: Date?
    // Complete user fields (merged from completeRegistration)
    let publicKey: String?
}

struct RefreshTokenResponse: Decodable {
    let accessToken: String?
    let refreshToken: String?
}
