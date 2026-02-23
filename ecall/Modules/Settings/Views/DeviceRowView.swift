import SwiftUI

struct DeviceRowView: View {
    let device: Device
    let isOtherDevice: Bool

    var body: some View {
        HStack {
            Image(systemName: deviceIcon(for: device.identifier))
                .foregroundColor(.blue)
                .font(.system(size: 24))
                .frame(width: 30)

            VStack(alignment: .leading) {
                let deviceType = DeviceInfo.getCommercialName(for: device.identifier)

                if device.deviceName != "" {
                    Text("\(deviceType) - \(device.deviceName)").font(.headline)
                } else {
                    Text(deviceType).font(.headline)
                }

                Text("\(device.systemName) \(device.systemVersion)").font(.subheadline).foregroundColor(.gray)

                let locationAndRelativeTime = "\(device.location.isNotEmpty && device.location != "-, -" ? device.location + " • " : "")\(AppUtils.relativeTime(from: device.updatedAt))"
                Text(locationAndRelativeTime).font(.caption).foregroundColor(.gray)
            }

            if isOtherDevice {
                Spacer()

                Image(systemName: "chevron.right")
                    .foregroundColor(.gray)
                    .font(.system(size: 14, weight: .medium))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }

    private func deviceIcon(for name: String) -> String {
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
