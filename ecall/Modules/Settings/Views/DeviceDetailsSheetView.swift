import SwiftUI

struct DeviceDetailSheetView: View {
    let device: Device
    let onTerminate: () -> Void

    @State private var showConfirm = false

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: deviceIcon(for: device.identifier))
                .resizable()
                .scaledToFit()
                .frame(width: 50, height: 50)
                .padding()
                .background(Circle().fill(Color.blue.opacity(0.2)))
                .foregroundColor(.blue)
                .padding(.top, 16)

            VStack(spacing: 4) {
                if device.deviceName != "" {
                    Text("\(device.identifier) - \(device.deviceName)").font(.title2)
                        .bold()
                } else {
                    Text("\(device.identifier)").font(.title2)
                        .bold()
                }
                Text(AppUtils.relativeTime(from: device.updatedAt))
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }

            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Image(systemName: "laptopcomputer.and.iphone")
                        .foregroundColor(.blue)
                        .font(.system(size: 24))
                        .frame(width: 30)
                    VStack(alignment: .leading) {
                        Text("\(device.systemName) \(device.systemVersion)")
                        Text(KeyLocalized.application)
                            .foregroundColor(.gray)
                    }
                }
                HStack {
                    Image(systemName: "mappin.and.ellipse")
                        .foregroundColor(.blue)
                        .font(.system(size: 24))
                        .frame(width: 30)
                    VStack(alignment: .leading) {
                        Text(device.location)
                        Text(KeyLocalized.location_based_ip)
                            .foregroundColor(.gray)
                    }
                }
            }
            .frame(maxWidth: .infinity)

            Spacer()

            Button(role: .destructive) {
                showConfirm = true
            } label: {
                Text(KeyLocalized.terminate_session)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.red)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .presentationDetents([.medium])
        .alert(KeyLocalized.terminate_session, isPresented: $showConfirm) {
            Button(KeyLocalized.terminate, role: .destructive) {
                onTerminate()
            }
            Button(KeyLocalized.cancel, role: .cancel) { }
        } message: {
            Text(KeyLocalized.are_you_sure_terminate_session)
        }
        .logViewName()
    }

    func deviceIcon(for name: String) -> String {
        if name.lowercased().contains("iphone") {
            return "iphone"
        } else if name.lowercased().contains("ipad") {
            return "ipad"
        } else if name.lowercased().contains("mac") {
            return "laptopcomputer"
        } else {
            return "desktopcomputer"
        }
    }
}
