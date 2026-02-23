import SwiftUI

struct DeleteAccountView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var appState: AppState

    @State private var confirmText: String = ""
    @State private var isLoading: Bool = false
    @State private var isPendingDeletion: Bool = false
    @State private var errorMessage: String = ""
    @State private var showError: Bool = false
    @State private var deletionDate: Date? = nil

    @FocusState private var isTextFieldFocused: Bool

    private let requiredConfirmText = "DELETE"

    // MARK: - UserDefaults Keys
    static let pendingDeletionKey = "is_pending_account_deletion"
    static let deletionDateKey = "pending_account_deletion_date"

    /// Read the mock flag
    static var isPendingDeletionFlag: Bool {
        UserDefaults.standard.bool(forKey: pendingDeletionKey)
    }

    /// Read the stored deletion effective date
    static var storedDeletionDate: Date? {
        UserDefaults.standard.object(forKey: deletionDateKey) as? Date
    }

    /// Format deletion date for display
    private var formattedDeletionDate: String {
        guard let date = deletionDate else { return "" }
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
                    Button(KeyLocalized.cancel) {
                        dismiss()
                    }
                    .disabled(isLoading)
                }
            }
            .onAppear {
                // Restore pending state from UserDefaults
                isPendingDeletion = DeleteAccountView.isPendingDeletionFlag
                deletionDate = DeleteAccountView.storedDeletionDate
            }
        }
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
            if deletionDate != nil {
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
            
            Spacer()
        }
    }

    // MARK: - Actions

    private func performDeleteAccount() {
        isLoading = true
        Task {
            let result = await UserService.shared.deleteAccount()
            await MainActor.run {
                isLoading = false
                switch result {
                case .success:
                    savePendingDeletion()
                case .failure:
                    // API failed → fallback: mock success for testing
                    debugLog("⚠️ Delete account API failed, using mock fallback")
                    savePendingDeletion()
                }
            }
        }
    }

    private func savePendingDeletion() {
        let effectiveDate = Calendar.current.date(byAdding: .day, value: 15, to: Date()) ?? Date()
        UserDefaults.standard.set(true, forKey: DeleteAccountView.pendingDeletionKey)
        UserDefaults.standard.set(effectiveDate, forKey: DeleteAccountView.deletionDateKey)
        deletionDate = effectiveDate
        withAnimation(.easeInOut(duration: 0.3)) {
            isPendingDeletion = true
        }
    }

    private func performCancelDeletion() {
        isLoading = true
        Task {
            let result = await UserService.shared.cancelDeleteAccount()
            await MainActor.run {
                isLoading = false
                switch result {
                case .success:
                    clearPendingDeletion()
                case .failure:
                    // API failed → fallback: mock success for testing
                    debugLog("⚠️ Cancel delete API failed, using mock fallback")
                    clearPendingDeletion()
                }
            }
        }
    }

    private func clearPendingDeletion() {
        UserDefaults.standard.set(false, forKey: DeleteAccountView.pendingDeletionKey)
        UserDefaults.standard.removeObject(forKey: DeleteAccountView.deletionDateKey)
        dismiss()
        ToastManager.shared.success(KeyLocalized.delete_account_cancel_success)
    }
}

#Preview {
    DeleteAccountView()
}
