import XCTest
@testable import navidrome_ios

@MainActor
final class DownloadManagerTests: XCTestCase {
    private var oldAutoCache: Bool = false

    override func setUp() async throws {
        try await super.setUp()
        oldAutoCache = AppConfig.autoCacheEnabled
        AppConfig.autoCacheEnabled = false
    }

    override func tearDown() async throws {
        AppConfig.autoCacheEnabled = oldAutoCache
        try await super.tearDown()
    }

    func testDownloadWithMissingStreamURLFailsPermanently() async {
        let nav = NullStreamNavidromeClient()
        let manager = DownloadManager(
            sessionConfiguration: .ephemeral,
            navidromeClient: nav
        )
        manager.removeAll()

        let song = Song(
            id: "song-1",
            title: "Song",
            artist: "Artist",
            album: "Album",
            albumId: "album-1",
            coverArt: "cover-1",
            duration: 120,
            track: 1
        )

        manager.download(song: song)

        guard let task = manager.taskMap[song.id] else {
            XCTFail("Expected task to exist")
            return
        }

        switch task.status {
        case .failed(let reason, let attempts):
            XCTAssertEqual(attempts, 1)
            XCTAssertEqual(reason, .permanent(statusCode: nil))
        default:
            XCTFail("Expected failed status, got \(task.status)")
        }
    }

    func testEnqueueIfAutoCacheRespectsSetting() async {
        let manager = DownloadManager(
            sessionConfiguration: .ephemeral,
            navidromeClient: NullStreamNavidromeClient()
        )
        manager.removeAll()

        let song = NowPlayingSong(
            songId: "np-1",
            title: "NPS",
            artist: "Artist",
            album: "Album",
            albumId: "album-1",
            artistId: "artist-1",
            coverArtId: "cover-1",
            durationSecs: 100,
            positionSecs: 0
        )

        AppConfig.autoCacheEnabled = false
        manager.enqueueIfAutoCache(song: song)
        XCTAssertNil(manager.taskMap[song.songId])

        AppConfig.autoCacheEnabled = true
        manager.enqueueIfAutoCache(song: song)
        XCTAssertNotNil(manager.taskMap[song.songId])
    }

    func testRetryFailedResetsAttemptsThenFailsAgainWhenNoURL() async {
        let manager = DownloadManager(
            sessionConfiguration: .ephemeral,
            navidromeClient: NullStreamNavidromeClient()
        )
        manager.removeAll()

        let song = Song(
            id: "song-2",
            title: "Song",
            artist: "Artist",
            album: "Album",
            albumId: "album-1",
            coverArt: "cover-1",
            duration: 120,
            track: 1
        )

        manager.download(song: song)
        manager.retryFailed(songId: song.id)

        guard let task = manager.taskMap[song.id] else {
            XCTFail("Expected task to exist")
            return
        }

        switch task.status {
        case .failed(_, let attempts):
            XCTAssertEqual(attempts, 1)
        default:
            XCTFail("Expected failed status after retry, got \(task.status)")
        }
    }

    func testRemoveAllClearsTaskState() async {
        let manager = DownloadManager(
            sessionConfiguration: .ephemeral,
            navidromeClient: NullStreamNavidromeClient()
        )
        manager.removeAll()

        let songA = Song(id: "a", title: "A", artist: "AR", album: "AL", albumId: "al-a", coverArt: "c", duration: 1, track: 1)
        let songB = Song(id: "b", title: "B", artist: "AR", album: "AL", albumId: "al-b", coverArt: "c", duration: 1, track: 1)

        manager.download(song: songA)
        manager.download(song: songB)
        XCTAssertFalse(manager.taskMap.isEmpty)

        manager.removeAll()

        XCTAssertTrue(manager.taskMap.isEmpty)
        XCTAssertTrue(manager.completedDownloads.isEmpty)
        XCTAssertEqual(manager.activeCount, 0)
    }
}

private actor NullStreamNavidromeClient: NavidromeClientProtocol {
    func star(id: String) async throws {}
    func unstar(id: String) async throws {}
    func scrobble(songId: String) async throws {}
    func fetchCoverArt(id: String, size: Int) async -> UIImage? { nil }
    nonisolated func streamURL(songId: String) -> URL? { nil }
}
