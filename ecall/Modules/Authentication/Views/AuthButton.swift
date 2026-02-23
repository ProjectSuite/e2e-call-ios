import SwiftUI

struct AuthButton: View {
    let title: String
    var systemImage: String?
    var customImage: Image?
    let disabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Group {
                    if let systemImage = systemImage {
                        Image(systemName: systemImage)
                            .resizable()
                            .frame(width: 18, height: 18)
                    } else if let customImage = customImage {
                        customImage
                            .resizable()
                            .frame(width: 18, height: 18)
                    }
                }
                .frame(width: 20, height: 20, alignment: .center)

                Text(title)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(disabled ? .gray : .black)
            }
            .foregroundColor(.black)
            .padding(.vertical, 12)
            .padding(.horizontal, 24)
            .frame(maxWidth: .infinity, alignment: .center)
            .overlay(
                Capsule()
                    .stroke(disabled ? Color.gray.opacity(0.4) : Color.gray.opacity(0.7), lineWidth: 1)
            )
        }
        .frame(maxWidth: .infinity)
    }
}
