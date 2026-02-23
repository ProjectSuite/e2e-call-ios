import SwiftUI
import LocalAuthentication

private enum KeySheetMode: Hashable { case key, logs }

struct KeyManagerSheetView: View {
    @Binding var isPresented: Bool
    @StateObject private var biometricAuth = BiometricAuthManager.shared

    // UI state
    @State private var mode: KeySheetMode = .key
    @State private var inEditMode = false
    @State private var isRevealed = false
    @State private var showGenerateAlert = false
    @State private var copiedToast = false
    @State private var error: String?
    @State private var autoHideTask: DispatchWorkItem?

    // Key state
    @State private var originalKey = ""
    @State private var draftKey = ""

    // Logs
    @ObservedObject private var logger = CryptoLogger.shared
    @State private var onlyErrors = false

    var body: some View {
        NavigationView {
            VStack(spacing: 16) {

                // Title and Close button
                HStack(spacing: 8) {
                    Image(systemName: "key.fill")
                    Text(KeyLocalized.aes_key)
                        .font(.headline)
                    Spacer()

                    Button {
                        isPresented = false
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                            .imageScale(.large)
                    }
                }

                // Mode switch
                Picker("", selection: $mode) {
                    Text(KeyLocalized.key).tag(KeySheetMode.key)
                    Text(KeyLocalized.logs).tag(KeySheetMode.logs)
                }
                .pickerStyle(.segmented)

                // Content
                if mode == .key {
                    keySection
                } else {
                    logsSection
                }

                Spacer(minLength: 8)
            }
            .padding()
            .navigationBarTitleDisplayMode(.inline)
            .interactiveDismissDisabled(inEditMode && draftKey != originalKey)
            .overlay(alignment: .top) {
                if copiedToast {
                    Text(KeyLocalized.copied)
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .background(.thinMaterial)
                        .clipShape(Capsule())
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .padding(.top, 8)
                } else {
                    EmptyView()
                }
            }
            .onAppear { syncFromManager() }
            .onDisappear { autoHideTask?.cancel() }
            .logViewName()
        }
    }

    // MARK: - Key UI

    private var keySection: some View {
        VStack(spacing: 12) {

            if inEditMode {
                TextField(KeyLocalized.base64_key, text: $draftKey)
                    .font(.system(.body, design: .monospaced))
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .padding(12)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                let display = isRevealed ? draftKey : maskedPreview(draftKey)

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(display)
                            .font(.system(.body, design: .monospaced))
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .contextMenu { Button(KeyLocalized.copy) { UIPasteboard.general.string = draftKey } }

                        Spacer()

                        Button { revealWithBiometrics() } label: {
                            Image(systemName: isRevealed ? "eye.slash" : "eye")
                        }
                        .accessibilityLabel(isRevealed ? KeyLocalized.hide_key : KeyLocalized.reveal_key)

                        Button {
                            UIPasteboard.general.string = draftKey
                            copiedToast = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { copiedToast = false }
                        } label: {
                            Image(systemName: "doc.on.doc")
                        }
                        .accessibilityLabel(KeyLocalized.copy)
                    }
                    .padding(12)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }

            if let error {
                Text(error).font(.footnote).foregroundColor(.red)
            } else {
                Text(KeyLocalized.keep_key_secret)
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 4)
            }

