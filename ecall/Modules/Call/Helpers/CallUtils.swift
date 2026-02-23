class CallUtils {
    /// Format participant display names:
    /// - 0 users: KeyLocalized.unknown
    /// - 1 user: "User 1"
    /// - 2 users: "User 1, User 2"
    /// - >=3 users: "User 1, User 2 & N other"
    static func formatParticipantsDisplayNames(
        _ participants: [Participant],
        maxCharactersPerName: Int = 15,
        truncationToken: String = "…"
    ) -> String {
        func trimmed(_ s: String) -> String {
            s.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        func limitPerName(_ name: String) -> String {
            let value = trimmed(name)
            guard maxCharactersPerName > 0 else { return value }
            guard value.count > maxCharactersPerName else { return value }

            // Reserve 1 char for truncation token when possible
            let available = max(0, maxCharactersPerName - truncationToken.count)
            guard available > 0 else { return String(truncationToken.prefix(maxCharactersPerName)) }
            return String(value.prefix(available)) + truncationToken
        }

        let names = participants
            .map { limitPerName($0.effectiveDisplayName) }
            .filter { !$0.isEmpty }

        if names.isEmpty { return KeyLocalized.unknown }
        if names.count == 1 { return names[0] }
        if names.count == 2 { return names[0] + ", " + names[1] }
        let others = names.count - 2
        return names[0] + ", " + names[1] + " & \(others) \(KeyLocalized.other_participant)"
    }

    /// Format date with "Today", "Yesterday" or formatted date
    static func formatDateWithRelativeDay(_ date: Date) -> String {
        let calendar = Calendar.current

        if calendar.isDateInToday(date) {
            return KeyLocalized.today
        } else if calendar.isDateInYesterday(date) {
            return KeyLocalized.yesterday
        } else {
            return DateFormatters.dateShort.string(from: date)
        }
    }
}
