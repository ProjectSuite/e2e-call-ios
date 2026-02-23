import SwiftUI
import CoreImage
import UIKit
import Vision

class AddFriendViewModel: ObservableObject {
    @Published var friendAddMode: FriendAddMode = .scan
    @Published var errorMessage: String?

    // MARK: - Data Sources
    @Published var scannedQRPayload: String = "" // From camera scan/upload image
    @Published var importedQRPayload: String = "" // From external URL import
    @Published var selectedImage: UIImage?
    @Published var importedDisplayName: String? // From swipe left history to add friend

    // MARK: - Computed Properties
    var userId: String? {
        if friendAddMode == .scan && scannedQRPayload.isNotEmpty {
            return parseAndValidate(raw: scannedQRPayload)
        } else if friendAddMode == .autoImport && importedQRPayload.isNotEmpty {
            return parseAndValidate(raw: importedQRPayload)
        }
        return nil
    }

    var hasValidUserId: Bool {
        return userId != nil && !(userId?.isEmpty ?? true)
    }

    var displayName: String? {
        if let importedDisplayName = importedDisplayName {
            return importedDisplayName
        } else if friendAddMode == .scan && scannedQRPayload.isNotEmpty {
            return extractDisplayName(from: scannedQRPayload)
        } else if friendAddMode == .autoImport && importedQRPayload.isNotEmpty {
            return extractDisplayName(from: importedQRPayload)
        }
        return nil
    }

    private func decodeQRCode(from image: UIImage) -> String? {
        guard let ciImage = CIImage(image: image) else { return nil }

        let request = VNDetectBarcodesRequest { _, error in
            if let error = error {
                debugLog("Barcode detection error: \(error.localizedDescription)")
            }
        }
        request.symbologies = [.qr]

        let handler = VNImageRequestHandler(ciImage: ciImage, options: [:])
        do {
            try handler.perform([request])
            if let results = request.results {
                for observation in results {
                    if let payload = observation.payloadStringValue {
                        return payload
                    }
                }
            }
        } catch {
            debugLog("Error performing barcode request: \(error.localizedDescription)")
        }
        return nil
    }

    func processSelectedImage() {
        if let image = selectedImage, let decoded = decodeQRCode(from: image) {
            debugLog("decode QR: \(decoded)")
            validateAndSetQRPayload(decoded)
        } else {
            showErrorMessage(KeyLocalized.invalid_qr_code)
            clearScannedData()
        }
    }

    private let tokenTTL: TimeInterval = 60 * 60

    /// Splits raw URL → path → token, then extracts userID and validates expiry.
    private func parseAndValidate(raw: String) -> String? {
        guard let url = URL(string: raw) else {
            return UInt64(raw) != nil ? raw : nil
        }

        // Handle universal link: {domain}/share/contact/{token}
        if url.scheme == "https" && url.path.hasPrefix("/share/contact/") {
            if AppUtils.isValidConfiguredHost(url.host) {
                let tokenString = String(url.path.dropFirst("/share/contact/".count))
                return extractUserIdFromToken(tokenString)
            }
        }

        // Handle deep link: ecall://contact/{token}
        if AppUtils.validUrlApp(url) {
            let tokenString = url.path.dropFirst()
            return extractUserIdFromToken(String(tokenString))
        }

        // Fallback for numeric ID
        return UInt64(raw) != nil ? raw : nil
    }

