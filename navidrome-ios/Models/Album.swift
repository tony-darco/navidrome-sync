import Foundation

// MARK: - Album

nonisolated struct Album: Codable, Identifiable, Sendable {
    let id: String
    let name: String
    let artist: String
    let coverArt: String
    let songCount: Int
    let year: Int?

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        name = (try? c.decode(String.self, forKey: .name))
            ?? (try? c.decode(String.self, forKey: .title))
            ?? ""
        artist = (try? c.decode(String.self, forKey: .artist))
            ?? (try? c.decode(String.self, forKey: .albumArtist))
            ?? ""
        coverArt = (try? c.decode(String.self, forKey: .coverArt)) ?? ""
        songCount = (try? c.decode(Int.self, forKey: .songCount)) ?? 0
        year = try? c.decode(Int.self, forKey: .year)
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, title, artist, albumArtist, coverArt, songCount, year
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(name, forKey: .name)
        try c.encode(artist, forKey: .artist)
        try c.encode(coverArt, forKey: .coverArt)
        try c.encode(songCount, forKey: .songCount)
        try c.encodeIfPresent(year, forKey: .year)
    }

    init(id: String, name: String, artist: String, coverArt: String, songCount: Int, year: Int?) {
        self.id = id
        self.name = name
        self.artist = artist
        self.coverArt = coverArt
        self.songCount = songCount
        self.year = year
    }
}

// MARK: - Song

nonisolated struct Song: Codable, Identifiable, Sendable {
    let id: String
    let title: String
    let artist: String
    let album: String
    let albumId: String
    let coverArt: String
    let duration: Int
    let track: Int

    private enum CodingKeys: String, CodingKey {
        case id, title, artist, album, albumId, coverArt, duration, track
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        title = (try? c.decode(String.self, forKey: .title)) ?? ""
        artist = (try? c.decode(String.self, forKey: .artist)) ?? ""
        album = (try? c.decode(String.self, forKey: .album)) ?? ""
        albumId = (try? c.decode(String.self, forKey: .albumId)) ?? ""
        coverArt = (try? c.decode(String.self, forKey: .coverArt)) ?? ""
        duration = (try? c.decode(Int.self, forKey: .duration)) ?? 0
        track = (try? c.decode(Int.self, forKey: .track)) ?? 0
    }

    init(id: String, title: String, artist: String, album: String, albumId: String, coverArt: String, duration: Int, track: Int) {
        self.id = id
        self.title = title
        self.artist = artist
        self.album = album
        self.albumId = albumId
        self.coverArt = coverArt
        self.duration = duration
        self.track = track
    }

    /// Convert to NowPlayingSong for playback.
    func toNowPlayingSong() -> NowPlayingSong {
        NowPlayingSong(
            songId: id,
            title: title,
            artist: artist,
            album: album,
            coverArtId: coverArt,
            durationSecs: duration,
            positionSecs: 0
        )
    }
}

// MARK: - Subsonic response wrappers

nonisolated struct SubsonicWrapper: Decodable, Sendable {
    let subsonicResponse: SubsonicResponse

    enum CodingKeys: String, CodingKey {
        case subsonicResponse = "subsonic-response"
    }
}

nonisolated struct SubsonicResponse: Decodable, Sendable {
    let status: String
    let albumList2: AlbumList2?
    let album: AlbumWithSongs?
    let searchResult3: SearchResult3?
}

nonisolated struct AlbumList2: Decodable, Sendable {
    let album: [Album]?
}

nonisolated struct AlbumWithSongs: Decodable, Sendable {
    let id: String
    let name: String?
    let artist: String?
    let coverArt: String?
    let songCount: Int?
    let year: Int?
    let song: [Song]?

    func toAlbum() -> Album {
        Album(
            id: id,
            name: name ?? "",
            artist: artist ?? "",
            coverArt: coverArt ?? "",
            songCount: songCount ?? 0,
            year: year
        )
    }
}

nonisolated struct SearchResult3: Decodable, Sendable {
    let album: [Album]?
    let song: [Song]?
}
