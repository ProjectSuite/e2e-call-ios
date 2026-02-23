import SwiftUI
import CoreImage
import CoreImage.CIFilterBuiltins

class MyQRCodeViewModel: ObservableObject {
    @Published var userID: String = ""
    @Published var displayName: String = ""
    @Published var publicKeyHash: String = ""

    /// How long before the contact-token expires (seconds)
    private let tokenTTL: TimeInterval = 60 * 60  // 1 hour

    private let context = CIContext()
    private let filter = CIFilter.qrCodeGenerator()

    /// Build the token: "<userID>:<base64EncodedDisplayName>:<expiry>"
    private func makeContactToken() -> String? {
        guard !userID.isEmpty else { return nil }
        let expiry = Int(Date().addingTimeInterval(tokenTTL).timeIntervalSince1970)
        let encodedDisplayName = Data(displayName.utf8).base64EncodedString()
        // Format: userId:base64EncodedDisplayName:expiry
        return "\(userID):\(encodedDisplayName):\(expiry)"
    }

    var deepLink: String {
        guard let token = makeContactToken() else { return "" }
        return "\(Endpoints.shared.shareURL)/contact/\(token)"
    }

    init() {
        loadCredentials()
    }

    func loadCredentials() {
        if let uid = KeyStorage.shared.readUserId() {
            userID = uid
        }
        if let name = KeyStorage.shared.readDisplayName() {
            displayName = name
        }
        if let pubKeyHash = KeyStorage.shared.readPublicKeyHash() {
            publicKeyHash = pubKeyHash
        }
    }

    /// Generates a QR for your deepLink
    func generateQRCode() -> UIImage? {
        guard !deepLink.isEmpty else { return nil }
        let data = Data(deepLink.utf8)
        filter.setValue(data, forKey: "inputMessage")
        guard let outputImage = filter.outputImage else { return nil }
        let transform = CGAffineTransform(scaleX: 10, y: 10)
        let scaled = outputImage.transformed(by: transform)
        guard let cgImg = context.createCGImage(scaled, from: scaled.extent) else { return nil }
        return UIImage(cgImage: cgImg)
    }
}
