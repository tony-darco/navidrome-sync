import Foundation

/// The current song as broadcast in STATE_SYNC payloads.
nonisolated struct NowPlayingSong: Codable, Equatable, Sendable {
    let songId: String
    let title: String
    let artist: String
    let album: String
    var albumId: String? = nil
    var artistId: String? = nil
    let coverArtId: String
    let durationSecs: Int
    var positionSecs: Double
    var isPlaying: Bool?
    var starred: Bool? = nil
}

/// Per-client summary included in STATE_SYNC broadcasts.
nonisolated struct ConnectedClient: Codable, Identifiable, Sendable {
    let clientId: String
    let clientType: String
    let role: String

    var id: String { clientId }
}
