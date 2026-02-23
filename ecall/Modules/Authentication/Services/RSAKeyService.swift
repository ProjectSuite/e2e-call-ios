import SwiftUI
import Security

class RSAKeyService {
    func generateRSAKeyPair() -> (publicKey: String, privateKey: String)? {
        let attributes: [String: Any] = [
            kSecAttrKeyType as String: kSecAttrKeyTypeRSA,
            kSecAttrKeySizeInBits as String: 2048
        ]
        var error: Unmanaged<CFError>?
        guard let privateKey = SecKeyCreateRandomKey(attributes as CFDictionary, &error),
              let publicKey = SecKeyCopyPublicKey(privateKey)
        else {
            return nil
        }
        guard let publicKeyData = SecKeyCopyExternalRepresentation(publicKey, &error) as Data?,
              let privateKeyData = SecKeyCopyExternalRepresentation(privateKey, &error) as Data?
        else {
            return nil
        }
        let pubKeyBase64 = publicKeyData.base64EncodedString()
        let privKeyBase64 = privateKeyData.base64EncodedString()
        return (pubKeyBase64, privKeyBase64)
    }
}
