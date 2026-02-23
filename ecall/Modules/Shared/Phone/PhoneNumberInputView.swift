import SwiftUI

struct PhoneNumberInputView: View {
    @Binding var countryCode: String
    @Binding var phoneNumber: String
    var onCountryCodeChanged: ((String) -> Void)?
    var onPhoneNumberChanged: ((String) -> Void)?
    var shouldFocusPhoneNumber: Bool = false
    var hasValidCountry: Bool = true
    var countryRegionCode: String?
    var autoFocusOnAppear: Bool = false

    @FocusState private var isCountryCodeFocused: Bool
    @FocusState private var isPhoneNumberFocused: Bool
    @State private var displayPhoneNumber: String = ""

    private let phoneUtility = PhoneNumberUtility()

    private func formatPhoneNumber(_ digitsOnly: String) -> String {
        guard let region = countryRegionCode?.uppercased(), !digitsOnly.isEmpty else {
            return digitsOnly
        }

        let formatter = PartialFormatter(
            utility: phoneUtility,
            defaultRegion: region,
            withPrefix: false
        )

        return formatter.formatPartial(digitsOnly)
    }

    private func stripNonDigits(_ value: String) -> String {
        value.filter { $0.isNumber }
    }

    private func smoothFocusSwitch(toPhone: Bool) {
        withAnimation(.easeInOut(duration: 0.18)) {
            if toPhone {
                isCountryCodeFocused = false
                isPhoneNumberFocused = true
            } else {
                isPhoneNumberFocused = false
                isCountryCodeFocused = true
            }
        }
    }

    var body: some View {
        HStack(spacing: 0) {
            // Country code input (always starts with +)
            HStack(spacing: 0) {
                Text("+")
                    .foregroundColor(.primary)
                    .font(.system(size: 17))

                TextField("", text: Binding(
                    get: {
                        countryCode.hasPrefix("+") ? String(countryCode.dropFirst()) : countryCode
                    },
                    set: { newValue in
                        let numericOnly = newValue.filter { $0.isNumber }
                        let newCode = "+" + numericOnly
                        countryCode = newCode
                        onCountryCodeChanged?(newCode)
                    }
                ))
                .keyboardType(.numberPad)
                .textContentType(.none)
                .autocorrectionDisabled(true)
                .focused($isCountryCodeFocused)
                .font(.system(size: 17))
                .frame(maxWidth: 40)
            }
            .padding(.leading, 12)

            Divider()
                .frame(height: 20)
                .padding(.vertical, 8)
                .padding(.horizontal, 8)

            // Phone number input
            TextField(KeyLocalized.your_phone_number_placeholder, text: $displayPhoneNumber)
                .keyboardType(.numberPad)
                .textContentType(.telephoneNumber)
                .autocorrectionDisabled(true)
                .focused($isPhoneNumberFocused)
                .font(.system(size: 17))
                .onChange(of: shouldFocusPhoneNumber) { shouldFocus in
                    if shouldFocus && hasValidCountry {
                        smoothFocusSwitch(toPhone: true)
                    }
                }
                .onChange(of: isPhoneNumberFocused) { isFocused in
                    if isFocused && !hasValidCountry {
                        smoothFocusSwitch(toPhone: false)
                    }
                }
                .onChange(of: hasValidCountry) { isValid in
                    if isValid && isCountryCodeFocused {
                        smoothFocusSwitch(toPhone: true)
                    }
                }
        }
        .frame(height: 52)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.systemGray6))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
        )
        .onAppear {
            displayPhoneNumber = formatPhoneNumber(phoneNumber)
            if !countryCode.hasPrefix("+") {
                countryCode = "+" + countryCode
            }
            if autoFocusOnAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    smoothFocusSwitch(toPhone: true)
                }
            }
        }
        .onChange(of: countryCode) { newValue in
            if !newValue.hasPrefix("+") {
                countryCode = "+" + newValue
            }
        }
        .onChange(of: displayPhoneNumber) { newValue in
            let digitsOnly = stripNonDigits(newValue)
            if digitsOnly != phoneNumber {
                phoneNumber = digitsOnly
                onPhoneNumberChanged?(digitsOnly)
            }
            let formatted = formatPhoneNumber(digitsOnly)
            if formatted != newValue {
                displayPhoneNumber = formatted
            }
        }
        .onChange(of: phoneNumber) { newDigits in
            let formatted = formatPhoneNumber(newDigits)
            if formatted != displayPhoneNumber {
                displayPhoneNumber = formatted
            }
        }
    }
}
