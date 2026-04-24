import SwiftUI

struct SearchView: View {
    @EnvironmentObject private var store: SyncStore
    @State private var query = ""
    @State private var artists: [ArtistID3] = []
    @State private var albums: [Album] = []
    @State private var songs: [Song] = []
    @State private var isSearching = false
    @State private var hasSearched = false
    @State private var searchTask: Task<Void, Never>?

    private var hasResults: Bool { !artists.isEmpty || !albums.isEmpty || !songs.isEmpty }

    var body: some View {
        ZStack(alignment: .bottom) {
        NavigationStack {
            List {
                if !artists.isEmpty {
                    Section("Artists") {
                        ForEach(artists) { artist in
                            NavigationLink(value: artist) {
                                ArtistRowView(artist: artist)
                            }
                            .listRowBackground(Color.clear)
                            .listRowInsets(EdgeInsets())
                            .listRowSeparator(.hidden)
                        }
                    }
                }

                if !albums.isEmpty {
                    Section("Albums") {
                        ForEach(albums) { album in
                            NavigationLink(value: album) {
                                albumRow(album)
                            }
                            .listRowBackground(Color.clear)
                        }
                    }
                }

                if !songs.isEmpty {
                    Section("Songs") {
                        ForEach(songs) { song in
                            Button { store.playSong(song.toNowPlayingSong()) } label: {
                                songRow(song)
                            }
                            .buttonStyle(.plain)
                            .listRowBackground(Color.clear)
                        }
                    }
                }

                if hasSearched && !hasResults && !isSearching {
                    HStack {
                        Spacer()
                        VStack(spacing: 8) {
                            Image(systemName: "magnifyingglass")
                                .font(.largeTitle)
                                .foregroundStyle(.secondary)
                            Text("No results found")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.top, 40)
                        Spacer()
                    }
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .miniPlayerScrollObserver()
            .overlay {
                if !hasSearched && !hasResults {
                    GeometryReader { geo in
                        VStack {
                            Spacer()
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 48))
                                .foregroundStyle(.secondary)
                            Text("Search for artists, albums, and songs")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .padding(.top, 8)
                            Spacer()
                        }
                        .frame(width: geo.size.width, height: geo.size.height)
                    }
                }
            }
            .background { store.dominantBackgroundColor.ignoresSafeArea() }
            .navigationTitle("Search")
            .searchable(text: $query, prompt: "Artists, albums, songs...")
            .onSubmit(of: .search) {
                scheduleSearch(immediate: true)
            }
            .onChange(of: query) { _, newValue in
                if newValue.isEmpty {
                    searchTask?.cancel()
                    artists = []
                    albums = []
                    songs = []
                    hasSearched = false
                } else {
                    scheduleSearch(immediate: false)
                }
            }
            .navigationDestination(for: ArtistID3.self) { artist in
                ArtistDetailView(artistId: artist.id, artistName: artist.name)
            }
            .navigationDestination(for: Album.self) { album in
                AlbumDetailView(albumId: album.id)
            }
        }
        } // ZStack
    }

    private func scheduleSearch(immediate: Bool) {
        searchTask?.cancel()
        searchTask = Task {
            if !immediate {
                try? await Task.sleep(for: .milliseconds(350))
            }
            guard !Task.isCancelled else { return }
            await performSearch()
        }
    }

    private func performSearch() async {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        isSearching = true
        hasSearched = true
        defer { isSearching = false }
        do {
            let result = try await NavidromeClient.shared.search(query: trimmed)
            artists = result.artists
            albums = result.albums
            songs = result.songs
        } catch {
            print("[search] error: \(error)")
        }
    }

    private func albumRow(_ album: Album) -> some View {
        HStack(spacing: 12) {
            CoverArtImage(id: album.coverArt, size: 80)
                .frame(width: 48, height: 48)
                .clipShape(RoundedRectangle(cornerRadius: 6))
            VStack(alignment: .leading, spacing: 2) {
                Text(album.name)
                    .font(.body)
                    .lineLimit(1)
                Text(album.artist)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }

    private func songRow(_ song: Song) -> some View {
        let isNowPlaying = song.id == store.nowPlaying?.songId
        return HStack(spacing: 12) {
            CoverArtImage(id: song.coverArt, size: 80, isNowPlaying: isNowPlaying, isPlaying: store.isPlaying)
                .frame(width: 40, height: 40)
                .clipShape(RoundedRectangle(cornerRadius: 4))
            VStack(alignment: .leading, spacing: 2) {
                Text(song.title)
                    .font(.body)
                    .lineLimit(1)
                Text(song.artist)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            Text(formatDuration(song.duration))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func formatDuration(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%d:%02d", m, s)
    }
}
