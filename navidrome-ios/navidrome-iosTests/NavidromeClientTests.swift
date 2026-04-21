import Testing
import Foundation
@testable import navidrome_ios

// MARK: - MockURLProtocol

/// Intercepts URLSession requests in tests and returns canned responses.
final class MockURLProtocol: URLProtocol {
    // nonisolated(unsafe): accessed from both test code (main actor) and URLSession's
    // internal queue. Test controls ordering so no real race occurs.
    nonisolated(unsafe) static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    nonisolated override class func canInit(with request: URLRequest) -> Bool { true }
    nonisolated override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    nonisolated override func startLoading() {
        guard let handler = MockURLProtocol.requestHandler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }
        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    nonisolated override func stopLoading() {}
}

// MARK: - NavidromeClientTests

@Suite("NavidromeClient URL construction and error handling")
struct NavidromeClientTests {

    // MARK: - Setup helpers

    private func makeClient() -> NavidromeClient {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        return NavidromeClient(session: URLSession(configuration: config))
    }

    /// Sets login state scoped to a unique keychain service for this test run.
    private func setLoginState(
        server: String = "http://test.server:4533",
        user: String = "testuser",
        pass: String = "testpass"
    ) -> String {
        let testService = "navidrome-tests-\(UUID().uuidString)"
        AppConfig.keychainService = testService
        AppConfig.serverURL = server
        AppConfig.username = user
        AppConfig.password = pass
        return testService
    }

    private func restoreLoginState(originalService: String, originalServer: String?) {
        AppConfig.deleteFromKeychain(key: "navidrome_username")
        AppConfig.deleteFromKeychain(key: "navidrome_password")
        AppConfig.serverURL = originalServer
        AppConfig.keychainService = originalService
    }

    private func okResponse(url: URL) -> HTTPURLResponse {
        HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
    }

    private func albumListJSON(albums: [[String: Any]] = []) throws -> Data {
        try JSONSerialization.data(withJSONObject: [
            "subsonic-response": [
                "status": "ok",
                "version": "1.16.1",
                "albumList2": ["album": albums],
            ],
        ])
    }

    // MARK: - URL construction

    @Test("streamURL includes all required Subsonic query params")
    func streamURLIncludesRequiredParams() {
        let origService = AppConfig.keychainService
        let origServer = AppConfig.serverURL
        let testService = setLoginState()
        defer { restoreLoginState(originalService: origService, originalServer: origServer) }
        _ = testService

        let client = NavidromeClient()
        guard let url = client.streamURL(songId: "abc123") else {
            Issue.record("streamURL returned nil")
            return
        }
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems ?? []
        let params = Dictionary(uniqueKeysWithValues: items.map { ($0.name, $0.value ?? "") })

        #expect(url.path == "/rest/stream.view")
        #expect(params["id"] == "abc123")
        #expect(params["u"] == "testuser")
        #expect(params["p"] == "testpass")
        #expect(params["v"] == "1.16.1")
        #expect(params["c"] == "navidrome-ios")
        #expect(params["f"] == "json")
    }

    @Test("streamURL returns nil when not logged in")
    func streamURLNilWhenNotLoggedIn() {
        let origServer = AppConfig.serverURL
        let origService = AppConfig.keychainService
        let testService = "navidrome-tests-\(UUID().uuidString)"
        AppConfig.keychainService = testService
        AppConfig.serverURL = nil
        AppConfig.deleteFromKeychain(key: "navidrome_username")
        AppConfig.deleteFromKeychain(key: "navidrome_password")
        defer {
            AppConfig.serverURL = origServer
            AppConfig.keychainService = origService
        }

        #expect(NavidromeClient().streamURL(songId: "x") == nil)
    }

    @Test("streamURL uses configured server base URL and scheme")
    func streamURLUsesServerBase() {
        let origService = AppConfig.keychainService
        let origServer = AppConfig.serverURL
        let testService = setLoginState(server: "https://music.example.com")
        defer { restoreLoginState(originalService: origService, originalServer: origServer) }
        _ = testService

        guard let url = NavidromeClient().streamURL(songId: "s1") else {
            Issue.record("streamURL returned nil")
            return
        }
        #expect(url.host == "music.example.com")
        #expect(url.scheme == "https")
    }

    // MARK: - Response parsing

