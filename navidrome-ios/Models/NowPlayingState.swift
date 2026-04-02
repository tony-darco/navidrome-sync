import Foundation

/// The current song as broadcast in STATE_SYNC payloads.
nonisolated struct NowPlayingSong: Codable, Equatable, Sendable {
    let songId: String
    let title: String
    let artist: String
    let album: String
    let coverArtId: String
    let durationSecs: Int
    var positionSecs: Double
}

/// Per-client summary included in STATE_SYNC broadcasts.
nonisolated struct ConnectedClient: Codable, Identifiable, Sendable {
    let clientId: String
    let clientType: String
    let role: String

    var id: String { clientId }
}
