import SwiftUI

struct PlaylistsView: View {
    @EnvironmentObject private var store: SyncStore
    @EnvironmentObject private var playlistStore: PlaylistStore
    @State private var showCreateSheet = false
    @State private var searchText = ""

    private var filteredPlaylists: [Playlist] {
        if searchText.isEmpty { return playlistStore.playlists }
        return playlistStore.playlists.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        List {
            ForEach(filteredPlaylists) { playlist in
                NavigationLink(value: playlist) {
                    PlaylistRowView(playlist: playlist)
                }
                .listRowBackground(Color.clear)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .miniPlayerScrollObserver()
        .background { store.dominantBackgroundColor.ignoresSafeArea() }
        .searchable(text: $searchText, prompt: "Search playlists")
        .navigationTitle("Playlists")
        .navigationDestination(for: Playlist.self) { playlist in
            PlaylistDetailView(playlistId: playlist.id, playlistName: playlist.name)
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showCreateSheet = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showCreateSheet) {
            PlaylistCreateSheet()
        }
        .overlay {
            if playlistStore.isLoading && playlistStore.playlists.isEmpty {
                ProgressView()
            } else if !playlistStore.isLoading && playlistStore.playlists.isEmpty {
                ContentUnavailableView(
                    "No Playlists",
                    systemImage: "music.note.list",
                    description: Text("Tap + to create one.")
                )
            }
        }
        .task {
            await playlistStore.fetchPlaylists()
        }
    }
}
