import SwiftUI

extension String {
    var toInt: Int {
        return Int(self) ?? 0
    }

    var toDouble: Double {
        return Double(self) ?? 0.0
    }
}

extension String {
    var hexColor: Color {
        return Color(hex: self)
    }

    var isNotEmpty: Bool {
        return !isEmpty
    }
}
