import Foundation
import Security

struct VPNPersonalKeychain {
    static let sharedKey = "SHARED"
    static let passwordKey = "VPN_PASSWORD"

    private let serviceValue = "VPNKitPersonal"
    private var ikev2PasswordTag: String

    init(ikev2PasswordTag: String) {
        self.ikev2PasswordTag = ikev2PasswordTag
    }

    func save(key: String, value: String) -> Data? {
        guard
            let keyData = key.data(using: .utf8),
            let valueData = value.data(using: .utf8)
        else { return nil }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrGeneric as String: keyData,
            kSecAttrAccount as String: keyData,
            kSecAttrService as String: serviceValue,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
            kSecValueData as String: valueData,
            kSecReturnPersistentRef as String: true
        ]

        SecItemDelete(query as CFDictionary)

        var persistentRef: AnyObject?
        let status = SecItemAdd(query as CFDictionary, &persistentRef)
        guard status == errSecSuccess, let ref = persistentRef as? Data, !ref.isEmpty else {
            VPNKitLogger.error("VPNPersonalKeychain save failed key=\(key) status=\(status)")
            return nil
        }
        return ref
    }

    func saveIKEv2Password(_ password: String) -> Data? {
        guard let passwordData = password.data(using: .utf8) else {
            VPNKitLogger.error("VPNPersonalKeychain IKEv2 password not UTF-8 encodable")
            return nil
        }

        let queryDelete: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: ikev2PasswordTag
        ]
        SecItemDelete(queryDelete as CFDictionary)

        let queryAdd: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: ikev2PasswordTag,
            kSecValueData as String: passwordData,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock,
            kSecReturnPersistentRef as String: true
        ]

        var result: AnyObject?
        let status = SecItemAdd(queryAdd as CFDictionary, &result)
        guard status == errSecSuccess, let ref = result as? Data, !ref.isEmpty else {
            VPNKitLogger.error("VPNPersonalKeychain IKEv2 password save failed status=\(status)")
            return nil
        }
        return ref
    }
}
