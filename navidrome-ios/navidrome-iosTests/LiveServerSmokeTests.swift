import XCTest
@testable import navidrome_ios

/// Live integration smoke tests that run against a real navidrome-sync server.
///
/// **Skipped automatically** when `NAVIDROME_TEST_URL` is not set in the environment.
/// To run locally:
///   ```
///   NAVIDROME_TEST_URL=http://localhost:8080 \
///   NAVIDROME_SERVER_URL=http://localhost:4533 \
///   NAVIDROME_TEST_USER=admin \
///   NAVIDROME_TEST_PASS=admin \
///   make test-ios-live
///   ```
///
/// Tests execute **serially** (REGISTER must complete before ROLE_CHANGE is observable).
/// Each test opens a fresh WebSocket connection and cleans up on completion.
final class LiveServerSmokeTests: XCTestCase {

    // MARK: - Environment helpers

    private var syncURL: String { ProcessInfo.processInfo.environment["NAVIDROME_TEST_URL"] ?? "" }
    private var navidromeURL: String { ProcessInfo.processInfo.environment["NAVIDROME_SERVER_URL"] ?? "" }
    private var testUser: String { ProcessInfo.processInfo.environment["NAVIDROME_TEST_USER"] ?? "" }
    private var testPass: String { ProcessInfo.processInfo.environment["NAVIDROME_TEST_PASS"] ?? "" }

    private func requireEnv() throws {
        try XCTSkipUnless(!syncURL.isEmpty,
            "Set NAVIDROME_TEST_URL to run live server smoke tests (e.g. http://localhost:8080)")
    }

    // MARK: - WebSocket smoke tests

    /// Verifies that a client can connect, send REGISTER, and receive ROLE_CHANGE from the server.
    func testWebSocketConnectAndRegister() throws {
        try requireEnv()

        let receivedRoleChange = expectation(description: "ROLE_CHANGE received")
        let clientId = UUID().uuidString
        let syncClient = SyncClient()

        syncClient.onMessage = { envelope in
            if envelope.type == .roleChange {
                receivedRoleChange.fulfill()
            }
        }

        syncClient.connect(baseURL: syncURL, clientId: clientId)
        defer { syncClient.disconnect() }

        waitForExpectations(timeout: 5)
    }

    /// Verifies that a second client observes a ROLE_CHANGE when it connects.
    func testSecondClientReceivesRoleChange() throws {
        try requireEnv()

        let receivedRole = expectation(description: "second client got ROLE_CHANGE")
        let clientA = SyncClient()
        let clientB = SyncClient()

        // First client registers as active
        clientA.connect(baseURL: syncURL, clientId: UUID().uuidString)
        defer { clientA.disconnect() }

        // Give server time to process REGISTER
        Thread.sleep(forTimeInterval: 0.3)

        // Second client should receive ROLE_CHANGE (observer assignment)
        clientB.onMessage = { envelope in
            if envelope.type == .roleChange {
                receivedRole.fulfill()
            }
        }
        clientB.connect(baseURL: syncURL, clientId: UUID().uuidString)
        defer { clientB.disconnect() }

        waitForExpectations(timeout: 5)
    }

    // MARK: - REST API smoke tests

    /// Verifies the Navidrome REST API returns a valid album list response.
    func testNavidromeAlbumListReturnsValidResponse() async throws {
        try requireEnv()
        guard !navidromeURL.isEmpty else {
            throw XCTSkip("Set NAVIDROME_SERVER_URL to run Navidrome API smoke tests")
        }

        // Temporarily set credentials
        let origService = AppConfig.keychainService
        let origServer = AppConfig.serverURL
        let testService = "navidrome-live-smoke-\(UUID().uuidString)"
        AppConfig.keychainService = testService
        AppConfig.serverURL = navidromeURL
        AppConfig.username = testUser
        AppConfig.password = testPass
        defer {
            AppConfig.deleteFromKeychain(key: "navidrome_username")
            AppConfig.deleteFromKeychain(key: "navidrome_password")
            AppConfig.serverURL = origServer
            AppConfig.keychainService = origService
        }

        let client = NavidromeClient()
        let albums = try await client.getAlbums(type: "newest", size: 10)

        // We can't assert specific content, but we can assert the response decoded
        XCTAssertNotNil(albums, "getAlbums() should return without throwing")
    }

    /// Verifies that invalid credentials produce an authFailed error.
    func testNavidromeInvalidCredentialsSurfaceAuthFailed() async throws {
        try requireEnv()
        guard !navidromeURL.isEmpty else {
            throw XCTSkip("Set NAVIDROME_SERVER_URL to run Navidrome API smoke tests")
        }

        let client = NavidromeClient()
        do {
            try await client.validateCredentials(
                serverURL: navidromeURL,
                username: "invalid_user_\(UUID().uuidString)",
                password: "wrong_password"
            )
            XCTFail("Expected authFailed or serverError but got no error")
        } catch NavidromeError.authFailed {
            // Pass — server correctly rejected bad credentials
        } catch NavidromeError.serverError {
            // Also acceptable — Subsonic error envelope with code 40
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    // MARK: - Sync service config smoke test

    /// Verifies the Go sync service /api/config endpoint returns expected JSON structure.
    func testSyncServiceConfigEndpoint() async throws {
        try requireEnv()

        guard let url = URL(string: "\(syncURL)/api/config") else {
            XCTFail("Could not build config URL from NAVIDROME_TEST_URL")
            return
        }

        let (data, response) = try await URLSession.shared.data(from: url)
        let http = try XCTUnwrap(response as? HTTPURLResponse)
        XCTAssertEqual(http.statusCode, 200, "/api/config must return 200")

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        XCTAssertNotNil(json, "/api/config must return a JSON object")
    }
}
