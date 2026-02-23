import SwiftUI

struct LargeTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<_Label>) -> some View {
        configuration
            .font(.title3)                                // Bigger text
            .padding(.horizontal, 12)                     // Horizontal padding
            .padding(.vertical, 12)                       // Vertical padding
            .background(RoundedRectangle(cornerRadius: 8)
                            .fill(Color(.systemGray6)))    // Background style
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
            )
    }
}
