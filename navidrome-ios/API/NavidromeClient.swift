import Foundation
import UIKit

/// Handles all Subsonic API calls directly against the Navidrome server.
actor NavidromeClient {
    static let shared = NavidromeClient()

    private let session = URLSession.shared

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
        guard let auth = AppConfig.authParams else { throw NavidromeError.notLoggedIn }
        let base = try baseURL()
        let sep = path.contains("?") ? "&" : "?"
        var urlString = "\(base)\(path)\(sep)\(auth)"
        if !params.isEmpty {
            let extra = params.map { "\($0.key)=\($0.value)" }.joined(separator: "&")
            urlString += "&\(extra)"
        }
        guard let url = URL(string: urlString) else { throw NavidromeError.invalidURL }
        return url
    }

    // MARK: - Album APIs

    func getAlbums(type: String = "newest", size: Int = 50, offset: Int = 0) async throws -> [Album] {
        let url = try buildURL(path: "/rest/getAlbumList2.view", params: [
            "type": type,
            "size": String(size),
            "offset": String(offset),
        ])
        let (data, _) = try await session.data(from: url)
        let wrapper = try JSONDecoder().decode(SubsonicWrapper.self, from: data)
        return wrapper.subsonicResponse.albumList2?.album ?? []
    }

    func getAlbum(id: String) async throws -> (album: Album, songs: [Song]) {
        let url = try buildURL(path: "/rest/getAlbum.view", params: ["id": id])
        let (data, _) = try await session.data(from: url)
        let wrapper = try JSONDecoder().decode(SubsonicWrapper.self, from: data)
        guard let raw = wrapper.subsonicResponse.album else {
            throw NavidromeError.badResponse
        }
        return (album: raw.toAlbum(), songs: raw.song ?? [])
    }

    func search(query: String) async throws -> (albums: [Album], songs: [Song]) {
        let url = try buildURL(path: "/rest/search3.view", params: [
            "query": query,
            "albumCount": "20",
            "songCount": "20",
        ])
        let (data, _) = try await session.data(from: url)
        let wrapper = try JSONDecoder().decode(SubsonicWrapper.self, from: data)
        let result = wrapper.subsonicResponse.searchResult3
        return (albums: result?.album ?? [], songs: result?.song ?? [])
    }

    // MARK: - Artist APIs

    func getArtists() async throws -> [ArtistIndex] {
        let url = try buildURL(path: "/rest/getArtists.view")
        let (data, _) = try await session.data(from: url)
        let wrapper = try JSONDecoder().decode(SubsonicWrapper.self, from: data)
        return wrapper.subsonicResponse.artists?.index ?? []
    }

    func getArtist(id: String) async throws -> ArtistDetail {
        let url = try buildURL(path: "/rest/getArtist.view", params: ["id": id])
        let (data, _) = try await session.data(from: url)
        let wrapper = try JSONDecoder().decode(SubsonicWrapper.self, from: data)
        guard let artist = wrapper.subsonicResponse.artist else {
            throw NavidromeError.badResponse
        }
        return artist
    }

    // MARK: - Song APIs

    func getSongs(offset: Int = 0, count: Int = 50) async throws -> [Song] {
        let url = try buildURL(path: "/rest/search3.view", params: [
            "query": "",
            "songCount": String(count),
            "songOffset": String(offset),
            "artistCount": "0",
            "albumCount": "0",
        ])
        let (data, _) = try await session.data(from: url)
        let wrapper = try JSONDecoder().decode(SubsonicWrapper.self, from: data)
        return wrapper.subsonicResponse.searchResult3?.song ?? []
    }

    // MARK: - Playlist APIs

    func getPlaylists() async throws -> [Playlist] {
        let url = try buildURL(path: "/rest/getPlaylists.view")
        let (data, _) = try await session.data(from: url)
        let wrapper = try JSONDecoder().decode(SubsonicWrapper.self, from: data)
        return wrapper.subsonicResponse.playlists?.playlist ?? []
    }

    func getPlaylist(id: String) async throws -> PlaylistWithSongs {
        let url = try buildURL(path: "/rest/getPlaylist.view", params: ["id": id])
        let (data, _) = try await session.data(from: url)
        let wrapper = try JSONDecoder().decode(SubsonicWrapper.self, from: data)
        guard let playlist = wrapper.subsonicResponse.playlist else {
            throw NavidromeError.badResponse
        }
        return playlist
    }

    func createPlaylist(name: String, songIds: [String] = []) async throws -> String {
        var params = ["name": name]
        // songId params need to be repeated in the URL, but for creation with no songs this is fine
        if songIds.isEmpty {
            let url = try buildURL(path: "/rest/createPlaylist.view", params: params)
            let (data, _) = try await session.data(from: url)
            let wrapper = try JSONDecoder().decode(SubsonicWrapper.self, from: data)
            return wrapper.subsonicResponse.playlist?.id ?? ""
        }
        // Build URL with repeated songId params
        let url = try buildURL(path: "/rest/createPlaylist.view", params: params)
        let songParams = songIds.map { "songId=\($0)" }.joined(separator: "&")
        guard let fullURL = URL(string: url.absoluteString + "&" + songParams) else {
            throw NavidromeError.invalidURL
        }
        let (data, _) = try await session.data(from: fullURL)
        let wrapper = try JSONDecoder().decode(SubsonicWrapper.self, from: data)
        return wrapper.subsonicResponse.playlist?.id ?? ""
    }

    func updatePlaylist(playlistId: String, songIdsToAdd: [String] = [], songIndexesToRemove: [Int] = []) async throws {
        var url = try buildURL(path: "/rest/updatePlaylist.view", params: ["playlistId": playlistId])
        var extra = ""
        for songId in songIdsToAdd {
            extra += "&songIdToAdd=\(songId)"
        }
        for index in songIndexesToRemove {
            extra += "&songIndexToRemove=\(index)"
        }
        if !extra.isEmpty {
            guard let fullURL = URL(string: url.absoluteString + extra) else {
                throw NavidromeError.invalidURL
            }
            url = fullURL
        }
        let (_, _) = try await session.data(from: url)
    }

    func deletePlaylist(id: String) async throws {
        let url = try buildURL(path: "/rest/deletePlaylist.view", params: ["id": id])
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
        guard let base = AppConfig.serverURL, let auth = AppConfig.authParams else {
            throw NavidromeError.notLoggedIn
        }
        let sep = path.contains("?") ? "&" : "?"
        var urlString = "\(base)\(path)\(sep)\(auth)"
        if !params.isEmpty {
            let extra = params.map { "\($0.key)=\($0.value)" }.joined(separator: "&")
            urlString += "&\(extra)"
        }
        guard let url = URL(string: urlString) else { throw NavidromeError.invalidURL }
        return url
    }
}

nonisolated enum NavidromeError: Error {
    case invalidURL
    case badResponse
    case authFailed
    case notLoggedIn
}
