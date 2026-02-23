import SwiftUI

struct DevicesView: View {
    @EnvironmentObject var languageManager: LanguageManager
    @StateObject private var viewModel = DevicesViewModel()
    @State private var showDeviceSheet: Bool = false
    @State private var showConfirm = false

    var body: some View {
        NavigationView {
            List {
                if let currentDevice = viewModel.currentDevice {
                    Section(header: Text(KeyLocalized.this_device)) {
                        DeviceRowView(device: currentDevice, isOtherDevice: false)

                        Button {
                            showConfirm = true
                        } label: {
                            Label(KeyLocalized.terminate_all_other_sessions, systemImage: "hand.raised")
                                .foregroundColor(.red)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .alert(KeyLocalized.terminate_sessions, isPresented: $showConfirm) {
                            Button(KeyLocalized.terminate, role: .destructive) {
                                viewModel.terminateAllOtherSessions()
                            }
                            Button(KeyLocalized.cancel, role: .cancel) { }
                        } message: {
                            Text(KeyLocalized.are_you_sure_terminate_all)
                        }
                    }
                }

                // Active sessions section
                if !viewModel.otherDevices.isEmpty {
                    Section(header: Text(KeyLocalized.active_sessions)) {
                        ForEach(viewModel.otherDevices) { device in
                            Button {
                                viewModel.selectedDevice = device
                                showDeviceSheet = true
                            } label: {
                                DeviceRowView(device: device, isOtherDevice: true)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .sheet(isPresented: $showDeviceSheet) {
                if let device = viewModel.selectedDevice {
                    DeviceDetailSheetView(device: device, onTerminate: {
                        viewModel.terminate(device: device)
                        showDeviceSheet = false
                    })
                } else {
                    Text(KeyLocalized.no_devices_found)
                }
            }

            // Error section
            if viewModel.errorMessage != "" {
                Section {
                    Text(viewModel.errorMessage)
                        .foregroundColor(.red)
                }
            }
        }
        .navigationTitle(KeyLocalized.devices)
        .navigationBarTitleDisplayMode(.inline)
        .overlay {
            if viewModel.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.black.opacity(0.3))
            }
        }
        .logViewName()
    }
}