    /// Extract userID from token without signature verification.
    /// Supports formats:
    /// - New format (3 parts): userId:base64EncodedDisplayName:expiry
    /// - Legacy format (4 parts): userId:base64EncodedDisplayName:expiry:signature (ignored)
    /// - Legacy format (3 parts): userId:expiry:signature (ignored)
    private func extractUserIdFromToken(_ tokenString: String) -> String? {
        let parts = tokenString.split(separator: ":")
        let candidateId = parts.first.map(String.init) ?? ""

        // If the first component is a numeric user id, keep it as a fallback
        let numericId: String? = UInt64(candidateId) != nil ? candidateId : nil

        // New format (3 parts): userId:base64EncodedDisplayName:expiry (no signature)
        if parts.count == 3 {
            if let expiry = TimeInterval(parts[2]),
               Date().timeIntervalSince1970 < expiry {
                // Valid expiry, return userID
                return String(parts[0])
            } else {
                // Expired, fallback to numeric ID if valid
                return numericId
            }
        }
        
        // Legacy format (4 parts): userId:base64EncodedDisplayName:expiry:signature
        // We ignore signature verification as backend doesn't verify
        if parts.count == 4 {
            if let expiry = TimeInterval(parts[2]),
               Date().timeIntervalSince1970 < expiry {
                return String(parts[0])
            } else {
                return numericId
            }
        }

        // Legacy format (3 parts with signature): userId:expiry:signature
        // We ignore signature verification as backend doesn't verify
        if parts.count == 3 {
            if let expiry = TimeInterval(parts[1]),
               Date().timeIntervalSince1970 < expiry {
                return String(parts[0])
            } else {
                return numericId
            }
        }

        // Invalid format, fallback to numeric ID if available
        return numericId
    }

    private func extractDisplayName(from raw: String) -> String? {
        guard let url = URL(string: raw) else {
            return nil
        }

        let tokenString: String
        // Handle universal link: {domain}/share/contact/{token}
        if url.scheme == "https" && url.path.hasPrefix("/share/contact/") {
            if AppUtils.isValidConfiguredHost(url.host) {
                tokenString = String(url.path.dropFirst("/share/contact/".count))
            } else {
                return nil
            }
        }
        // Handle deep link: ecall://contact/{token}
        else if AppUtils.validUrlApp(url) {
            tokenString = String(url.path.dropFirst())
        } else {
            return nil
        }

        let parts = tokenString.split(separator: ":")
        
        // New format (3 parts): userId:base64EncodedDisplayName:expiry
        if parts.count == 3 {
            let encodedDisplayName = String(parts[1])
            if let data = Data(base64Encoded: encodedDisplayName),
               let decodedDisplayName = String(data: data, encoding: .utf8) {
                return decodedDisplayName
            }
        }
        
        // Legacy format (4 parts): userId:base64EncodedDisplayName:expiry:signature
        if parts.count == 4 {
            let encodedDisplayName = String(parts[1])
            if let data = Data(base64Encoded: encodedDisplayName),
               let decodedDisplayName = String(data: data, encoding: .utf8) {
                return decodedDisplayName
            }
        }
        
        // Old format doesn't have displayName
        return nil
    }

    func sendFriendRequest(completion: @escaping (Bool) -> Void) {
        guard let uid = userId, let id = UInt64(uid) else {
            completion(false)
            self.showErrorMessage(KeyLocalized.invalid_data)
            return
        }

        ContactsAPIService.shared.sendFriendRequest(to: id) { result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    completion(true)
                case let .failure(error):
                    errorLog(error.content)
                    self.showErrorMessage(error.content)
                    completion(false)
                }
            }
        }
    }

    func showErrorMessage(_ message: String) {
        errorMessage = message
    }

    func clearError() {
        errorMessage = nil
    }

    func clearScannedData() {
        scannedQRPayload = ""
        importedQRPayload = ""
        selectedImage = nil
    }

    // MARK: - QR Processing Methods
    func validateAndSetQRPayload(_ scannedString: String) {
        clearError()

        // Use existing parseAndValidate function to check if valid
        if parseAndValidate(raw: scannedString) != nil {
            // Set to scannedQRPayload since this comes from camera/photo
            scannedQRPayload = scannedString
            debugLog("Valid QR format detected: \(scannedString)")
        } else {
            showErrorMessage(KeyLocalized.invalid_qr_code)
            debugLog("Invalid QR format: \(scannedString)")
        }
    }
}
