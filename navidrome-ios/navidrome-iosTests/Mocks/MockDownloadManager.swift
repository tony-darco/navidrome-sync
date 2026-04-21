import Foundation
@testable import navidrome_ios

@MainActor
final class MockDownloadManager: DownloadManaging {
    var downloadedSongIds: Set<String> = []
    var localURLs: [String: URL] = [:]
    private(set) var autoCachedSongs: [NowPlayingSong] = []

    func enqueueIfAutoCache(song: NowPlayingSong) {
        autoCachedSongs.append(song)
    }

    func isDownloaded(songId: String) -> Bool {
        downloadedSongIds.contains(songId)
    }

    func localURL(for songId: String) -> URL? {
        localURLs[songId]
    }
}
