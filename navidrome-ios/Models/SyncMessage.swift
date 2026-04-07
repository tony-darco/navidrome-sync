import Foundation

// MARK: - Message Types

nonisolated enum MessageType: String, Codable, Sendable {
    // Inbound (client → server)
    case register = "REGISTER"
    case nowPlaying = "NOW_PLAYING"
    case positionUpdate = "POSITION_UPDATE"
    case claim = "CLAIM"
    case play = "PLAY"
    case pause = "PAUSE"
    case next = "NEXT"
    case prev = "PREV"
    case seek = "SEEK"
    case playSong = "PLAY_SONG"
    case loadQueue = "LOAD_QUEUE"
    case setQueue = "SET_QUEUE"
    case setPlaybackOptions = "SET_PLAYBACK_OPTIONS"
    case playlistChanged = "PLAYLIST_CHANGED"
    case starChanged = "STAR_CHANGED"

    // Outbound (server → client)
    case stateSync = "STATE_SYNC"
    case command = "COMMAND"
    case roleChange = "ROLE_CHANGE"
    case error = "ERROR"
    case playlistInvalidate = "PLAYLIST_INVALIDATE"
    case starNotify = "STAR_NOTIFY"
}

// MARK: - Envelope

/// Wire format for every WebSocket message.
/// Inbound messages include clientId; outbound from the server omit it.
nonisolated struct SyncEnvelope: Codable, Sendable {
    let type: MessageType
    var clientId: String?
    var payload: JSON?
}

// MARK: - Typed payloads

nonisolated struct RegisterPayload: Codable, Sendable {
    let clientType: String
}

nonisolated struct NowPlayingPayload: Codable, Sendable {
    let songId: String
    let title: String
    let artist: String
    let album: String
    let coverArtId: String
    let durationSecs: Int
    let positionSecs: Double
}

nonisolated struct PositionUpdatePayload: Codable, Sendable {
    let positionSecs: Double
}

nonisolated struct SeekPayload: Codable, Sendable {
    let positionSecs: Double
}

nonisolated struct StateSyncPayload: Codable, Sendable {
    let activeClientId: String?
    let song: NowPlayingSong?
    let clients: [ConnectedClient]
    let queue: [QueueItemPayload]?
    let queueIndex: Int?
    let shuffle: Bool?
    let repeatMode: String?
}

nonisolated struct RoleChangePayload: Codable, Sendable {
    let clientId: String
    let role: String
}

nonisolated struct CommandPayload: Codable, Sendable {
    let action: String
    let positionSecs: Double?
    let song: NowPlayingPayload?
    let queue: [QueueItemPayload]?
    let startIndex: Int?
    let queueIndex: Int?
}

// Extra models for sending commands
nonisolated struct PlaySongPayload: Codable, Sendable {
    let song: NowPlayingSong
}

nonisolated struct LoadQueuePayload: Codable, Sendable {
    let queue: [NowPlayingSong]
    let startIndex: Int
}


nonisolated struct ErrorPayload: Codable, Sendable {
    let code: String
    let message: String
}

nonisolated struct PlaylistChangedPayload: Codable, Sendable {
    let playlistId: String
    let action: String
}

nonisolated struct PlaylistInvalidation: Equatable, Sendable {
    let playlistId: String
    let action: String
}

nonisolated struct StarChangedPayload: Codable, Sendable {
    let songId: String
    let starred: Bool
}

nonisolated struct QueueItemPayload: Codable, Sendable {
    let songId: String
    let title: String
    let artist: String
    let album: String
    let coverArtId: String
    let durationSecs: Int

    func toNowPlayingSong() -> NowPlayingSong {
        NowPlayingSong(
            songId: songId,
            title: title,
            artist: artist,
            album: album,
            coverArtId: coverArtId,
            durationSecs: durationSecs,
            positionSecs: 0,
            starred: nil
        )
    }
}

nonisolated struct SetQueuePayload: Codable, Sendable {
    let queue: [QueueItemPayload]
    let queueIndex: Int
}

nonisolated struct PlaybackOptionsPayload: Codable, Sendable {
    let shuffle: Bool
    let repeatMode: String
}

// MARK: - Lightweight JSON wrapper

/// A thin wrapper that preserves arbitrary JSON so the generic `payload` field
/// can be decoded and then re-decoded into a concrete type on demand.
nonisolated enum JSON: Codable, Sendable {
    case object([String: JSON])
    case array([JSON])
    case string(String)
    case number(Double)
    case bool(Bool)
    case null

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let b = try? container.decode(Bool.self) {
            self = .bool(b)
        } else if let n = try? container.decode(Double.self) {
            self = .number(n)
        } else if let s = try? container.decode(String.self) {
            self = .string(s)
        } else if let arr = try? container.decode([JSON].self) {
            self = .array(arr)
        } else if let obj = try? container.decode([String: JSON].self) {
            self = .object(obj)
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unsupported JSON value")
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .object(let obj): try container.encode(obj)
        case .array(let arr): try container.encode(arr)
        case .string(let s): try container.encode(s)
        case .number(let n): try container.encode(n)
        case .bool(let b): try container.encode(b)
        case .null: try container.encodeNil()
        }
    }

    /// Re-decode the JSON blob into a concrete Codable type.
    func decode<T: Decodable>(_ type: T.Type) -> T? {
        guard let data = try? JSONEncoder().encode(self) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }
}
