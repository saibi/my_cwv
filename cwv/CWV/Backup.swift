import Foundation
import Security

/// 앱을 삭제해도 iOS Keychain 항목은 남아, 같은 Team ID/번들 ID로 다시 설치하면 읽을 수 있다.
extension KeyValueBackup {
    static let keychain = KeyValueBackup(
        save: { data in
            let q: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                    kSecAttrService as String: "local.saibi.cwv.backup",
                                    kSecAttrAccount as String: "userdata"]
            SecItemDelete(q as CFDictionary)
            var add = q
            add[kSecValueData as String] = data
            add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
            SecItemAdd(add as CFDictionary, nil)  // 실패해도 UserDefaults 저장은 유지된다
        },
        load: {
            let q: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                    kSecAttrService as String: "local.saibi.cwv.backup",
                                    kSecAttrAccount as String: "userdata",
                                    kSecReturnData as String: true,
                                    kSecMatchLimit as String: kSecMatchLimitOne]
            var out: CFTypeRef?
            return SecItemCopyMatching(q as CFDictionary, &out) == errSecSuccess ? out as? Data : nil
        })
}
