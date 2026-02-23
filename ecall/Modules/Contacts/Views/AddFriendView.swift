import SwiftUI
import Photos

struct AddFriendView: View {
    @EnvironmentObject var languageManager: LanguageManager
    @Environment(\.dismiss) var dismiss
    @StateObject private var viewModel = AddFriendViewModel()
    @State private var showImagePicker = false

    init(initialKey: String? = nil, displayName: String? = nil) {
        let vm = AddFriendViewModel()
        if let data = initialKey {
            vm.friendAddMode = .autoImport
            vm.importedQRPayload = data
        }

        if let data = displayName {
            vm.importedDisplayName = data
        }

        _viewModel = StateObject(wrappedValue: vm)
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {

                switch viewModel.friendAddMode {
                case .scan:
                    ScanSectionView(viewModel: viewModel) {
                        requestPhotoAccess()
                    }
                case .autoImport:
                    AutoImportSectionView(viewModel: viewModel)
                }

                // "Add Friend" button
                if viewModel.hasValidUserId {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.seal.fill").foregroundColor(.green)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(KeyLocalized.user_name)
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(viewModel.displayName ?? viewModel.userId ?? "")
                                .font(.body)
                                .fontWeight(.medium)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                        Spacer()
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.systemGray6))
                    )

                    Button {
                        viewModel.sendFriendRequest { isSuccess in
                            if isSuccess {
                                dismiss()
                                ToastManager.shared.success(KeyLocalized.friend_request_sent_success)
                            }
                        }
                    } label: {
                        Text(KeyLocalized.add_friend_button)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.green)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                }

                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                }

                Spacer()
            }
            .padding()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(KeyLocalized.cancel) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .principal) {
                    Text(KeyLocalized.add_friend_title)
                        .font(.headline)
                }
            }
            .sheet(
                isPresented: $showImagePicker,
                onDismiss: {
                    // Only process the QR code when the user actually selects an image
                    guard viewModel.selectedImage != nil else { return }
                    viewModel.clearError()
                    viewModel.processSelectedImage()
                },
                content: {
                    PhotoPicker(selectedImage: $viewModel.selectedImage)
                }
            )
        }
        .logViewName()
        .onChange(of: viewModel.importedQRPayload) { _ in
            viewModel.clearError()
        }
    }

    // MARK: - Sections
    struct ScanSectionView: View {
        @ObservedObject var viewModel: AddFriendViewModel
        let onTapUpload: () -> Void

        var body: some View {
            VStack(spacing: 12) {
                Text(KeyLocalized.qr_scan_hint)
                    .font(.footnote)
                    .multilineTextAlignment(.center)

                QRScannerView(scannedKey: $viewModel.scannedQRPayload, onDismiss: {
                    viewModel.validateAndSetQRPayload(viewModel.scannedQRPayload)

                }, onScanAgain: {
                    viewModel.clearError()
                    viewModel.clearScannedData()
                })
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.9), lineWidth: 2))
                .shadow(radius: 4)
                .frame(height: 300)

                Button(action: onTapUpload) {
                    HStack(spacing: 8) {
                        Image(systemName: "photo.on.rectangle")
                        Text(KeyLocalized.upload_qr_scan)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color(.systemGray6))
                    .foregroundColor(.primary)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
        }
    }

    struct AutoImportSectionView: View {
        @ObservedObject var viewModel: AddFriendViewModel

        var body: some View {
            VStack(spacing: 12) {
                if viewModel.importedQRPayload.isEmpty {
                    Spacer()
                    Text(KeyLocalized.no_public_key_yet)
                        .foregroundColor(.gray)
                }
            }
        }
    }

    // MARK: - Permissions
    private func requestPhotoAccess() {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        switch status {
        case .authorized, .limited:
            showImagePicker = true
        case .notDetermined:
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { newStatus in
                DispatchQueue.main.async {
                    if newStatus == .authorized || newStatus == .limited {
                        showImagePicker = true
                    } else {
                        viewModel.showErrorMessage(KeyLocalized.unauthorized)
                    }
                }
            }
        default:
            viewModel.showErrorMessage(KeyLocalized.unauthorized)
        }
    }
}

struct AddFriendView_Previews: PreviewProvider {
    static var previews: some View {
        AddFriendView()
            .environmentObject(LanguageManager())
    }
}
