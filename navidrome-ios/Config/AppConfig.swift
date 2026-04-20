import Foundation
import Security

/// App configuration backed by UserDefaults with Keychain support for credentials.
/// All members are static — UserDefaults is thread-safe, so access from any context is safe.
nonisolated enum AppConfig {
    private static let defaults = UserDefaults.standard

    // MARK: - Server

    /// Base URL of the Navidrome server (e.g. "http://192.168.1.16:4533").
    static var serverURL: String? {
        get { defaults.string(forKey: "serverURL") }
        set { defaults.set(newValue, forKey: "serverURL") }
    }

    /// Base URL of the Go sync service (e.g. "http://192.168.1.116:8080").
    /// Only needed for multi-client sync. Leave nil for standalone mode.
    static var syncServiceURL: String? {
        get { defaults.string(forKey: "syncServiceURL") }
        set { defaults.set(newValue, forKey: "syncServiceURL") }
    }

    /// Navidrome username.
    static var username: String? {
        get { loadFromKeychain(key: "navidrome_username") }
        set {
            if let newValue { saveToKeychain(key: "navidrome_username", value: newValue) }
            else { deleteFromKeychain(key: "navidrome_username") }
        }
    }

    /// Navidrome password.
    static var password: String? {
        get { loadFromKeychain(key: "navidrome_password") }
        set {
            if let newValue { saveToKeychain(key: "navidrome_password", value: newValue) }
            else { deleteFromKeychain(key: "navidrome_password") }
        }
    }

    /// Whether the user has successfully logged in.
    static var isLoggedIn: Bool {
        serverURL != nil && username != nil && password != nil
    }

    /// Subsonic auth query string built from stored credentials.
    static var authParams: String? {
        guard let u = username, let p = password else { return nil }
        return "u=\(u)&p=\(p)&v=1.16.1&c=navidrome-ios&f=json"
    }

    /// Persistent client ID — survives app restarts.
    static var clientId: String {
        if let existing = defaults.string(forKey: "clientId") {
            return existing
        }
        let id = UUID().uuidString
        defaults.set(id, forKey: "clientId")
        return id
    }

    // MARK: - Appearance

    static var coloredAlbumBackground: Bool {
        get { defaults.object(forKey: "coloredAlbumBackground") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "coloredAlbumBackground") }
    }

    static var coloredPlaylistBackground: Bool {
        get { defaults.object(forKey: "coloredPlaylistBackground") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "coloredPlaylistBackground") }
    }

    // MARK: - Downloads

    /// Whether offline mode is enabled (only play downloaded content).
    static var offlineMode: Bool {
        get { defaults.object(forKey: "offlineMode") as? Bool ?? false }
        set { defaults.set(newValue, forKey: "offlineMode") }
    }

    /// Whether to automatically cache songs after playback (at scrobble time).
    static var autoCacheEnabled: Bool {
        get { defaults.object(forKey: "autoCacheEnabled") as? Bool ?? false }
        set { defaults.set(newValue, forKey: "autoCacheEnabled") }
    }

    /// Maximum auto-cache storage in bytes. 0 = unlimited. Default 1 GB.
    static var maxCacheSize: Int64 {
        get { defaults.object(forKey: "maxCacheSize") as? Int64 ?? 1_073_741_824 }
        set { defaults.set(newValue, forKey: "maxCacheSize") }
    }

    /// Download quality as maxBitRate param for stream.view. 0 = original quality.
    static var downloadQuality: Int {
        get { defaults.object(forKey: "downloadQuality") as? Int ?? 0 }
        set { defaults.set(newValue, forKey: "downloadQuality") }
    }

    /// Clear all stored credentials and server info.
    static func logout() {
        serverURL = nil
        syncServiceURL = nil
        username = nil
        password = nil
    }

    // MARK: - Keychain helpers

    static func saveToKeychain(key: String, value: String) {
        let data = Data(value.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
        ]
        SecItemDelete(query as CFDictionary)

        var add = query
        add[kSecValueData as String] = data
        SecItemAdd(add as CFDictionary, nil)
    }

    static func loadFromKeychain(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func deleteFromKeychain(key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
        ]
        SecItemDelete(query as CFDictionary)
    }
}
