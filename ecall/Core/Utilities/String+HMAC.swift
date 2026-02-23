import Foundation
import CryptoKit

extension String {
    func hmacSHA256(key: String) -> String {
        let keyData = Data(key.utf8)
        let messageData = Data(self.utf8)
        let symmetricKey = SymmetricKey(data: keyData)
        let signature = HMAC<SHA256>.authenticationCode(for: messageData, using: symmetricKey)
        return Data(signature).map { String(format: "%02hhx", $0) }.joined()
    }
}
