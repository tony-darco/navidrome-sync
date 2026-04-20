import Testing
import Foundation
@testable import navidrome_ios

// MARK: - Test Fixture Helpers

/// Load a JSON fixture file from the TestFixtures bundle directory.
private func loadFixture(_ name: String) throws -> Data {
    // When running in an Xcode test bundle, look relative to the bundle resource path.
    // Fall back to compile-time #file path for SPM / command-line runs.
    let fileName = name.hasSuffix(".json") ? String(name.dropLast(5)) : name
    if let url = Bundle(for: _BundleAnchor.self).url(forResource: fileName, withExtension: "json", subdirectory: "TestFixtures") {
        return try Data(contentsOf: url)
    }
    // Fallback: resolve relative to this source file
    let thisFile = URL(fileURLWithPath: #filePath)
    let fixtureURL = thisFile
        .deletingLastPathComponent()
        .appendingPathComponent("TestFixtures")
        .appendingPathComponent("\(fileName).json")
    return try Data(contentsOf: fixtureURL)
}

/// Dummy class used only for `Bundle(for:)` resolution inside the test bundle.
private final class _BundleAnchor {}

// MARK: - Album Decoding

@Suite("Album Decoding")
struct AlbumDecodingTests {

    @Test("Decode album list with standard fields")
    func decodeStandardAlbum() throws {
        let data = try loadFixture("subsonic_get_album_list")
        let wrapper = try JSONDecoder().decode(SubsonicWrapper.self, from: data)

        #expect(wrapper.subsonicResponse.status == "ok")
        let albums = try #require(wrapper.subsonicResponse.albumList2?.album)
        #expect(albums.count == 3)

        let first = albums[0]
        #expect(first.id == "al-001")
        #expect(first.name == "Midnight Tales")
        #expect(first.artist == "The Wanderers")
        #expect(first.songCount == 12)
        #expect(first.year == 2023)
        #expect(first.isStarred == true)
    }

    @Test("Decode album using title/albumArtist fallback keys")
    func decodeFallbackKeys() throws {
        let data = try loadFixture("subsonic_get_album_list")
        let wrapper = try JSONDecoder().decode(SubsonicWrapper.self, from: data)
        let albums = try #require(wrapper.subsonicResponse.albumList2?.album)

        // Second album uses `title` instead of `name`, `albumArtist` instead of `artist`
        let second = albums[1]
        #expect(second.id == "al-002")
        #expect(second.name == "Electric Dawn")
        #expect(second.artist == "Neon Pulse")
        #expect(second.year == 2024)
        #expect(second.isStarred == false)
    }

    @Test("Decode album with minimal fields — missing optionals default gracefully")
    func decodeMinimalAlbum() throws {
        let data = try loadFixture("subsonic_get_album_list")
        let wrapper = try JSONDecoder().decode(SubsonicWrapper.self, from: data)
        let albums = try #require(wrapper.subsonicResponse.albumList2?.album)

        let third = albums[2]
        #expect(third.id == "al-003")
        #expect(third.name == "Quiet Rooms")
        #expect(third.artist == "")
        #expect(third.coverArt == "")
        #expect(third.songCount == 0)
        #expect(third.year == nil)
        #expect(third.isStarred == false)
    }

    @Test("Album encode → decode round-trip preserves all fields")
    func albumRoundTrip() throws {
        let album = Album(
            id: "rt-1", name: "Round Trip", artist: "Tester",
            coverArt: "rt-1", songCount: 5, year: 2025, starred: "2025-01-01"
        )
        let data = try JSONEncoder().encode(album)
        let decoded = try JSONDecoder().decode(Album.self, from: data)

        #expect(decoded.id == album.id)
        #expect(decoded.name == album.name)
        #expect(decoded.artist == album.artist)
        #expect(decoded.coverArt == album.coverArt)
        #expect(decoded.songCount == album.songCount)
        #expect(decoded.year == album.year)
        #expect(decoded.starred == album.starred)
    }
}

// MARK: - Song Decoding

@Suite("Song Decoding")
struct SongDecodingTests {

    @Test("Decode songs from album detail fixture")
    func decodeSongsFromAlbum() throws {
        let data = try loadFixture("subsonic_get_album")
        let wrapper = try JSONDecoder().decode(SubsonicWrapper.self, from: data)
        let albumDetail = try #require(wrapper.subsonicResponse.album)
        let songs = try #require(albumDetail.song)

        #expect(songs.count == 2)

        let first = songs[0]
        #expect(first.id == "s-001")
        #expect(first.title == "Opening")
        #expect(first.artist == "The Wanderers")
        #expect(first.albumId == "al-001")
        #expect(first.duration == 245)
        #expect(first.track == 1)
        #expect(first.isStarred == true)

        let second = songs[1]
        #expect(second.id == "s-002")
        #expect(second.isStarred == false)
    }

    @Test("Song.toNowPlayingSong() converts correctly")
    func songToNowPlayingSong() {
        let song = Song(
            id: "s-1", title: "Test Song", artist: "Artist",
            album: "Album", albumId: "al-1", artistId: "ar-1",
            coverArt: "ca-1", duration: 180, track: 3, starred: "2025-01-01"
        )
        let nps = song.toNowPlayingSong()

        #expect(nps.songId == "s-1")
        #expect(nps.title == "Test Song")
        #expect(nps.artist == "Artist")
        #expect(nps.album == "Album")
        #expect(nps.albumId == "al-1")
        #expect(nps.artistId == "ar-1")
        #expect(nps.coverArtId == "ca-1")
        #expect(nps.durationSecs == 180)
        #expect(nps.positionSecs == 0)
        #expect(nps.starred == true)
    }

    @Test("Song with missing optional fields decodes with defaults")
    func songMissingOptionals() throws {
        let json = """
        {"id": "s-min"}
        """.data(using: .utf8)!
        let song = try JSONDecoder().decode(Song.self, from: json)

        #expect(song.id == "s-min")
        #expect(song.title == "")
        #expect(song.artist == "")
        #expect(song.album == "")
        #expect(song.albumId == "")
        #expect(song.duration == 0)
        #expect(song.track == 0)
        #expect(song.isStarred == false)
    }
}

// MARK: - AlbumWithSongs Conversion

@Suite("AlbumWithSongs Conversion")
struct AlbumWithSongsTests {

    @Test("toAlbum() converts album detail to Album")
    func toAlbum() throws {
        let data = try loadFixture("subsonic_get_album")
        let wrapper = try JSONDecoder().decode(SubsonicWrapper.self, from: data)
        let detail = try #require(wrapper.subsonicResponse.album)
        let album = detail.toAlbum()

        #expect(album.id == "al-001")
        #expect(album.name == "Midnight Tales")
        #expect(album.artist == "The Wanderers")
        #expect(album.songCount == 2)
        #expect(album.year == 2023)
    }
}

// MARK: - Playlist Decoding

@Suite("Playlist Decoding")
struct PlaylistDecodingTests {

    @Test("Playlist decode with missing optional fields")
    func playlistMinimal() throws {
        let json = """
        {"id": "pl-1"}
        """.data(using: .utf8)!
        let playlist = try JSONDecoder().decode(Playlist.self, from: json)

        #expect(playlist.id == "pl-1")
        #expect(playlist.name == "")
        #expect(playlist.songCount == 0)
        #expect(playlist.coverArt == "")
    }

    @Test("Playlist encode → decode round-trip")
    func playlistRoundTrip() throws {
        let playlist = Playlist(id: "pl-1", name: "My Mix", songCount: 15, coverArt: "pl-1")
        let data = try JSONEncoder().encode(playlist)
        let decoded = try JSONDecoder().decode(Playlist.self, from: data)

        #expect(decoded.id == playlist.id)
        #expect(decoded.name == playlist.name)
        #expect(decoded.songCount == playlist.songCount)
        #expect(decoded.coverArt == playlist.coverArt)
    }

    @Test("Playlist conforms to Hashable")
    func playlistHashable() {
        let a = Playlist(id: "pl-1", name: "A", songCount: 1, coverArt: "")
        let b = Playlist(id: "pl-1", name: "A", songCount: 1, coverArt: "")
        let c = Playlist(id: "pl-2", name: "B", songCount: 2, coverArt: "")

        #expect(a == b)
        #expect(a != c)
        #expect(Set([a, b]).count == 1)
    }
}

// MARK: - ArtistID3 Decoding

@Suite("ArtistID3 Decoding")
struct ArtistID3DecodingTests {

    @Test("ArtistID3 decode with all fields")
    func decodeComplete() throws {
        let json = """
        {"id": "ar-1", "name": "Test Artist", "albumCount": 5}
        """.data(using: .utf8)!
        let artist = try JSONDecoder().decode(ArtistID3.self, from: json)

        #expect(artist.id == "ar-1")
        #expect(artist.name == "Test Artist")
        #expect(artist.albumCount == 5)
    }

    @Test("ArtistID3 decode with minimal fields")
    func decodeMinimal() throws {
        let json = """
        {"id": "ar-2"}
        """.data(using: .utf8)!
        let artist = try JSONDecoder().decode(ArtistID3.self, from: json)

        #expect(artist.id == "ar-2")
        #expect(artist.name == "")
        #expect(artist.albumCount == 0)
    }

    @Test("ArtistID3 conforms to Hashable")
    func artistHashable() {
        let a = ArtistID3(id: "ar-1", name: "A", albumCount: 1)
        let b = ArtistID3(id: "ar-1", name: "A", albumCount: 1)

        #expect(a == b)
        #expect(Set([a, b]).count == 1)
    }
}

// MARK: - Genre Decoding

@Suite("Genre Decoding")
struct GenreDecodingTests {

    @Test("Genre decode with all fields")
    func decodeFull() throws {
        let json = """
        {"value": "Rock", "songCount": 150, "albumCount": 20}
        """.data(using: .utf8)!
        let genre = try JSONDecoder().decode(Genre.self, from: json)

        #expect(genre.value == "Rock")
        #expect(genre.name == "Rock")
        #expect(genre.songCount == 150)
        #expect(genre.albumCount == 20)
        #expect(genre.id == "Rock")
    }

    @Test("Genre decode with minimal fields")
    func decodeMinimal() throws {
        let json = """
        {}
        """.data(using: .utf8)!
        let genre = try JSONDecoder().decode(Genre.self, from: json)

        #expect(genre.value == "")
        #expect(genre.songCount == 0)
        #expect(genre.albumCount == 0)
    }
}

// MARK: - Subsonic Error Envelope

@Suite("Subsonic Error Handling")
struct SubsonicErrorTests {

    @Test("Error response has status=failed and error details")
    func errorEnvelope() throws {
        let data = try loadFixture("subsonic_error_response")
        let wrapper = try JSONDecoder().decode(SubsonicWrapper.self, from: data)

        #expect(wrapper.subsonicResponse.status == "failed")
        let error = try #require(wrapper.subsonicResponse.error)
        #expect(error.code == 40)
        #expect(error.message == "Wrong username or password")
    }

    @Test("Error response has nil albumList2 — should not decode as valid album list")
    func errorResponseHasNoAlbums() throws {
        let data = try loadFixture("subsonic_error_response")
        let wrapper = try JSONDecoder().decode(SubsonicWrapper.self, from: data)

        #expect(wrapper.subsonicResponse.albumList2 == nil)
        #expect(wrapper.subsonicResponse.album == nil)
        #expect(wrapper.subsonicResponse.searchResult3 == nil)
        #expect(wrapper.subsonicResponse.playlists == nil)
    }
}
