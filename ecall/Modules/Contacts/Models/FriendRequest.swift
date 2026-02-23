import Foundation

struct FriendRequest: Codable, Identifiable {
    var id: UInt64
    var senderId: UInt64
    var receiverId: UInt64
    var status: String?
    var receiverName: String
    var date: String

    var createdAt: Date? {
        return DateFormatters.iso8601Fractional.date(from: date) ??
            DateFormatters.iso8601.date(from: date)
    }

    var dateDisplay: String {
        if let d = createdAt { return DateFormatters.timeShort.string(from: d) }
        return date
    }
}
