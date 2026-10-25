import Foundation
import Security

/// Reads the Anthropic API key from the login keychain.
enum Keychain {
    static let service = "imessage-to-notes"
    static let account = "anthropic-api-key"

    static func anthropicAPIKey() throws -> String {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data,
              let key = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
              !key.isEmpty
        else {
            let reason = SecCopyErrorMessageString(status, nil) as String? ?? "status \(status)"
            throw AdapterError(
                "No Anthropic API key in the keychain (service \(service), account \(account)): \(reason)"
            )
        }
        return key
    }
}
