import Testing
import Security
@testable import navidrome_ios

@Suite("AppConfig Keychain and Login")
struct AppConfigTests {

    @Test("First launch with empty credentials is not logged in")
    func firstLaunchNotLoggedIn() {
        let originalService = AppConfig.keychainService
        let originalServerURL = AppConfig.serverURL
        let originalSyncURL = AppConfig.syncServiceURL

        let testService = "navidrome-tests-\(UUID().uuidString)"
        AppConfig.keychainService = testService
        defer {
            AppConfig.deleteFromKeychain(key: "navidrome_username")
            AppConfig.deleteFromKeychain(key: "navidrome_password")
            AppConfig.serverURL = originalServerURL
            AppConfig.syncServiceURL = originalSyncURL
            AppConfig.keychainService = originalService
        }

        AppConfig.serverURL = nil
        AppConfig.syncServiceURL = nil
        AppConfig.deleteFromKeychain(key: "navidrome_username")
        AppConfig.deleteFromKeychain(key: "navidrome_password")

        #expect(AppConfig.isLoggedIn == false)
        #expect(AppConfig.username == nil)
        #expect(AppConfig.password == nil)
    }

    @Test("Keychain save updates existing value")
    func keychainUpdatePath() {
        let originalService = AppConfig.keychainService
        let testService = "navidrome-tests-\(UUID().uuidString)"
        AppConfig.keychainService = testService

        defer {
            AppConfig.deleteFromKeychain(key: "navidrome_username")
            AppConfig.keychainService = originalService
        }

        AppConfig.saveToKeychain(key: "navidrome_username", value: "first")
        #expect(AppConfig.loadFromKeychain(key: "navidrome_username") == "first")

        AppConfig.saveToKeychain(key: "navidrome_username", value: "second")
        #expect(AppConfig.loadFromKeychain(key: "navidrome_username") == "second")
    }

    @Test("Login state requires server URL and credentials")
    func loginStateDerivation() {
        let originalService = AppConfig.keychainService
        let originalServerURL = AppConfig.serverURL
        let originalSyncURL = AppConfig.syncServiceURL
        let testService = "navidrome-tests-\(UUID().uuidString)"

        AppConfig.keychainService = testService
        defer {
            AppConfig.logout()
            AppConfig.serverURL = originalServerURL
            AppConfig.syncServiceURL = originalSyncURL
            AppConfig.keychainService = originalService
        }

        AppConfig.logout()
        #expect(AppConfig.isLoggedIn == false)

        AppConfig.serverURL = "http://localhost:4533"
        #expect(AppConfig.isLoggedIn == false)

        AppConfig.username = "admin"
        #expect(AppConfig.isLoggedIn == false)

        AppConfig.password = "admin"
        #expect(AppConfig.isLoggedIn == true)
    }

    @Test("Logout clears server and credentials")
    func logoutClearsData() {
        let originalService = AppConfig.keychainService
        let originalServerURL = AppConfig.serverURL
        let originalSyncURL = AppConfig.syncServiceURL
        let testService = "navidrome-tests-\(UUID().uuidString)"

        AppConfig.keychainService = testService
        defer {
            AppConfig.deleteFromKeychain(key: "navidrome_username")
            AppConfig.deleteFromKeychain(key: "navidrome_password")
            AppConfig.serverURL = originalServerURL
            AppConfig.syncServiceURL = originalSyncURL
            AppConfig.keychainService = originalService
        }

        AppConfig.serverURL = "http://localhost:4533"
        AppConfig.syncServiceURL = "http://localhost:8080"
        AppConfig.username = "user"
        AppConfig.password = "pass"

        #expect(AppConfig.isLoggedIn == true)
        AppConfig.logout()

        #expect(AppConfig.serverURL == nil)
        #expect(AppConfig.syncServiceURL == nil)
        #expect(AppConfig.username == nil)
        #expect(AppConfig.password == nil)
        #expect(AppConfig.isLoggedIn == false)
    }

    @Test("Legacy keychain entry is migrated to service-scoped entry")
    func legacyKeychainMigration() {
        let originalService = AppConfig.keychainService
        let testService = "navidrome-tests-\(UUID().uuidString)"
        AppConfig.keychainService = testService
        defer {
            AppConfig.deleteFromKeychain(key: "navidrome_username")
            AppConfig.keychainService = originalService
        }

        let key = "navidrome_username"
        let legacyValue = "legacy-user"
        let legacyQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
        ]
        SecItemDelete(legacyQuery as CFDictionary)

        let addLegacy: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: Data(legacyValue.utf8),
        ]
        let status = SecItemAdd(addLegacy as CFDictionary, nil)
        #expect(status == errSecSuccess || status == errSecDuplicateItem)

        let loaded = AppConfig.loadFromKeychain(key: key)
        #expect(loaded == legacyValue)

        // Service-scoped entry should now exist.
        let serviceQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecAttrService as String: testService,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        let migratedStatus = SecItemCopyMatching(serviceQuery as CFDictionary, &result)
        #expect(migratedStatus == errSecSuccess)

        // Legacy entry should be cleaned up by migration.
        result = nil
        let legacyStatus = SecItemCopyMatching((legacyQuery.merging([
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]) { _, new in new }) as CFDictionary, &result)
        #expect(legacyStatus != errSecSuccess)
    }
}
