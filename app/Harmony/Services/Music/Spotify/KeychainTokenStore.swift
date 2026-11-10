import Foundation
import Security

/// Spotify tokens in the Keychain (TODO 1.19, PROJECT.md §11): they survive app restarts, never
/// leave this phone (no iCloud Keychain, no backup to another device), and are readable once the
/// phone has been unlocked after a restart.
struct KeychainTokenStore {
    /// Keychain service name; tests use their own so they never touch the app's tokens.
    let service: String

    func load() throws -> SpotifyTokens? {
        var query = itemQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = result as? Data else { throw KeychainError(status: status) }
        return try JSONDecoder().decode(SpotifyTokens.self, from: data)
    }

    func save(_ tokens: SpotifyTokens) throws {
        let data = try JSONEncoder().encode(tokens)
        let status = SecItemUpdate(itemQuery as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        if status == errSecItemNotFound {
            var item = itemQuery
            item[kSecValueData as String] = data
            item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            let added = SecItemAdd(item as CFDictionary, nil)
            guard added == errSecSuccess else { throw KeychainError(status: added) }
        } else if status != errSecSuccess {
            throw KeychainError(status: status)
        }
    }

    /// Does nothing if there are no tokens.
    func delete() throws {
        let status = SecItemDelete(itemQuery as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else { throw KeychainError(status: status) }
    }

    private var itemQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: "spotify-tokens",
        ]
    }
}

/// A Keychain call failed with this `OSStatus`.
struct KeychainError: Error, Equatable {
    let status: OSStatus
}
