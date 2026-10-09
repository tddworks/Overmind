import Foundation
import Security
import Monitor

/// The `TokenVault` port over the login Keychain: one generic password (CANONICAL law 15).
struct KeychainTokenVault: TokenVault {
    let service = "com.tddworks.edgemeter"
    let account = "cloudflare-api-token"

    private var query: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: account]
    }

    func save(_ token: String) throws {
        SecItemDelete(query as CFDictionary)
        var item = query
        item[kSecValueData as String] = Data(token.utf8)
        item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        let status = SecItemAdd(item as CFDictionary, nil)
        guard status == errSecSuccess else { throw KeychainError(status: status) }
    }

    func load() -> String? {
        var lookup = query
        lookup[kSecReturnData as String] = true
        lookup[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: AnyObject?
        guard SecItemCopyMatching(lookup as CFDictionary, &result) == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    func delete() {
        SecItemDelete(query as CFDictionary)
    }

    struct KeychainError: Error { let status: OSStatus }
}
