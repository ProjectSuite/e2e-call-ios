import SwiftUI

struct PermissionsView: View {
    @StateObject private var viewModel = PermissionsViewModel()

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                headerBanner

                VStack(spacing: 8) {
                    ForEach(viewModel.items) { item in
                        PermissionRowView(
                            item: item,
                            onEditTap: {
                                switch item.status {
                                case .granted:
                                    break
                                case .denied:
                                    viewModel.openSettings()
                                case .notDetermined:
                                    viewModel.requestPermission(for: item.type)
                                }
                            }
                        )
                    }
                }
                .padding(.horizontal)

                syncIndicator

                if shouldShowOpenSettingsButton {
                    Button(action: {
                        viewModel.openSettings()
                    }, label: {
                        HStack {
                            Image(systemName: "gearshape.fill")
                            Text(KeyLocalized.permissions_open_settings_button)
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.accentColor)
                        .foregroundColor(.white)
                        .cornerRadius(14)
                    })
                    .padding(.horizontal)
                    .padding(.bottom, 24)
                }
            }
            .padding(.top, 16)
        }
        .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
        .navigationTitle(KeyLocalized.permissions_title)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            viewModel.refresh()
        }
    }

    @ViewBuilder
    private var headerBanner: some View {
        if viewModel.allPermissionsGranted {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.white)
                    .padding(8)
                    .background(Color.green)
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 4) {
                    Text(KeyLocalized.permissions_all_granted_title)
                        .font(.subheadline.weight(.semibold))
                    Text(KeyLocalized.permissions_all_granted_body)
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
            .padding()
            .background(Color.green.opacity(0.15))
            .cornerRadius(16)
            .padding(.horizontal)
        } else {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(.white)
                    .padding(8)
                    .background(Color.blue)
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 4) {
                    Text(KeyLocalized.permissions_info_title)
                        .font(.subheadline.weight(.semibold))
                    Text(KeyLocalized.permissions_info_body)
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
            .padding()
            .background(Color.blue.opacity(0.12))
            .cornerRadius(16)
            .padding(.horizontal)
        }
    }

    private var syncIndicator: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(Color.green)
                .frame(width: 8, height: 8)
            Text(KeyLocalized.permissions_sync_indicator)
                .font(.footnote)
                .foregroundColor(.secondary)
            Spacer()
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }

    private var shouldShowOpenSettingsButton: Bool {
        !viewModel.items.isEmpty && !viewModel.items.contains(where: { $0.status == .notDetermined })
    }
}

private struct PermissionRowView: View {
    let item: PermissionItem
    let onEditTap: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(item.type.gradient)
                .frame(width: 46, height: 46)
                .overlay(
                    Image(systemName: item.type.systemImageName)
                        .foregroundColor(.white)
                        .font(.system(size: 20, weight: .semibold))
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(item.type.title)
                    .font(.subheadline.weight(.semibold))

                Text(item.type.subtitle)
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }

            Spacer()

            VStack {
                statusBadge

                if item.status != .granted {
                    Button(action: {
                        onEditTap()
                    }, label: {
                        Image(systemName: item.status == .denied ? "arrow.up.forward.square" : "square.and.pencil")
                            .foregroundColor(.blue)
                            .font(.system(size: 16, weight: .semibold))
                    })
                }
            }
        }
        .padding()
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(16)
    }

    @ViewBuilder
    private var statusBadge: some View {
        let (text, foreground, background): (String, Color, Color) = {
            switch item.status {
            case .granted:
                return (
                    KeyLocalized.permissions_status_granted,
                    Color(red: 0.18, green: 0.57, blue: 0.29),
                    Color.green.opacity(0.15)
                )
            case .denied:
                return (
                    KeyLocalized.permissions_status_denied,
                    Color(red: 0.77, green: 0.20, blue: 0.24),
                    Color.red.opacity(0.12)
                )
            case .notDetermined:
                return (
                    KeyLocalized.permissions_status_not_set,
                    Color(red: 0.77, green: 0.51, blue: 0.16),
                    Color.orange.opacity(0.12)
                )
            }
        }()

        Text(text)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .foregroundColor(foreground)
            .background(background)
            .cornerRadius(999)
    }
}
