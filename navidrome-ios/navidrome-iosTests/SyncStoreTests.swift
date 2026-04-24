import XCTest
@testable import navidrome_ios

@MainActor
final class SyncStoreTests: XCTestCase {
    private var oldSyncURL: String?
    private var oldOfflineMode: Bool = false

    override func setUp() async throws {
        try await super.setUp()
        oldSyncURL = AppConfig.syncServiceURL
        oldOfflineMode = AppConfig.offlineMode
        AppConfig.offlineMode = false
        AppConfig.syncServiceURL = "http://localhost:8080"
    }

    override func tearDown() async throws {
        AppConfig.syncServiceURL = oldSyncURL
        AppConfig.offlineMode = oldOfflineMode
        try await super.tearDown()
    }

    func testConnectUsesSyncServiceURL() async {
        let syncClient = MockSyncClient()
        let store = SyncStore(
            syncClient: syncClient,
            navidromeClient: MockNavidromeClient(),
            downloadManager: MockDownloadManager(),
            audioPlayer: AudioPlayer()
        )

        store.connect()

        XCTAssertEqual(syncClient.connectCalls.count, 1)
        XCTAssertEqual(syncClient.connectCalls.first?.baseURL, "http://localhost:8080")
        XCTAssertEqual(syncClient.connectCalls.first?.clientId, store.myClientId)
        XCTAssertTrue(store.isConnected)
    }

    func testStateSyncObserverUpdatesQueueAndNowPlaying() async throws {
        let syncClient = MockSyncClient()
        let me = AppConfig.clientId
        let store = SyncStore(
            syncClient: syncClient,
            navidromeClient: MockNavidromeClient(),
            downloadManager: MockDownloadManager(),
            audioPlayer: AudioPlayer()
        )

        let payload = StateSyncPayload(
            activeClientId: "active-web",
            song: NowPlayingSong(
                songId: "song-1",
                title: "Test Song",
                artist: "Test Artist",
                album: "Test Album",
                albumId: "album-1",
                artistId: "artist-1",
                coverArtId: "cover-1",
                durationSecs: 200,
                positionSecs: 42.0,
                isPlaying: true,
                starred: false
            ),
            clients: [
                ConnectedClient(clientId: me, clientType: "ios", role: "observer"),
                ConnectedClient(clientId: "active-web", clientType: "web", role: "active")
            ],
            queue: [
                QueueItemPayload(
                    songId: "song-1", title: "Test Song", artist: "Test Artist",
                    album: "Test Album", albumId: "album-1", artistId: "artist-1",
                    coverArtId: "cover-1", durationSecs: 200
                ),
                QueueItemPayload(
                    songId: "song-2", title: "Next Song", artist: "Test Artist",
                    album: "Test Album", albumId: "album-1", artistId: "artist-1",
                    coverArtId: "cover-2", durationSecs: 180
                )
            ],
            queueIndex: 0,
            shuffle: false,
            repeatMode: "off"
        )

        let envelope = SyncEnvelope(type: .stateSync, clientId: nil, payload: try payload.asJSON())
        syncClient.simulateIncoming(envelope)

        await Task.yield()

        XCTAssertEqual(store.myRole, "observer")
        XCTAssertEqual(store.activeClientId, "active-web")
        XCTAssertEqual(store.queue.count, 2)
        XCTAssertEqual(store.queue.first?.songId, "song-1")
        XCTAssertEqual(store.nowPlaying?.songId, "song-1")
        XCTAssertEqual(store.position, 42.0)
        XCTAssertTrue(store.isPlaying)
    }

    // Regression test: when the app (re)starts and the server reports the iOS client
    // as active with isPlaying=false (hub paused the state on disconnect), the AudioPlayer
    // should still be loaded so that tapping play works without picking a new song.
    func testBecomeActiveWithPausedSongLoadsPlayerButDoesNotAutoPlay() async throws {
        let syncClient = MockSyncClient()
        let me = AppConfig.clientId
        let mockDownloadManager = MockDownloadManager()
        // Provide a local URL so loadAndPlay can reach audioPlayer.play()
        mockDownloadManager.localURLs["song-1"] = URL(string: "file:///tmp/test-song.mp3")!

        let store = SyncStore(
            syncClient: syncClient,
            navidromeClient: MockNavidromeClient(),
            downloadManager: mockDownloadManager,
            audioPlayer: AudioPlayer()
        )

        // Server assigns us as active with the song paused (isPlaying=false).
        // This matches the scenario after an app rebuild or when connecting fresh
        // while the native Navidrome client had been playing.
        let payload = StateSyncPayload(
            activeClientId: me,
            song: NowPlayingSong(
                songId: "song-1",
                title: "Test Song",
                artist: "Test Artist",
                album: "Test Album",
                albumId: "album-1",
                artistId: "artist-1",
                coverArtId: "cover-1",
                durationSecs: 200,
                positionSecs: 30.0,
                isPlaying: false,
                starred: false
            ),
            clients: [
                ConnectedClient(clientId: me, clientType: "ios", role: "active")
            ],
            queue: nil,
            queueIndex: nil,
            shuffle: nil,
            repeatMode: nil
        )

        let envelope = SyncEnvelope(type: .stateSync, clientId: nil, payload: try payload.asJSON())
        syncClient.simulateIncoming(envelope)

        await Task.yield()

        // nowPlaying should be set (proves loadAndPlay was called, not skipped)
        XCTAssertEqual(store.nowPlaying?.songId, "song-1")
        // Should NOT be playing since the server reported isPlaying=false
        XCTAssertFalse(store.isPlaying)
        // Role should be active
        XCTAssertEqual(store.myRole, "active")
    }

    func testConcurrentStateSyncKeepsSingleActiveRoleInvariant() async throws {
        let syncClient = MockSyncClient()
        let me = AppConfig.clientId
        let store = SyncStore(
            syncClient: syncClient,
            navidromeClient: MockNavidromeClient(),
            downloadManager: MockDownloadManager(),
            audioPlayer: AudioPlayer()
        )

        let payloadA = StateSyncPayload(
            activeClientId: "A",
            song: nil,
            clients: [
                ConnectedClient(clientId: me, clientType: "ios", role: "observer"),
                ConnectedClient(clientId: "A", clientType: "web", role: "active")
            ],
            queue: nil,
            queueIndex: nil,
            shuffle: nil,
            repeatMode: nil
        )

        let payloadB = StateSyncPayload(
            activeClientId: "B",
            song: nil,
            clients: [
                ConnectedClient(clientId: me, clientType: "ios", role: "observer"),
                ConnectedClient(clientId: "B", clientType: "web", role: "active")
            ],
            queue: nil,
            queueIndex: nil,
            shuffle: nil,
            repeatMode: nil
        )

        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                syncClient.simulateIncoming(SyncEnvelope(type: .stateSync, clientId: nil, payload: try? payloadA.asJSON()))
            }
            group.addTask {
                syncClient.simulateIncoming(SyncEnvelope(type: .stateSync, clientId: nil, payload: try? payloadB.asJSON()))
            }
        }

        await Task.yield()

        let activeCount = store.connectedClients.filter { $0.role == "active" }.count
        XCTAssertEqual(activeCount, 1)
    }
}

private extension Encodable {
    func asJSON() throws -> JSON {
        let data = try JSONEncoder().encode(self)
        return try JSONDecoder().decode(JSON.self, from: data)
    }
}
