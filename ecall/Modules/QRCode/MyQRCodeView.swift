import SwiftUI
import Photos

struct MyQRCodeView: View {
    @Binding var showQRCodePopup: Bool
    @StateObject private var viewModel = MyQRCodeViewModel()
    @State private var showShareQRSheet: Bool = false
    @State private var showSaveSuccessToast: Bool = false
    @State private var copyButtonIsCopied: Bool = false
    @State private var scanLineOffset: CGFloat = 0

    // Color palette
    private var primaryGradient: LinearGradient {
        LinearGradient(
            colors: [Color(hex: "06B6D4"), Color(hex: "3B82F6")],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var backgroundColor: Color { Color(hex: "F0FDFA") }
    private var cardBackground: Color { Color.white }
    private var textPrimary: Color { Color(hex: "0F172A") }
    private var textSecondary: Color { Color(hex: "64748B") }

    var body: some View {
        ZStack {
            backgroundColor.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                headerView

                // Profile Section
                profileSection

                // My QR content
                myQRContent
            }

            // Toast notification
            if showSaveSuccessToast {
                saveSuccessToast
            }
        }
        .onAppear {
            startScanLineAnimation()
        }
        .sheet(isPresented: $showShareQRSheet) {
            if let qrImage = viewModel.generateQRCode() {
                ShareSheet(activityItems: [qrImage])
                    .presentationDetents([.fraction(0.5), .large])
                    .presentationDragIndicator(.visible)
            }
        }
        .logViewName()
    }

    // MARK: - Header View
    private var headerView: some View {
        HStack {
            Button {
                showQRCodePopup = false
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundColor(textSecondary)
            }
            .accessibilityLabel("Close")
            .accessibilityHint("Closes the QR code screen")

            Spacer()

            Text(KeyLocalized.my_qr_title)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(textPrimary)

            Spacer()

            // Invisible button for balance
            Button { } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundColor(.clear)
            }
            .disabled(true)
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
    }

    // MARK: - Profile Section
    private var profileSection: some View {
        VStack(spacing: 12) {
            let displayName = viewModel.displayName

            // Avatar
            ZStack {
                SmartAvatarView(
                    url: nil,
                    name: displayName,
                    size: 80
                )
            }

            Text(displayName)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(textPrimary)
        }
        .padding(.vertical, 16)
    }

    // MARK: - My QR Content
    private var myQRContent: some View {
        ScrollView {
            VStack(spacing: 24) {
                // QR Code Card
                qrCodeCard

                // Action Buttons
                actionButtons

                // Link Section
                linkSection
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 32)
        }
    }

    // MARK: - QR Code Card
    private var qrCodeCard: some View {
        VStack(spacing: 16) {
            ZStack {
                // Card background
                RoundedRectangle(cornerRadius: 24)
                    .fill(cardBackground)
                    .shadow(color: Color.gray.opacity(0.2), radius: 16, x: 0, y: 8)

                VStack(spacing: 20) {
                    // QR Code with corner decorations
                    ZStack {
                        if let qrImage = viewModel.generateQRCode() {
                            // QR Code
                            Image(uiImage: qrImage)
                                .interpolation(.none)
                                .resizable()
                                .frame(width: 180, height: 180)
                                .cornerRadius(12)
                                .overlay(
                                    // Scan line animation
                                    scanLineOverlay
                                )
                                .overlay(
                                    // Corner frame decorations
                                    cornerFrames
                                )
                                .overlay(
                                    // Logo overlay
                                    logoOverlay
                                )
                                .accessibilityLabel(KeyLocalized.qr_scan_to_add.replacingOccurrences(of: "%@", with: viewModel.displayName.isEmpty ? KeyLocalized.user_placeholder : viewModel.displayName))
                                .accessibilityHint(KeyLocalized.qr_scan_to_add.replacingOccurrences(of: "%@", with: viewModel.displayName.isEmpty ? KeyLocalized.user_placeholder : viewModel.displayName))
                        } else {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.gray.opacity(0.2))
                                .frame(width: 180, height: 180)
                                .overlay(
                                    Text(KeyLocalized.qr_unavailable)
                                        .font(.system(size: 13))
                                        .foregroundColor(textSecondary)
                                )
                        }
                    }
                    .frame(width: 200, height: 200)

                    // Caption
                    Text(String(format: KeyLocalized.qr_scan_to_add, viewModel.displayName.isEmpty ? KeyLocalized.user_placeholder : viewModel.displayName))
                        .font(.system(size: 13, weight: .regular))
                        .foregroundColor(textSecondary)
                }
                .padding(24)
            }
        }
    }

    // MARK: - Corner Frame Decorations
    private var cornerFrames: some View {
        GeometryReader { geo in
            ZStack {
                // Top-left corner
                Path { path in
                    path.move(to: CGPoint(x: 0, y: 12))
                    path.addLine(to: CGPoint(x: 0, y: 0))
                    path.addLine(to: CGPoint(x: 12, y: 0))
                }
                .stroke(Color(hex: "06B6D4"), lineWidth: 3)

                // Top-right corner
                Path { path in
                    path.move(to: CGPoint(x: geo.size.width - 12, y: 0))
                    path.addLine(to: CGPoint(x: geo.size.width, y: 0))
                    path.addLine(to: CGPoint(x: geo.size.width, y: 12))
                }
                .stroke(Color(hex: "06B6D4"), lineWidth: 3)

                // Bottom-left corner
                Path { path in
                    path.move(to: CGPoint(x: 0, y: geo.size.height - 12))
                    path.addLine(to: CGPoint(x: 0, y: geo.size.height))
                    path.addLine(to: CGPoint(x: 12, y: geo.size.height))
                }
                .stroke(Color(hex: "06B6D4"), lineWidth: 3)

                // Bottom-right corner
                Path { path in
                    path.move(to: CGPoint(x: geo.size.width - 12, y: geo.size.height))
                    path.addLine(to: CGPoint(x: geo.size.width, y: geo.size.height))
                    path.addLine(to: CGPoint(x: geo.size.width, y: geo.size.height - 12))
                }
                .stroke(Color(hex: "06B6D4"), lineWidth: 3)
            }
        }
    }