            // Action buttons - Generate new and Reset changes
            VStack(spacing: 12) {
                Button(role: .destructive) {
                    showGenerateAlert = true
                } label: {
                    HStack {
                        Image(systemName: "wand.and.rays")
                        Text(KeyLocalized.generate_new)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.red.opacity(0.1))
                    .foregroundColor(.red)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }

                Button {
                    draftKey = originalKey
                    let data = Data(base64Encoded: draftKey) ?? Data()
                    CallEncryptionManager.shared.setUpAesKey(data)
                    CallEncryptionManager.shared.sessionAESKey = data
                } label: {
                    HStack {
                        Image(systemName: "arrow.counterclockwise")
                        Text(KeyLocalized.reset_changes)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color(.systemGray5))
                    .foregroundColor(.primary)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
        }
        .alert(KeyLocalized.replace_current_key, isPresented: $showGenerateAlert) {
            Button(KeyLocalized.cancel, role: .cancel) {}
            Button(KeyLocalized.replace, role: .destructive) {
                draftKey = CallEncryptionManager.shared.randomAESKey().base64EncodedString()
                let data = Data(base64Encoded: draftKey) ?? Data()
                CallEncryptionManager.shared.setUpAesKey(data)
                CallEncryptionManager.shared.sessionAESKey = data
            }
        } message: {
            Text(KeyLocalized.new_key_will_apply)
        }
    }

    // MARK: - Logs UI

    private var logsSection: some View {
        VStack(spacing: 8) {
            HStack {
                Text(KeyLocalized.logs)
                    .font(.headline)
                    .bold()

                Spacer()

                HStack(spacing: 8) {
                    Text(KeyLocalized.errors_only)
                    Toggle(KeyLocalized.errors_only, isOn: $onlyErrors)
                        .labelsHidden()
                }

                Button {
                    logger.clear()
                } label: { Label(KeyLocalized.clear, systemImage: "trash") }
                .foregroundColor(.red)
            }

            Divider()

            LogListView(lines: filteredLines)
                .frame(maxHeight: 280)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))

            HStack {
                Button {
                    UIPasteboard.general.string = filteredLines.joined(separator: "\n")
                    copiedToast = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { copiedToast = false }
                } label: { Label(KeyLocalized.copy_all, systemImage: "doc.on.doc") }

                Spacer()
                Text("\(filteredLines.count) \(KeyLocalized.lines_count)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .font(.footnote)
            }
        }
    }

    private var filteredLines: [String] {
        onlyErrors ? logger.entries.filter { $0.localizedCaseInsensitiveContains("error") } : logger.entries
    }

    // MARK: - Helpers

    private func syncFromManager() {
        originalKey = CallEncryptionManager.shared.originalAESKey?.base64EncodedString() ?? ""
        draftKey = CallEncryptionManager.shared.sessionAESKey?.base64EncodedString() ?? originalKey
    }

    private func maskedPreview(_ s: String) -> String {
        guard s.count >= 8 else { return String(repeating: "•", count: max(8, s.count)) }
        let left = s.prefix(4), right = s.suffix(4)
        return "\(left)••••••••••••••••\(right)"
    }

    private func validateBase64Key(_ s: String) -> String? {
        guard let data = Data(base64Encoded: s) else { return KeyLocalized.key_must_be_base64 }
        // Adjust if using AES-128/192
        return (data.count == 32) ? nil : KeyLocalized.key_must_decode_to_32_bytes
    }

    private func revealWithBiometrics() {
        if isRevealed { isRevealed = false; return }

        Task {
            let success = await biometricAuth.authenticate(reason: KeyLocalized.reveal_aes_key)
            if success {
                await showForTenSeconds()
            }
        }
    }

    @MainActor
    private func showForTenSeconds() async {
        isRevealed = true
        autoHideTask?.cancel()
        let t = DispatchWorkItem { self.isRevealed = false }
        autoHideTask = t
        DispatchQueue.main.asyncAfter(deadline: .now() + 10, execute: t)
    }
}

// MARK: - Log list

struct LogListView: View {
    let lines: [String]

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 6) {
                    ForEach(Array(lines.enumerated()), id: \.offset) { idx, line in
                        Text(line)
                            .font(.system(.caption, design: .monospaced))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .id(idx)
                    }
                }
                .padding(12)
            }
            .onReceive(NotificationCenter.default.publisher(for: .cryptoLogAppended)) { _ in
                guard !lines.isEmpty else { return }
                withAnimation { proxy.scrollTo(lines.count - 1, anchor: .bottom) }
            }
        }
    }
}
