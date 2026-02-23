import SwiftUI

struct SmartAvatarView: View {
    let url: URL?
    let name: String
    let size: CGFloat

    var body: some View {
        if let url = url {
            AsyncImage(url: url) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                LetterAvatarView(name: name, size: size)
            }
            .frame(width: size, height: size)
            .clipShape(Circle())
        } else {
            LetterAvatarView(name: name, size: size)
        }
    }
}

// MARK: LetterAvatarView
struct LetterAvatarView: View {
    let name: String
    let size: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .fill(backgroundColor)

            Text(initials)
                .font(.system(size: size * 0.45, weight: .bold))
                .foregroundColor(.white)
        }
        .frame(width: size, height: size)
    }

    private var backgroundColor: Color {
        let firstCharacter = extractFirstCharacter(from: name)
        let colorType = determineColorType(for: firstCharacter)
        return colorType.color
    }

    private var initials: String {
        let formatter = PersonNameComponentsFormatter()
        if let components = formatter.personNameComponents(from: name) {
            return extractInitialsFromComponents(components)
        }
        return extractFirstCharacter(from: name)
    }

    // MARK: - Private Helper Methods
    private func extractFirstCharacter(from name: String) -> String {
        return String(name.prefix(1)).uppercased()
    }

    private func determineColorType(for character: String) -> ColorType {
        return ColorType(fromRawValue: character)
    }

    private func extractInitialsFromComponents(_ components: PersonNameComponents) -> String {
        let initials = [
            components.givenName?.prefix(1),
            components.familyName?.prefix(1)
        ]
        .compactMap { $0 }
        .map { String($0) }
        .joined()

        return initials.isEmpty ? "?" : initials
    }
}
