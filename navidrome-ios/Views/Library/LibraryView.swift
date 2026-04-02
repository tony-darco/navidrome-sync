import SwiftUI

struct LibraryView: View {
    @EnvironmentObject private var store: SyncStore
    @State private var albums: [Album] = []
    @State private var searchText = ""
    @State private var searchAlbums: [Album] = []
    @State private var searchSongs: [Song] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var searchTask: Task<Void, Never>?

    var body: some View {
        NavigationStack {
            Group {
                if searchText.isEmpty {
                    albumGrid
                } else {
                    searchResults
                }
            }
            .navigationTitle("Library")
            .searchable(text: $searchText, prompt: "Search albums and songs")
            .onChange(of: searchText) { _, newValue in
                debounceSearch(newValue)
            }
            .task {
                await loadAlbums(force: false)
            }
        }
    }

    // MARK: - Album grid (default view)

    private var albumGrid: some View {
        ScrollView {
            if isLoading && albums.isEmpty {
                ProgressView()
                    .padding(.top, 60)
            } else if let errorMessage, albums.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    Text(errorMessage)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    Button("Retry") {
                        Task { await loadAlbums(force: true) }
                    }
                    .buttonStyle(.bordered)
                }
                .padding(.top, 60)
            } else {
                AlbumGridView(albums: albums)
            }
        }
    }

    // MARK: - Search results

    private var searchResults: some View {
        List {
            if !searchAlbums.isEmpty {
                Section("Albums") {
                    ForEach(searchAlbums) { album in
                        NavigationLink(value: album) {
                            albumRow(album)
                        }
                    }
                }
            }
            if !searchSongs.isEmpty {
                Section("Songs") {
                    ForEach(searchSongs) { song in
                        Button { playSingleSong(song) } label: {
                            songRow(song)
                        }
                    }
                }
            }
        }
        .navigationDestination(for: Album.self) { album in
            AlbumDetailView(albumId: album.id)
        }
    }

    // MARK: - Row views

    private func albumRow(_ album: Album) -> some View {
        HStack(spacing: 12) {
            CoverArtImage(id: album.coverArt, size: 80)
                .frame(width: 50, height: 50)
                .clipShape(RoundedRectangle(cornerRadius: 6))
            VStack(alignment: .leading) {
                Text(album.name).lineLimit(1)
                Text(album.artist).font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
        }
    }

    private func songRow(_ song: Song) -> some View {
        HStack(spacing: 12) {
            CoverArtImage(id: song.coverArt, size: 80)
                .frame(width: 40, height: 40)
                .clipShape(RoundedRectangle(cornerRadius: 4))
            VStack(alignment: .leading) {
                Text(song.title).lineLimit(1)
                Text(song.artist).font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer()
            Text(formatDuration(song.duration))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Data loading

    private func loadAlbums(force: Bool = false) async {
        guard force || albums.isEmpty else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            albums = try await NavidromeClient.shared.getAlbums()
            if albums.isEmpty {
                errorMessage = "No albums found in your library."
            }
        } catch {
            print("[library] failed to load albums: \(error)")
            errorMessage = "Could not load albums.\n\(error.localizedDescription)"
        }
    }

    private func debounceSearch(_ query: String) {
        searchTask?.cancel()
        guard !query.isEmpty else {
            searchAlbums = []
            searchSongs = []
            return
        }
        searchTask = Task {
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            do {
                let results = try await NavidromeClient.shared.search(query: query)
                guard !Task.isCancelled else { return }
                searchAlbums = results.albums
                searchSongs = results.songs
            } catch {
                print("[library] search error: \(error)")
            }
        }
    }

    private func playSingleSong(_ song: Song) {
        store.playSong(song.toNowPlayingSong())
    }

    private func formatDuration(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%d:%02d", m, s)
    }
}

// Make Album Hashable for NavigationLink value
extension Album: Hashable {
    static func == (lhs: Album, rhs: Album) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}
