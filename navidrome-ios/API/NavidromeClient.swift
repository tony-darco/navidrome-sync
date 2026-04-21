import Foundation
import UIKit

/// Handles all Subsonic API calls directly against the Navidrome server.
actor NavidromeClient: NavidromeClientProtocol {
    static let shared = NavidromeClient()

    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    // MARK: - Validation (used by LoginView)

    /// Test credentials against the Navidrome server's ping endpoint.
    func validateCredentials(serverURL: String, username: String, password: String) async throws {
        let auth = "u=\(username)&p=\(password)&v=1.16.1&c=navidrome-ios&f=json"
        guard let url = URL(string: "\(serverURL)/rest/ping.view?\(auth)") else {
            throw NavidromeError.invalidURL
        }
        let (data, response) = try await session.data(from: url)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw NavidromeError.badResponse
        }
        // Check Subsonic response for auth failure
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let sub = json["subsonic-response"] as? [String: Any],
           let status = sub["status"] as? String, status == "failed" {
            throw NavidromeError.authFailed
        }
    }

    // MARK: - URL building

    private func baseURL() throws -> String {
        guard let url = AppConfig.serverURL else { throw NavidromeError.notLoggedIn }
        return url
    }

    private func buildURL(path: String, params: [String: String] = [:]) throws -> URL {
        let base = try baseURL()
        guard let u = AppConfig.username, let p = AppConfig.password else {
            throw NavidromeError.notLoggedIn
        }
        guard var components = URLComponents(string: "\(base)\(path)") else {
            throw NavidromeError.invalidURL
        }
        var items: [URLQueryItem] = [
            URLQueryItem(name: "u", value: u),
            URLQueryItem(name: "p", value: p),
            URLQueryItem(name: "v", value: "1.16.1"),
            URLQueryItem(name: "c", value: "navidrome-ios"),
            URLQueryItem(name: "f", value: "json"),
        ]
        for (key, value) in params {
            items.append(URLQueryItem(name: key, value: value))
        }
        components.queryItems = items
        guard let url = components.url else { throw NavidromeError.invalidURL }
        return url
    }

    // MARK: - Shared request + validation

    /// Perform a GET request, validate the HTTP status, decode the Subsonic wrapper,
    /// and check the Subsonic-level status. Throws on any failure.
    private func request(path: String, params: [String: String] = [:]) async throws -> SubsonicResponse {
        let url = try buildURL(path: path, params: params)
        let (data, response) = try await session.data(from: url)
        if let http = response as? HTTPURLResponse, http.statusCode != 200 {
            throw NavidromeError.badResponse
        }
        let wrapper = try JSONDecoder().decode(SubsonicWrapper.self, from: data)
        if wrapper.subsonicResponse.status != "ok" {
            if let err = wrapper.subsonicResponse.error {
                throw NavidromeError.serverError(code: err.code, message: err.message)
            }
            throw NavidromeError.badResponse
        }
        return wrapper.subsonicResponse
    }

    // MARK: - Album APIs

    func getAlbums(type: String = "newest", size: Int = 50, offset: Int = 0, genre: String? = nil) async throws -> [Album] {
        var params = [
            "type": type,
            "size": String(size),
            "offset": String(offset),
        ]
        if let genre { params["genre"] = genre }
        let resp = try await request(path: "/rest/getAlbumList2.view", params: params)
        return resp.albumList2?.album ?? []
    }

    func getAlbum(id: String) async throws -> (album: Album, songs: [Song]) {
        let resp = try await request(path: "/rest/getAlbum.view", params: ["id": id])
        guard let raw = resp.album else {
            throw NavidromeError.badResponse
        }
        return (album: raw.toAlbum(), songs: raw.song ?? [])
    }

    func search(query: String) async throws -> (albums: [Album], songs: [Song]) {
        let resp = try await request(path: "/rest/search3.view", params: [
            "query": query,
            "albumCount": "20",
            "songCount": "20",
        ])
        let result = resp.searchResult3
        return (albums: result?.album ?? [], songs: result?.song ?? [])
    }

    // MARK: - Artist APIs

    func getArtists() async throws -> [ArtistIndex] {
        let resp = try await request(path: "/rest/getArtists.view")
        return resp.artists?.index ?? []
    }

    // MARK: - Genre APIs

    func getGenres() async throws -> [Genre] {
        let resp = try await request(path: "/rest/getGenres.view")
        return resp.genres?.genre ?? []
    }

    func getSongsByGenre(genre: String, count: Int = 50, offset: Int = 0) async throws -> [Song] {
        let resp = try await request(path: "/rest/getSongsByGenre.view", params: [
            "genre": genre,
            "count": String(count),
            "offset": String(offset),
        ])
        return resp.songsByGenre?.song ?? []
    }

    func getArtist(id: String) async throws -> ArtistDetail {
        let resp = try await request(path: "/rest/getArtist.view", params: ["id": id])
        guard let artist = resp.artist else {
            throw NavidromeError.badResponse
        }
        return artist
    }

    func getArtistInfo2(id: String) async throws -> ArtistInfo2 {
        let resp = try await request(path: "/rest/getArtistInfo2.view", params: ["id": id])
        return resp.artistInfo2 ?? ArtistInfo2(biography: nil, largeImageUrl: nil, mediumImageUrl: nil, smallImageUrl: nil)
    }

    func getTopSongs(artistName: String, count: Int = 50) async throws -> [Song] {
        let resp = try await request(path: "/rest/getTopSongs.view", params: [
            "artist": artistName,
            "count": String(count),
        ])
        return resp.topSongs?.song ?? []
    }

    // MARK: - Song APIs

    func getSongs(offset: Int = 0, count: Int = 50) async throws -> [Song] {
        let resp = try await request(path: "/rest/search3.view", params: [
            "query": "",
            "songCount": String(count),
            "songOffset": String(offset),
            "artistCount": "0",
            "albumCount": "0",
        ])
        return resp.searchResult3?.song ?? []
    }

    // MARK: - Playlist APIs

    func getPlaylists() async throws -> [Playlist] {
        let resp = try await request(path: "/rest/getPlaylists.view")
        return resp.playlists?.playlist ?? []
    }

    func getPlaylist(id: String) async throws -> PlaylistWithSongs {
        let resp = try await request(path: "/rest/getPlaylist.view", params: ["id": id])
        guard let playlist = resp.playlist else {
            throw NavidromeError.badResponse
        }
        return playlist
    }

    func createPlaylist(name: String, songIds: [String] = []) async throws -> String {
        var params = ["name": name]
        // For URLComponents, we handle repeated songId params by building the URL
        // then appending them, since URLComponents doesn't natively support repeated keys
        if songIds.isEmpty {
            let resp = try await request(path: "/rest/createPlaylist.view", params: params)
            return resp.playlist?.id ?? ""
        }
        let url = try buildURL(path: "/rest/createPlaylist.view", params: params)
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        let existing = components.queryItems ?? []
        components.queryItems = existing + songIds.map { URLQueryItem(name: "songId", value: $0) }
        guard let fullURL = components.url else {
            throw NavidromeError.invalidURL
        }
        let (data, response) = try await session.data(from: fullURL)
        if let http = response as? HTTPURLResponse, http.statusCode != 200 {
            throw NavidromeError.badResponse
        }
        let wrapper = try JSONDecoder().decode(SubsonicWrapper.self, from: data)
        if wrapper.subsonicResponse.status != "ok" {
            if let err = wrapper.subsonicResponse.error {
                throw NavidromeError.serverError(code: err.code, message: err.message)
            }
            throw NavidromeError.badResponse
        }
        return wrapper.subsonicResponse.playlist?.id ?? ""
    }

    func updatePlaylist(playlistId: String, songIdsToAdd: [String] = [], songIndexesToRemove: [Int] = []) async throws {
        let url = try buildURL(path: "/rest/updatePlaylist.view", params: ["playlistId": playlistId])
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        var items = components.queryItems ?? []
        for songId in songIdsToAdd {
            items.append(URLQueryItem(name: "songIdToAdd", value: songId))
        }
        for index in songIndexesToRemove {
            items.append(URLQueryItem(name: "songIndexToRemove", value: String(index)))
        }
        components.queryItems = items
        guard let fullURL = components.url else {
            throw NavidromeError.invalidURL
        }
        let (_, _) = try await session.data(from: fullURL)
    }

    func deletePlaylist(id: String) async throws {
        let url = try buildURL(path: "/rest/deletePlaylist.view", params: ["id": id])
        let (_, _) = try await session.data(from: url)
    }

    // MARK: - Media Annotation APIs

    func star(id: String) async throws {
        let url = try buildURL(path: "/rest/star.view", params: ["id": id])
        let (_, _) = try await session.data(from: url)
    }

    func unstar(id: String) async throws {
        let url = try buildURL(path: "/rest/unstar.view", params: ["id": id])
        let (_, _) = try await session.data(from: url)
    }

    func scrobble(songId: String) async throws {
        let url = try buildURL(path: "/rest/scrobble.view", params: ["id": songId])
        let (_, _) = try await session.data(from: url)
    }

    // MARK: - Media URLs (nonisolated — only reads AppConfig statics)

    nonisolated func streamURL(songId: String) -> URL? {
        try? buildMediaURL(path: "/rest/stream.view", params: ["id": songId])
    }

    nonisolated func coverArtURL(id: String, size: Int = 300) -> URL? {
        guard !id.isEmpty else { return nil }
        return try? buildMediaURL(path: "/rest/getCoverArt.view", params: ["id": id, "size": String(size)])
    }

    func fetchCoverArt(id: String, size: Int = 300) async -> UIImage? {
        guard !id.isEmpty, let url = coverArtURL(id: id, size: size) else { return nil }
        guard let (data, _) = try? await session.data(from: url) else { return nil }
        return UIImage(data: data)
    }

    /// URL builder for media endpoints — nonisolated since it only reads AppConfig.
    private nonisolated func buildMediaURL(path: String, params: [String: String] = [:]) throws -> URL {
        guard let base = AppConfig.serverURL,
              let u = AppConfig.username,
              let p = AppConfig.password else {
            throw NavidromeError.notLoggedIn
        }
        guard var components = URLComponents(string: "\(base)\(path)") else {
            throw NavidromeError.invalidURL
        }
        var items: [URLQueryItem] = [
            URLQueryItem(name: "u", value: u),
            URLQueryItem(name: "p", value: p),
            URLQueryItem(name: "v", value: "1.16.1"),
            URLQueryItem(name: "c", value: "navidrome-ios"),
            URLQueryItem(name: "f", value: "json"),
        ]
        for (key, value) in params {
            items.append(URLQueryItem(name: key, value: value))
        }
        components.queryItems = items
        guard let url = components.url else { throw NavidromeError.invalidURL }
        return url
    }
}

nonisolated enum NavidromeError: LocalizedError {
    case invalidURL
    case badResponse
    case authFailed
    case notLoggedIn
    case serverError(code: Int, message: String)

    var errorDescription: String? {
        switch self {
        case .invalidURL: "Invalid server URL."
        case .badResponse: "Unexpected response from server."
        case .authFailed: "Wrong username or password."
        case .notLoggedIn: "Not logged in."
        case .serverError(_, let message): message
        }
    }
}
