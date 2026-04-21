import Combine
import Foundation

/// Centralized in-memory cache for album lists and per-album song details.
/// Owned at the app root and injected as an environment object so data
/// survives navigation, eliminating navigation-stack pop/flash artifacts.
@MainActor
final class MusicLibraryStore: ObservableObject {

    // MARK: - Nested types

    struct AlbumListState {
        var albums: [Album] = []
        var seenIDs: Set<String> = []
        var currentOffset: Int = 0
        var hasMore: Bool = true
        var isLoading: Bool = false
        var errorMessage: String?
    }

    nonisolated struct AlbumDetail: Sendable {
        let album: Album
        let songs: [Song]
    }

    // MARK: - Constants

    static let pageSize = 30

    // MARK: - Published state

    @Published private(set) var albumListStates: [AlbumSortOrder: AlbumListState] = [:]
    @Published private(set) var albumDetails: [String: AlbumDetail] = [:]

    // MARK: - Private

    /// Tracks in-flight detail fetches to prevent duplicate network calls.
    private var loadingDetailIDs: Set<String> = []

    /// Stores cancelable background-refresh tasks keyed by sort order.
    private var silentRefreshTasks: [AlbumSortOrder: Task<Void, Never>] = [:]

    // MARK: - Init

    init() {
        Task { await seedInitialAlbums() }
    }

    // MARK: - Seeding

    /// Fetches the first page of alphabetical albums on launch so navigating to
    /// AlbumsView for the first time is instant.
    private func seedInitialAlbums() async {
        guard albumListStates[.alphabeticalByName] == nil else { return }
        await loadAlbums(sortOrder: .alphabeticalByName)
    }

    // MARK: - Album list management

    /// Load albums for the given sort order.
    /// - If data is already cached: return immediately and kick off a silent background refresh.
    /// - If no cache (or force == true): show a loading state, fetch page 1.
    func loadAlbums(sortOrder: AlbumSortOrder, force: Bool = false) async {
        let hasCachedData = albumListStates[sortOrder].map { !$0.albums.isEmpty } ?? false

        if hasCachedData && !force {
            startSilentRefresh(sortOrder: sortOrder)
            return
        }

        // Show loading indicator synchronously before any await.
        var loadingState = AlbumListState()
        loadingState.isLoading = true
        albumListStates[sortOrder] = loadingState

        do {
            let batch = try await NavidromeClient.shared.getAlbums(
                type: sortOrder.rawValue, size: Self.pageSize, offset: 0
            )
            var newState = AlbumListState()
            newState.albums = batch.filter { newState.seenIDs.insert($0.id).inserted }
            newState.currentOffset = batch.count
            newState.hasMore = batch.count >= Self.pageSize
            if newState.albums.isEmpty {
                newState.errorMessage = "No albums found."
            }
            albumListStates[sortOrder] = newState
        } catch {
            var errState = AlbumListState()
            errState.errorMessage = "Could not load albums.\n\(error.localizedDescription)"
            albumListStates[sortOrder] = errState
        }
    }

    private func startSilentRefresh(sortOrder: AlbumSortOrder) {
        silentRefreshTasks[sortOrder]?.cancel()
        silentRefreshTasks[sortOrder] = Task { [weak self] in
            await self?.silentRefreshAlbums(sortOrder: sortOrder)
        }
    }

    private func silentRefreshAlbums(sortOrder: AlbumSortOrder) async {
        // Don't clobber an active load or pagination request.
        guard albumListStates[sortOrder]?.isLoading != true, !Task.isCancelled else { return }

        do {
            let batch = try await NavidromeClient.shared.getAlbums(
                type: sortOrder.rawValue, size: Self.pageSize, offset: 0
            )
            // Re-check after the await: abort if a pagination or force-load is now in flight.
            guard albumListStates[sortOrder]?.isLoading != true, !Task.isCancelled else { return }
            var newState = AlbumListState()
            newState.albums = batch.filter { newState.seenIDs.insert($0.id).inserted }
            newState.currentOffset = batch.count
            newState.hasMore = batch.count >= Self.pageSize
            if newState.albums.isEmpty {
                newState.errorMessage = "No albums found."
            }
            albumListStates[sortOrder] = newState
        } catch {
            // Silent refresh failure is non-fatal; keep existing cached data.
        }
    }

    /// Appends the next page for the given sort order.
    func loadNextPage(sortOrder: AlbumSortOrder) async {
        guard var state = albumListStates[sortOrder],
              state.hasMore, !state.isLoading else { return }

        // Mark loading synchronously before the first await.
        state.isLoading = true
        albumListStates[sortOrder] = state
        let offset = state.currentOffset

        do {
            let batch = try await NavidromeClient.shared.getAlbums(
                type: sortOrder.rawValue, size: Self.pageSize, offset: offset
            )
            // Re-read state after the await to pick up any concurrent seenIDs changes.
            guard var current = albumListStates[sortOrder] else { return }
            current.isLoading = false
            let unique = batch.filter { current.seenIDs.insert($0.id).inserted }
            current.albums.append(contentsOf: unique)
            current.currentOffset += batch.count
            current.hasMore = batch.count >= Self.pageSize
            albumListStates[sortOrder] = current
        } catch {
            if var current = albumListStates[sortOrder] {
                current.isLoading = false
                albumListStates[sortOrder] = current
            }
        }
    }

    // MARK: - Album detail management

    /// Load songs for a specific album.
    /// - If already cached: return immediately and refresh in the background.
    /// - Otherwise: fetch and populate the cache.
    func loadAlbumDetail(id: String) async {
        if albumDetails[id] != nil {
            Task { [weak self] in await self?.silentRefreshAlbumDetail(id: id) }
            return
        }
        guard !loadingDetailIDs.contains(id) else { return }
        loadingDetailIDs.insert(id)
        do {
            let result = try await NavidromeClient.shared.getAlbum(id: id)
            albumDetails[id] = AlbumDetail(album: result.album, songs: result.songs)
        } catch {
            print("[MusicLibraryStore] failed to load album \(id): \(error)")
        }
        loadingDetailIDs.remove(id)
    }

    private func silentRefreshAlbumDetail(id: String) async {
        guard !loadingDetailIDs.contains(id) else { return }
        loadingDetailIDs.insert(id)
        do {
            let result = try await NavidromeClient.shared.getAlbum(id: id)
            albumDetails[id] = AlbumDetail(album: result.album, songs: result.songs)
        } catch {
            // Silent refresh failure is non-fatal.
        }
        loadingDetailIDs.remove(id)
    }

    // MARK: - Star sync

    /// Called when a song's starred state changes (from NowPlayingView or a remote starNotify
    /// message) so that AlbumDetailView stays in sync without a re-fetch.
    func updateSongStar(songId: String, starred: Bool) {
        for (albumId, detail) in albumDetails {
            guard let index = detail.songs.firstIndex(where: { $0.id == songId }) else { continue }
            let old = detail.songs[index]
            let updated = Song(
                id: old.id,
                title: old.title,
                artist: old.artist,
                album: old.album,
                albumId: old.albumId,
                artistId: old.artistId,
                coverArt: old.coverArt,
                duration: old.duration,
                track: old.track,
                starred: starred ? "1" : nil
            )
            var songs = detail.songs
            songs[index] = updated
            albumDetails[albumId] = AlbumDetail(album: detail.album, songs: songs)
            return // song IDs are globally unique
        }
    }
}
