import SwiftUI
import UIKit

struct CountryPickerView: View {
    @Binding var selectedCountry: CountryCodePickerViewController.Country?
    @State private var showPicker = false

    var body: some View {
        Button {
            showPicker = true
        } label: {
            HStack {
                if let country = selectedCountry {
                    if !country.flag.isEmpty {
                        Text(country.flag)
                            .font(.system(size: 24))
                    }
                    Text(country.name)
                        .foregroundColor(.primary)
                        .font(.system(size: 17))
                } else {
                    Text(KeyLocalized.country)
                        .foregroundColor(.secondary)
                        .font(.system(size: 17))
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
                    .font(.system(size: 14, weight: .medium))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(.systemGray6))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
            )
        }
        .frame(height: 52)
        .sheet(isPresented: $showPicker) {
            CountryCodePickerViewControllerRepresentable(
                selectedCountry: $selectedCountry,
                isPresented: $showPicker
            )
        }
    }
}

struct CountryCodePickerViewControllerRepresentable: UIViewControllerRepresentable {
    @Binding var selectedCountry: CountryCodePickerViewController.Country?
    @Binding var isPresented: Bool

    func makeUIViewController(context: Context) -> UINavigationController {
        let utility = PhoneNumberUtility()
        let options = CountryCodePickerOptions(
            textLabelFont: UIFont.systemFont(ofSize: 15, weight: .regular),
            detailTextLabelFont: UIFont.systemFont(ofSize: 17, weight: .medium)
        )
        let picker = CountryCodePickerViewController(
            utility: utility,
            options: options
        )
        picker.delegate = context.coordinator
        let nav = UINavigationController(rootViewController: picker)
        let closeButton = UIBarButtonItem(barButtonSystemItem: .close, target: context.coordinator, action: #selector(Coordinator.dismiss))
        picker.navigationItem.leftBarButtonItem = closeButton
        return nav
    }

    func updateUIViewController(_ uiViewController: UINavigationController, context: Context) { }

    func makeCoordinator() -> Coordinator {
        Coordinator(selectedCountry: $selectedCountry, isPresented: $isPresented)
    }

    final class Coordinator: NSObject, CountryCodePickerDelegate {
        @Binding var selectedCountry: CountryCodePickerViewController.Country?
        @Binding var isPresented: Bool

        init(selectedCountry: Binding<CountryCodePickerViewController.Country?>, isPresented: Binding<Bool>) {
            _selectedCountry = selectedCountry
            _isPresented = isPresented
        }

        func countryCodePickerViewControllerDidPickCountry(_ country: CountryCodePickerViewController.Country) {
            selectedCountry = country
            isPresented = false
        }

        @objc func dismiss() {
            isPresented = false
        }
    }
}
