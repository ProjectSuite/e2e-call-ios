import SwiftUI

struct DevicesResponse: Codable {
    let devices: [Device]
}

struct Device: Codable, Identifiable {
    var id: Int
    var userId: Int
    var deviceName: String
    var systemName: String
    var systemVersion: String
    var identifier: String
    var ip: String
    var location: String
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id, userId, deviceName, systemName, systemVersion, identifier, ip, location, updatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        userId = try container.decodeIfPresent(Int.self, forKey: .userId) ?? 0
        deviceName = try container.decodeIfPresent(String.self, forKey: .deviceName) ?? ""
        systemName = try container.decodeIfPresent(String.self, forKey: .systemName) ?? ""
        systemVersion = try container.decodeIfPresent(String.self, forKey: .systemVersion) ?? ""
        identifier = try container.decodeIfPresent(String.self, forKey: .identifier) ?? ""
        ip = try container.decodeIfPresent(String.self, forKey: .ip) ?? ""
        location = try container.decodeIfPresent(String.self, forKey: .location) ?? ""
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? Date()
    }
}
