import SwiftUI

struct DeleteAccountView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var appState: AppState

    @State private var confirmText: String = ""
    @State private var isLoading: Bool = false
    @State private var errorMessage: String = ""
    @State private var showError: Bool = false
    @State private var showLogoutConfirmation: Bool = false

    @FocusState private var isTextFieldFocused: Bool

    private let requiredConfirmText = "DELETE"

    /// Optional callback when cancel deletion succeeds (used from login flow)
    var onCancelDeletionSuccess: (() -> Void)?

    /// Whether the account is pending deletion (driven by server `deletedAt`)
    private var isPendingDeletion: Bool {
        appState.deletedAt != nil
    }

    /// Format deletion date for display
    private var formattedDeletionDate: String {
        guard let date = appState.deletedAt else { return "" }
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .short
        formatter.locale = LanguageManager.shared.locale
        return formatter.string(from: date)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if isPendingDeletion {
                    pendingDeletionContent
                } else {
                    confirmationContent
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    // Only show Cancel button when NOT pending deletion
                    if !isPendingDeletion {
                        Button(KeyLocalized.cancel) {
                            dismiss()
                        }
                        .disabled(isLoading)
                    }
                }
            }
            .alert(KeyLocalized.confirm_logout, isPresented: $showLogoutConfirmation) {
                Button(KeyLocalized.confirm, role: .destructive) {
                    appState.logout()
                }
                Button(KeyLocalized.cancel, role: .cancel) { }
            } message: {
                Text(KeyLocalized.logout_confirmation_message)
            }
        }
        .interactiveDismissDisabled(true)
    }

    // MARK: - State A: Confirmation

    private var confirmationContent: some View {
        VStack(spacing: 24) {
            Spacer().frame(height: 20)

            // Trash icon in red rounded square
            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.red.opacity(0.15))
                    .frame(width: 80, height: 80)

                Image(systemName: "trash.fill")
                    .font(.system(size: 36))
                    .foregroundColor(.red)
            }

            // Title
            Text(KeyLocalized.delete_account_title)
                .font(.title2.bold())
                .multilineTextAlignment(.center)

            // Description
            Text(KeyLocalized.delete_account_description)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            // Confirm text field
            TextField(KeyLocalized.delete_account_confirm_placeholder, text: $confirmText)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled(true)
                .focused($isTextFieldFocused)
                .padding(.horizontal, 32)
                .onChange(of: confirmText) { _ in
                    if showError { showError = false }
                }

            if showError {
                Text(errorMessage)
                    .font(.body)
                    .foregroundColor(.red)
                    .padding(.horizontal, 32)
            }

            // Delete button
            Button(action: {
                performDeleteAccount()
            }) {
                HStack {
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Image(systemName: "trash.fill")
                        Text(KeyLocalized.delete)
                    }
                }
                .font(.system(size: 17, weight: .semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(confirmText == requiredConfirmText ? Color.red : Color.gray.opacity(0.4))
                .foregroundColor(.white)
                .cornerRadius(14)
            }
            .disabled(confirmText != requiredConfirmText || isLoading)
            .padding(.horizontal, 24)
            
            Spacer()
        }
    }

    // MARK: - State B: Pending Deletion

    private var pendingDeletionContent: some View {
        VStack(spacing: 24) {
            Spacer().frame(height: 20)

            // Warning icon
            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.orange.opacity(0.15))
                    .frame(width: 80, height: 80)

                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 36))
                    .foregroundColor(.orange)
            }

            // Title
            Text(KeyLocalized.delete_account_warning_title)
                .font(.title2.bold())
                .multilineTextAlignment(.center)

            // Body
            Text(KeyLocalized.delete_account_warning_body)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            // Effective deletion date
            if appState.deletedAt != nil {
                VStack(spacing: 6) {
                    HStack(spacing: 8) {
                        Image(systemName: "calendar.badge.clock")
                            .foregroundColor(.red)
                        Text(KeyLocalized.delete_account_effective_date)
                            .font(.subheadline)
                            .foregroundColor(.red)
                    }
                    Text(formattedDeletionDate)
                        .font(.subheadline.bold())
                        .foregroundColor(.red)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.red.opacity(0.08))
                )
                .padding(.horizontal, 24)
            }

            if showError {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(.horizontal, 32)
            }

            // Cancel deletion button
            Button(action: {
                performCancelDeletion()
            }) {
                HStack {
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Image(systemName: "arrow.uturn.backward")
                        Text(KeyLocalized.delete_account_cancel_request)
                    }
                }
                .font(.system(size: 17, weight: .semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.orange)
                .foregroundColor(.white)
                .cornerRadius(14)
            }
            .disabled(isLoading)
            .padding(.horizontal, 24)

            // Logout button
            Button(action: {
                showLogoutConfirmation = true
            }) {
                HStack {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                    Text(KeyLocalized.logout)
                }
                .font(.system(size: 17, weight: .semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.red)
                .foregroundColor(.white)
                .cornerRadius(14)
            }
            .disabled(isLoading)
            .padding(.horizontal, 24)
            
            Spacer()
        }
    }

    // MARK: - Actions

    private func performDeleteAccount() {
        errorMessage = ""
        isLoading = true
        
        Task {
            let result = await UserService.shared.deleteAccount()
            await MainActor.run {
                isLoading = false
                switch result {
                case .success(let response):
                    // Set immediately to avoid gap time waiting for fetchCurrentUserInfo
                    appState.deletedAt = response.deletedAt
                case .failure(let error):
                    errorMessage = error.content
                    showError = true
                }
            }
        }
    }

    private func performCancelDeletion() {
        errorMessage = ""
        isLoading = true
        
        Task {
            let result = await UserService.shared.cancelDeleteAccount()
            await MainActor.run {
                isLoading = false
                switch result {
                case .success:
                    appState.deletedAt = nil
                    if let onCancelDeletionSuccess {
                        onCancelDeletionSuccess()
                    } else {
                        dismiss()
                    }
                    ToastManager.shared.success(KeyLocalized.delete_account_cancel_success)
                case .failure(let error):
                    errorMessage = error.content
                    showError = true
                }
            }
        }
    }
}

#Preview {
    DeleteAccountView()
}