    @Test("getAlbums decodes ok response into Album array")
    func getAlbumsDecodesOkResponse() async throws {
        let origService = AppConfig.keychainService
        let origServer = AppConfig.serverURL
        let testService = setLoginState()
        defer { restoreLoginState(originalService: origService, originalServer: origServer) }
        _ = testService

        let albumJSON: [String: Any] = [
            "id": "alb-1",
            "name": "Test Album",
            "artist": "Test Artist",
            "coverArt": "cov-1",
            "songCount": 10,
            "year": 2020,
        ]
        MockURLProtocol.requestHandler = { req in
            let data = try JSONSerialization.data(withJSONObject: [
                "subsonic-response": [
                    "status": "ok",
                    "version": "1.16.1",
                    "albumList2": ["album": [albumJSON]],
                ],
            ])
            return (HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, data)
        }

        let albums = try await makeClient().getAlbums()
        #expect(albums.count == 1)
        #expect(albums[0].id == "alb-1")
        #expect(albums[0].name == "Test Album")
        #expect(albums[0].artist == "Test Artist")
    }

    @Test("getAlbums returns empty array when albumList2 is absent")
    func getAlbumsEmptyWhenMissingList() async throws {
        let origService = AppConfig.keychainService
        let origServer = AppConfig.serverURL
        let testService = setLoginState()
        defer { restoreLoginState(originalService: origService, originalServer: origServer) }
        _ = testService

        MockURLProtocol.requestHandler = { req in
            let data = try JSONSerialization.data(withJSONObject: [
                "subsonic-response": ["status": "ok", "version": "1.16.1"],
            ])
            return (HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, data)
        }

        let albums = try await makeClient().getAlbums()
        #expect(albums.isEmpty)
    }

    @Test("getAlbum with title field falls back correctly")
    func getAlbumTitleFallback() async throws {
        let origService = AppConfig.keychainService
        let origServer = AppConfig.serverURL
        let testService = setLoginState()
        defer { restoreLoginState(originalService: origService, originalServer: origServer) }
        _ = testService

        MockURLProtocol.requestHandler = { req in
            let data = try JSONSerialization.data(withJSONObject: [
                "subsonic-response": [
                    "status": "ok",
                    "version": "1.16.1",
                    "album": [
                        "id": "alb-2",
                        "title": "Title Field Album",  // uses title instead of name
                        "albumArtist": "Album Artist",  // uses albumArtist instead of artist
                        "coverArt": "cov-2",
                        "songCount": 3,
                    ],
                ],
            ])
            return (HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, data)
        }

        let (album, _) = try await makeClient().getAlbum(id: "alb-2")
        #expect(album.name == "Title Field Album")
        #expect(album.artist == "Album Artist")
    }

    // MARK: - Error paths

