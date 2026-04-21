import Testing
import Foundation
@testable import navidrome_ios

@Suite("NowPlayingSong")
struct NowPlayingSongTests {

    @Test("Codable round-trip with all fields")
    func fullRoundTrip() throws {
        let song = NowPlayingSong(
            songId: "s-1",
            title: "Test Song",
            artist: "Artist",
            album: "Album",
            albumId: "al-1",
            artistId: "ar-1",
            coverArtId: "ca-1",
            durationSecs: 240,
            positionSecs: 55.3,
            isPlaying: true,
            starred: true
        )
        let data = try JSONEncoder().encode(song)
        let decoded = try JSONDecoder().decode(NowPlayingSong.self, from: data)

        #expect(decoded == song)
    }

    @Test("Codable round-trip with nil optional fields")
    func roundTripNilOptionals() throws {
        let song = NowPlayingSong(
            songId: "s-2",
            title: "Minimal",
            artist: "Art",
            album: "Alb",
            albumId: nil,
            artistId: nil,
            coverArtId: "ca-2",
            durationSecs: 100,
            positionSecs: 0
        )
        let data = try JSONEncoder().encode(song)
        let decoded = try JSONDecoder().decode(NowPlayingSong.self, from: data)

        #expect(decoded.songId == "s-2")
        #expect(decoded.albumId == nil)
        #expect(decoded.artistId == nil)
        #expect(decoded.isPlaying == nil)
        #expect(decoded.starred == nil)
    }

    @Test("Decode from server JSON (missing albumId/artistId)")
    func decodeFromServerJSON() throws {
        let json = """
        {
            "songId": "s-3",
            "title": "Server Song",
            "artist": "Remote Artist",
            "album": "Remote Album",
            "coverArtId": "ca-3",
            "durationSecs": 180,
            "positionSecs": 42.0,
            "isPlaying": false
        }
        """.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(NowPlayingSong.self, from: json)

        #expect(decoded.songId == "s-3")
        #expect(decoded.albumId == nil)
        #expect(decoded.artistId == nil)
        #expect(decoded.isPlaying == false)
    }

    @Test("Equatable: identical songs are equal")
    func equalSongs() {
        let a = NowPlayingSong(
            songId: "s-1", title: "T", artist: "A", album: "Al",
            coverArtId: "c", durationSecs: 100, positionSecs: 50
        )
        let b = NowPlayingSong(
            songId: "s-1", title: "T", artist: "A", album: "Al",
            coverArtId: "c", durationSecs: 100, positionSecs: 50
        )
        #expect(a == b)
    }

    @Test("Equatable: different position makes songs unequal")
    func unequalPosition() {
        let a = NowPlayingSong(
            songId: "s-1", title: "T", artist: "A", album: "Al",
            coverArtId: "c", durationSecs: 100, positionSecs: 50
        )
        var b = a
        b.positionSecs = 99
        #expect(a != b)
    }
}

@Suite("ConnectedClient")
struct ConnectedClientTests {

    @Test("Codable round-trip")
    func roundTrip() throws {
        let client = ConnectedClient(clientId: "c-1", clientType: "web", role: "active")
        let data = try JSONEncoder().encode(client)
        let decoded = try JSONDecoder().decode(ConnectedClient.self, from: data)

        #expect(decoded.clientId == "c-1")
        #expect(decoded.clientType == "web")
        #expect(decoded.role == "active")
        #expect(decoded.id == "c-1")
    }

    @Test("Identifiable id is clientId")
    func identifiable() {
        let client = ConnectedClient(clientId: "abc-123", clientType: "ios", role: "observer")
        #expect(client.id == "abc-123")
    }

    @Test("Decode from server JSON")
    func decodeJSON() throws {
        let json = """
        {"clientId": "x", "clientType": "ios", "role": "observer"}
        """.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(ConnectedClient.self, from: json)

        #expect(decoded.clientId == "x")
        #expect(decoded.role == "observer")
    }
}
