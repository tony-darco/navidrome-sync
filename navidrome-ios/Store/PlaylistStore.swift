import Combine
import Foundation

@MainActor
final class PlaylistStore: ObservableObject {
    @Published var playlists: [Playlist] = []
    @Published var isLoading = false
    @Published var error: String?

    private weak var syncStore: SyncStore?
    private var cancellable: AnyCancellable?

    func bind(to syncStore: SyncStore) {
        self.syncStore = syncStore
        cancellable = syncStore.$lastPlaylistInvalidation
            .compactMap { $0 }
            .sink { [weak self] _ in
                Task { await self?.fetchPlaylists() }
            }
    }

    func fetchPlaylists() async {
        isLoading = true
        error = nil
        do {
            playlists = try await NavidromeClient.shared.getPlaylists()
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    func createPlaylist(name: String) async {
        do {
            let id = try await NavidromeClient.shared.createPlaylist(name: name)
            notifyChanged(playlistId: id, action: "created")
        } catch {
            self.error = error.localizedDescription
        }
    }

    func deletePlaylist(id: String) async {
        do {
            try await NavidromeClient.shared.deletePlaylist(id: id)
            notifyChanged(playlistId: id, action: "deleted")
        } catch {
            self.error = error.localizedDescription
        }
    }

    func notifyChanged(playlistId: String, action: String) {
        syncStore?.notifyPlaylistChanged(playlistId: playlistId, action: action)
        // Also trigger a local refetch
        Task { await fetchPlaylists() }
    }
}
