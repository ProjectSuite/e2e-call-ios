extension String {
    var isValidPhoneNumber: Bool {
        // Remove all non-digit characters
        let digitsOnly = self.replacingOccurrences(of: "[^0-9]", with: "", options: .regularExpression)

        // Check if it's a valid phone number (at least 5 digits, max 20 digits)
        return digitsOnly.count >= 5 && digitsOnly.count <= 20
    }

    var isValidEmail: Bool {
        // Basic regex for email validation
        let emailRegEx = "^[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$"
        return NSPredicate(format: "SELF MATCHES %@", emailRegEx).evaluate(with: self)
    }
}