    // MARK: - Logo Overlay
    private var logoOverlay: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10)
                .fill(primaryGradient)
                .frame(width: 40, height: 40)
                .shadow(color: Color(hex: "06B6D4").opacity(0.4), radius: 8)

            // App logo or initials
            Image(systemName: "shield.checkered")
                .resizable()
                .scaledToFit()
                .frame(width: 22, height: 22)
                .foregroundColor(.white)
        }
        .accessibilityLabel("\(AppUtils.appDisplayName) app logo")
    }

    // MARK: - Scan Line Overlay
    private var scanLineOverlay: some View {
        GeometryReader { _ in
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [Color(hex: "06B6D4").opacity(0.3), Color(hex: "06B6D4").opacity(0.1)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(height: 2)
                .offset(y: scanLineOffset)
        }
    }

    // MARK: - Action Buttons
    private var actionButtons: some View {
        HStack(spacing: 12) {
            // Share Button
            Button {
                showShareQRSheet = true
            } label: {
                HStack {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 16, weight: .semibold))
                    Text(KeyLocalized.qr_share_button)
                        .font(.system(size: 14, weight: .semibold))
                }
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(primaryGradient)
                .foregroundColor(.white)
                .cornerRadius(14)
            }
            .accessibilityLabel("Share QR code")
            .accessibilityHint("Opens share sheet to share your QR code")

            Button {
                saveQRCodeToPhotos()
            } label: {
                HStack {
                    Image(systemName: "square.and.arrow.down")
                        .font(.system(size: 16, weight: .semibold))
                    Text(KeyLocalized.qr_save_button)
                        .font(.system(size: 14, weight: .semibold))
                }
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(Color(hex: "F1F5F9"))
                .foregroundColor(textPrimary)
                .cornerRadius(14)
            }
            .accessibilityLabel("Save QR code to Photos")
            .accessibilityHint("Saves your QR code image to the Photos app")
        }
    }

    // MARK: - Link Section
    private var linkSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            linkHeader

            linkContentRow
        }
        .padding(16)
        .background(cardBackground)
        .cornerRadius(16)
        .shadow(color: shadowColor, radius: 8, x: 0, y: 4)
    }

    private var linkHeader: some View {
        HStack {
            Image(systemName: "link")
                .font(.system(size: 16))
                .foregroundColor(textSecondary)

            Text(KeyLocalized.qr_invite_link_label)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(textSecondary)
        }
    }

    private var linkContentRow: some View {
        HStack(spacing: 8) {
            Text(linkDisplayText)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(textPrimary)
                .lineLimit(1)
                .truncationMode(.middle)

            Spacer()

            copyButton
        }
        .padding(12)
        .background(linkBackgroundColor)
        .cornerRadius(12)
    }
    
    private var linkDisplayText: String {
        viewModel.deepLink.isEmpty ? "\(Endpoints.shared.bundleURLScheme).app/u/..." : viewModel.deepLink
    }

    private var linkBackgroundColor: Color {
        Color(hex: "F1F5F9").opacity(0.5)
    }

    private var shadowColor: Color {
        Color.gray.opacity(0.1)
    }

    private var copyButton: some View {
        Button {
            copyLink()
        } label: {
            Text(copyButtonText)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(copyButtonBackground)
                .cornerRadius(8)
        }
        .accessibilityLabel(copyButtonText == "Copied!" ? "Link copied" : "Copy invite link")
        .accessibilityHint("Copies your invite link to clipboard")
    }

    private var copyButtonBackground: some View {
        Group {
            if copyButtonIsCopied {
                Color.green
            } else {
                primaryGradient
            }
        }
    }

    private var copyButtonText: String {
        copyButtonIsCopied ? KeyLocalized.qr_copy_button_copied : KeyLocalized.qr_copy_button_copy
    }

    // MARK: - Save Success Toast
    private var saveSuccessToast: some View {
        VStack {
            Spacer()
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.white)
                Text(KeyLocalized.qr_saved_to_photos)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Color.black.opacity(0.8))
            .cornerRadius(12)
            .padding(.bottom, 32)
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    // MARK: - Helper Functions
    private func startScanLineAnimation() {
        scanLineOffset = 0
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: false)) {
                scanLineOffset = 180
            }
        }
    }

    private func copyLink() {
        UIPasteboard.general.string = viewModel.deepLink

        // Haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()

        // Update button state
        withAnimation {
            copyButtonIsCopied = true
        }

        // Revert after 2 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation {
                copyButtonIsCopied = false
            }
        }
    }

    private func saveQRCodeToPhotos() {
        guard let qrImage = viewModel.generateQRCode() else { return }

        PHPhotoLibrary.requestAuthorization { status in
            guard status == .authorized else {
                debugLog("Photo library access denied")
                return
            }

            UIImageWriteToSavedPhotosAlbum(qrImage, nil, nil, nil)

            DispatchQueue.main.async {
                showSaveSuccessToast = true

                // Haptic feedback
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.success)

                // Hide toast after 2 seconds
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    withAnimation {
                        showSaveSuccessToast = false
                    }
                }
            }
        }
    }
}
