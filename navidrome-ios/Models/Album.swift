import Foundation

// MARK: - Album

nonisolated struct Album: Codable, Identifiable, Sendable {
    let id: String
    let name: String
    let artist: String
    let coverArt: String
    let songCount: Int
    let year: Int?
    let starred: String?

    var isStarred: Bool { starred != nil }

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
        starred = try? c.decode(String.self, forKey: .starred)
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, title, artist, albumArtist, coverArt, songCount, year, starred
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(name, forKey: .name)
        try c.encode(artist, forKey: .artist)
        try c.encode(coverArt, forKey: .coverArt)
        try c.encode(songCount, forKey: .songCount)
        try c.encodeIfPresent(year, forKey: .year)
        try c.encodeIfPresent(starred, forKey: .starred)
    }

    init(id: String, name: String, artist: String, coverArt: String, songCount: Int, year: Int?, starred: String? = nil) {
        self.id = id
        self.name = name
        self.artist = artist
        self.coverArt = coverArt
        self.songCount = songCount
        self.year = year
        self.starred = starred
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
    let starred: String?

    var isStarred: Bool { starred != nil }

    private enum CodingKeys: String, CodingKey {
        case id, title, artist, album, albumId, coverArt, duration, track, starred
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
        starred = try? c.decode(String.self, forKey: .starred)
    }

    init(id: String, title: String, artist: String, album: String, albumId: String, coverArt: String, duration: Int, track: Int, starred: String? = nil) {
        self.id = id
        self.title = title
        self.artist = artist
        self.album = album
        self.albumId = albumId
        self.coverArt = coverArt
        self.duration = duration
        self.track = track
        self.starred = starred
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
            positionSecs: 0,
            starred: isStarred
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
    let playlists: PlaylistsWrapper?
    let playlist: PlaylistWithSongs?
    let artists: ArtistsWrapper?
    let artist: ArtistDetail?
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
            year: year,
            starred: nil
        )
    }
}

nonisolated struct SearchResult3: Decodable, Sendable {
    let album: [Album]?
    let song: [Song]?
}

// MARK: - Playlist models

nonisolated struct Playlist: Codable, Identifiable, Sendable, Hashable {
    let id: String
    let name: String
    let songCount: Int
    let coverArt: String

    private enum CodingKeys: String, CodingKey {
        case id, name, songCount, coverArt
    }

    init(id: String, name: String, songCount: Int, coverArt: String) {
        self.id = id
        self.name = name
        self.songCount = songCount
        self.coverArt = coverArt
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        name = (try? c.decode(String.self, forKey: .name)) ?? ""
        songCount = (try? c.decode(Int.self, forKey: .songCount)) ?? 0
        coverArt = (try? c.decode(String.self, forKey: .coverArt)) ?? ""
    }
}

nonisolated struct PlaylistWithSongs: Decodable, Sendable {
    let id: String
    let name: String
    let songCount: Int
    let coverArt: String
    let entry: [Song]?

    private enum CodingKeys: String, CodingKey {
        case id, name, songCount, coverArt, entry
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        name = (try? c.decode(String.self, forKey: .name)) ?? ""
        songCount = (try? c.decode(Int.self, forKey: .songCount)) ?? 0
        coverArt = (try? c.decode(String.self, forKey: .coverArt)) ?? ""
        entry = try? c.decode([Song].self, forKey: .entry)
    }

    func toPlaylist() -> Playlist {
        Playlist(id: id, name: name, songCount: songCount, coverArt: coverArt)
    }
}

nonisolated struct PlaylistsWrapper: Decodable, Sendable {
    let playlist: [Playlist]?
}

// MARK: - Artist models

nonisolated struct ArtistID3: Codable, Identifiable, Sendable, Hashable {
    let id: String
    let name: String
    let albumCount: Int

    private enum CodingKeys: String, CodingKey {
        case id, name, albumCount
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        name = (try? c.decode(String.self, forKey: .name)) ?? ""
        albumCount = (try? c.decode(Int.self, forKey: .albumCount)) ?? 0
    }
}

nonisolated struct ArtistIndex: Codable, Identifiable, Sendable {
    let name: String
    let artist: [ArtistID3]

    var id: String { name }

    private enum CodingKeys: String, CodingKey {
        case name, artist
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        name = (try? c.decode(String.self, forKey: .name)) ?? ""
        artist = (try? c.decode([ArtistID3].self, forKey: .artist)) ?? []
    }
}

nonisolated struct ArtistsWrapper: Decodable, Sendable {
    let index: [ArtistIndex]?
}

nonisolated struct ArtistDetail: Decodable, Sendable {
    let id: String
    let name: String
    let album: [Album]?

    private enum CodingKeys: String, CodingKey {
        case id, name, album
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        name = (try? c.decode(String.self, forKey: .name)) ?? ""
        album = try? c.decode([Album].self, forKey: .album)
    }
}
