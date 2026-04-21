import Foundation
import UIKit
@testable import navidrome_ios

actor MockNavidromeClient: NavidromeClientProtocol {
    var streamURLs: [String: URL] = [:]
    var artworkByCoverId: [String: UIImage] = [:]

    private(set) var starredIds: [String] = []
    private(set) var unstarredIds: [String] = []
    private(set) var scrobbledIds: [String] = []

    func star(id: String) async throws {
        starredIds.append(id)
    }

    func unstar(id: String) async throws {
        unstarredIds.append(id)
    }

    func scrobble(songId: String) async throws {
        scrobbledIds.append(songId)
    }

    func fetchCoverArt(id: String, size: Int) async -> UIImage? {
        artworkByCoverId[id]
    }

    nonisolated func streamURL(songId: String) -> URL? {
        nil
    }
}