    @Test("HTTP 401 throws NavidromeError.badResponse")
    func http401ThrowsBadResponse() async {
        let origService = AppConfig.keychainService
        let origServer = AppConfig.serverURL
        let testService = setLoginState()
        defer { restoreLoginState(originalService: origService, originalServer: origServer) }
        _ = testService

        MockURLProtocol.requestHandler = { req in
            (HTTPURLResponse(url: req.url!, statusCode: 401, httpVersion: nil, headerFields: nil)!,
             Data("Unauthorized".utf8))
        }

        await #expect(throws: NavidromeError.badResponse) {
            try await makeClient().getAlbums()
        }
    }

    @Test("HTTP 500 throws NavidromeError.badResponse")
    func http500ThrowsBadResponse() async {
        let origService = AppConfig.keychainService
        let origServer = AppConfig.serverURL
        let testService = setLoginState()
        defer { restoreLoginState(originalService: origService, originalServer: origServer) }
        _ = testService

        MockURLProtocol.requestHandler = { req in
            (HTTPURLResponse(url: req.url!, statusCode: 500, httpVersion: nil, headerFields: nil)!,
             Data("Internal Server Error".utf8))
        }

        await #expect(throws: NavidromeError.badResponse) {
            try await makeClient().getAlbums()
        }
    }

    @Test("Subsonic failed status throws NavidromeError.serverError with code 40")
    func subsonicFailedStatusThrowsServerError() async throws {
        let origService = AppConfig.keychainService
        let origServer = AppConfig.serverURL
        let testService = setLoginState()
        defer { restoreLoginState(originalService: origService, originalServer: origServer) }
        _ = testService

        MockURLProtocol.requestHandler = { req in
            let data = try JSONSerialization.data(withJSONObject: [
                "subsonic-response": [
                    "status": "failed",
                    "version": "1.16.1",
                    "error": ["code": 40, "message": "Wrong username or password"],
                ],
            ])
            return (HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, data)
        }

        do {
            _ = try await makeClient().getAlbums()
            Issue.record("Expected serverError to be thrown")
        } catch NavidromeError.serverError(let code, _) {
            #expect(code == 40)
        } catch {
            Issue.record("Unexpected error type: \(type(of: error))")
        }
    }

    @Test("Malformed JSON body throws DecodingError")
    func malformedJSONThrowsDecodingError() async {
        let origService = AppConfig.keychainService
        let origServer = AppConfig.serverURL
        let testService = setLoginState()
        defer { restoreLoginState(originalService: origService, originalServer: origServer) }
        _ = testService

        MockURLProtocol.requestHandler = { req in
            (HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!,
             Data("not json {{{ garbage".utf8))
        }

        do {
            _ = try await makeClient().getAlbums()
            Issue.record("Expected DecodingError")
        } catch is DecodingError {
            // Pass — malformed JSON must surface as DecodingError
        } catch {
            Issue.record("Got unexpected error type: \(type(of: error))")
        }
    }

    @Test("Network timeout propagates as URLError.timedOut")
    func networkTimeoutPropagatesAsURLError() async {
        let origService = AppConfig.keychainService
        let origServer = AppConfig.serverURL
        let testService = setLoginState()
        defer { restoreLoginState(originalService: origService, originalServer: origServer) }
        _ = testService

        MockURLProtocol.requestHandler = { _ in throw URLError(.timedOut) }

        do {
            _ = try await makeClient().getAlbums()
            Issue.record("Expected URLError")
        } catch let error as URLError {
            #expect(error.code == .timedOut)
        } catch {
            Issue.record("Got unexpected error type: \(type(of: error))")
        }
    }

    // MARK: - Credential validation

    @Test("validateCredentials throws authFailed on Subsonic auth rejection")
    func validateCredentialsAuthFailed() async {
        MockURLProtocol.requestHandler = { req in
            let data = try JSONSerialization.data(withJSONObject: [
                "subsonic-response": [
                    "status": "failed",
                    "version": "1.16.1",
                    "error": ["code": 40, "message": "Wrong username or password"],
                ],
            ])
            return (HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, data)
        }

        await #expect(throws: NavidromeError.authFailed) {
            try await makeClient().validateCredentials(
                serverURL: "http://test.server:4533",
                username: "testuser",
                password: "wrongpass"
            )
        }
    }

    @Test("validateCredentials succeeds on ok status without throwing")
    func validateCredentialsSucceeds() async throws {
        MockURLProtocol.requestHandler = { req in
            let data = try JSONSerialization.data(withJSONObject: [
                "subsonic-response": ["status": "ok", "version": "1.16.1"],
            ])
            return (HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, data)
        }

        // Should not throw
        try await makeClient().validateCredentials(
            serverURL: "http://test.server:4533",
            username: "testuser",
            password: "testpass"
        )
    }

    @Test("validateCredentials throws badResponse on HTTP 401")
    func validateCredentials401ThrowsBadResponse() async {
        MockURLProtocol.requestHandler = { req in
            (HTTPURLResponse(url: req.url!, statusCode: 401, httpVersion: nil, headerFields: nil)!,
             Data())
        }

        await #expect(throws: NavidromeError.badResponse) {
            try await makeClient().validateCredentials(
                serverURL: "http://test.server:4533",
                username: "testuser",
                password: "testpass"
            )
        }
    }

    @Test("getAlbums request includes correct Subsonic query params")
    func getAlbumsRequestIncludesCorrectParams() async throws {
        let origService = AppConfig.keychainService
        let origServer = AppConfig.serverURL
        let testService = setLoginState()
        defer { restoreLoginState(originalService: origService, originalServer: origServer) }
        _ = testService

        var capturedURL: URL?
        MockURLProtocol.requestHandler = { req in
            capturedURL = req.url
            let data = try JSONSerialization.data(withJSONObject: [
                "subsonic-response": ["status": "ok", "version": "1.16.1", "albumList2": ["album": []]],
            ])
            return (HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, data)
        }

        _ = try await makeClient().getAlbums(type: "recent", size: 25, offset: 10)

        guard let url = capturedURL else {
            Issue.record("No request was made")
            return
        }
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        let params = Dictionary(uniqueKeysWithValues: items.map { ($0.name, $0.value ?? "") })

        #expect(url.path == "/rest/getAlbumList2.view")
        #expect(params["type"] == "recent")
        #expect(params["size"] == "25")
        #expect(params["offset"] == "10")
        #expect(params["f"] == "json")
        #expect(params["u"] == "testuser")
    }
}
