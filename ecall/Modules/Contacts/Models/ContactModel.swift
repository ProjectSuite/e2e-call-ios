import SwiftUI

struct EmptyResponse: Codable {}

struct ContactsResponse: Codable {
    let contacts: [Contact]
}

struct ToggleFavoriteResponse: Codable {
    let status: String
}

struct DeleteContactResponse: Codable {
    let status: String
}

struct SendFriendRequestResponse: Codable {
    let status: String
}

struct GetFriendRequestResponse: Codable {
    let friendRequests: [FriendRequest]
}

struct Contact: Codable, Identifiable {
    var id: UInt64?
    var userId: UInt64
    var contactId: UInt64
    var contactName: String
    var isBlocked: Bool
    var isFavorite: Bool
    var lastInteraction: Date?

    enum CodingKeys: String, CodingKey {
        case id, userId, contactId, contactName, isFavorite, isBlocked, lastInteraction
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UInt64.self, forKey: .id)
        userId = try container.decodeIfPresent(UInt64.self, forKey: .userId) ?? 0
        contactId = try container.decodeIfPresent(UInt64.self, forKey: .contactId) ?? 0
        contactName = try container.decodeIfPresent(String.self, forKey: .contactName) ?? ""
        isBlocked = try container.decodeIfPresent(Bool.self, forKey: .isBlocked) ?? false
        isFavorite = try container.decodeIfPresent(Bool.self, forKey: .isFavorite) ?? false
        lastInteraction = try container.decodeIfPresent(Date.self, forKey: .lastInteraction)
    }
}
