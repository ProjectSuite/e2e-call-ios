import SwiftUI

struct CountryPhoneInputSection: View {
    @Binding var fullPhoneNumber: String
    var onPhoneAvailabilityChanged: ((Bool) -> Void)?

    @State private var countryCode: String = "+84"
    @State private var localPhoneNumber: String = ""
    @State private var selectedCountry: CountryCodePickerViewController.Country?
    @State private var isUpdatingFromPicker = false

    private let utility = PhoneNumberUtility()

    var body: some View {
        VStack(spacing: 16) {
            CountryPickerView(selectedCountry: $selectedCountry)

            PhoneNumberInputView(
                countryCode: $countryCode,
                phoneNumber: $localPhoneNumber,
                onCountryCodeChanged: { newCode in
                    guard !isUpdatingFromPicker else { return }
                    detectCountry(from: newCode)
                    updateFullPhoneNumber()
                },
                onPhoneNumberChanged: { _ in
                    updateFullPhoneNumber()
                },
                shouldFocusPhoneNumber: selectedCountry != nil,
                hasValidCountry: selectedCountry != nil,
                countryRegionCode: selectedCountry?.code,
                autoFocusOnAppear: true
            )
        }
        .onAppear {
            initializeDefaultCountry()
        }
        .onChange(of: selectedCountry) { newCountry in
            guard let newCountry else {
                notifyAvailability()
                return
            }
            isUpdatingFromPicker = true
            countryCode = newCountry.prefix
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isUpdatingFromPicker = false
            }
            updateFullPhoneNumber()
        }
        .onChange(of: countryCode) { newCode in
            guard !isUpdatingFromPicker else { return }
            detectCountry(from: newCode)
            updateFullPhoneNumber()
        }
    }

    private func initializeDefaultCountry() {
        let defaultRegion = PhoneNumberUtility.defaultRegionCode()
        if let defaultCountry = CountryCodePickerViewController.Country(for: defaultRegion, with: utility) {
            selectedCountry = defaultCountry
            countryCode = defaultCountry.prefix
        } else if let regionCode = Locale.current.region?.identifier,
                  let fallbackCountry = CountryCodePickerViewController.Country(for: regionCode, with: utility) {
            selectedCountry = fallbackCountry
            countryCode = fallbackCountry.prefix
        }
    }

    private func normalizeFullPhone(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("+") {
            return trimmed
        }
        return "+" + trimmed
    }

    private func splitFallback(_ value: String) {
        guard value.hasPrefix("+") else {
            localPhoneNumber = value.filter { $0.isNumber }
            selectedCountry = nil
            return
        }
        let digits = String(value.dropFirst())
        for length in stride(from: min(3, digits.count), through: 1, by: -1) {
            let prefix = String(digits.prefix(length))
            if let codeValue = UInt64(prefix),
               let country = utility.mainCountry(forCode: codeValue)
                .flatMap({ CountryCodePickerViewController.Country(for: $0, with: utility) }) {
                selectedCountry = country
                countryCode = "+\(codeValue)"
                localPhoneNumber = String(digits.dropFirst(length))
                return
            }
        }
        localPhoneNumber = digits
        selectedCountry = nil
    }

    private func detectCountry(from code: String) {
        guard code.hasPrefix("+") else {
            selectedCountry = nil
            notifyAvailability()
            return
        }

        let numericCode = String(code.dropFirst())
        guard let codeValue = UInt64(numericCode), codeValue > 0 else {
            selectedCountry = nil
            notifyAvailability()
            return
        }

        if let regionCode = utility.mainCountry(forCode: codeValue),
           let country = CountryCodePickerViewController.Country(for: regionCode, with: utility) {
            selectedCountry = country
        } else {
            selectedCountry = nil
        }
        notifyAvailability()
    }

    private func updateFullPhoneNumber() {
        let digitsOnly = localPhoneNumber.filter { $0.isNumber }
        guard !digitsOnly.isEmpty else {
            fullPhoneNumber = ""
            notifyAvailability()
            return
        }
        let cleanCountry = countryCode.trimmingCharacters(in: .whitespacesAndNewlines)
        let combined = (cleanCountry + digitsOnly).components(separatedBy: .whitespacesAndNewlines).joined()
        fullPhoneNumber = combined
        notifyAvailability()
    }

    private func notifyAvailability() {
        let isAvailable = selectedCountry != nil && !localPhoneNumber.isEmpty
        onPhoneAvailabilityChanged?(isAvailable)
    }
}
