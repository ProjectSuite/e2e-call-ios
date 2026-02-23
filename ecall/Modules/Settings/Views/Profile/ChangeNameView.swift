import SwiftUI

struct ChangeNameView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var appState: AppState

    @State private var name: String = ""
    @State private var isLoading = false
    @State private var isNameValid: Bool = true
    @State private var showError: Bool = false
    @State private var errorMessage: String = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // Content
                VStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        TextField(KeyLocalized.name, text: $name)
                            .textFieldStyle(LargeTextFieldStyle())
                            .textInputAutocapitalization(.words)
                            .autocorrectionDisabled(true)
                            .clearButton(text: $name)
                            .onChange(of: name) { newValue in
                                isNameValid = validateName(newValue)
                                clearError()
                            }

                        if showError {
                            Text(errorMessage)
                                .font(.caption)
                                .foregroundColor(.red)
                                .padding(.leading, 4)
                        }

                        if !isNameValid {
                            Text(getValidationErrorMessage())
                                .font(.caption)
                                .foregroundColor(.red)
                        }

                        Text("\(name.count)/\(AppConfig.maximumNameLength)")
                            .font(.caption)
                            .foregroundColor(.gray)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }

                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.top, 20)

                saveButton
                    .padding(.horizontal, 16)
                    .padding(.bottom, 32)
            }
            .navigationTitle(KeyLocalized.change_display_name)
            .navigationBarTitleDisplayMode(.inline)
        }
        .logViewName()
    }

    private var saveButton: some View {
        Button(action: saveName) {
            HStack {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                }
                Text(KeyLocalized.save)
                    .font(.system(size: 16, weight: .semibold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(isNameValid && !name.isEmpty ? Color.blue : Color.gray)
            .cornerRadius(8)
        }
        .disabled(!isNameValid || name.isEmpty || isLoading)
    }

    private func saveName() {
        guard isNameValid && !name.isEmpty else { return }

        isLoading = true

        UserService.shared.updateUser(displayName: name) { data, error in
            Task { @MainActor in
                isLoading = false

                if data != nil { // success
                    appState.updateDisplayName(name)
                    dismiss()
                    ToastManager.shared.success(KeyLocalized.change_info_success)
                } else {
                    self.showErrorMessage(error?.content ?? KeyLocalized.unknown_error_try_again)
                }
            }
        }
    }

    private func showErrorMessage(_ message: String) {
        errorMessage = message
        showError = true
    }

    private func clearError() {
        showError = false
        errorMessage = ""
    }

    private func validateName(_ name: String) -> Bool {
        // Check length
        guard name.count <= AppConfig.maximumNameLength else { return false }

        // Check for invalid characters that can break URL parsing
        // Now that we use Base64 encoding, we can allow most characters
        // Only restrict characters that could break the token format
        let invalidCharacters = CharacterSet(charactersIn: ":")
        return name.rangeOfCharacter(from: invalidCharacters) == nil
    }

    private func getValidationErrorMessage() -> String {
        if name.count > AppConfig.maximumNameLength {
            return "\(KeyLocalized.name) \(KeyLocalized.must_be_less_than) \(AppConfig.maximumNameLength) \(KeyLocalized.characters)"
        } else if name.rangeOfCharacter(from: CharacterSet(charactersIn: ":")) != nil {
            return KeyLocalized.name_cannot_contain_colon
        }
        return ""
    }
}

#Preview {
    ChangeNameView()
}
