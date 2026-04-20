import SwiftUI

struct SearchView: View {
    @EnvironmentObject private var store: SyncStore
    @State private var query = ""
    @State private var albums: [Album] = []
    @State private var songs: [Song] = []
    @State private var isSearching = false
    @State private var hasSearched = false

    var body: some View {
        NavigationStack {
            List {
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

                if hasSearched && albums.isEmpty && songs.isEmpty && !isSearching {
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
            .overlay {
                if !hasSearched && albums.isEmpty && songs.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 48))
                            .foregroundStyle(.secondary)
                        Text("Search for albums and songs")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .background { store.dominantBackgroundColor.ignoresSafeArea() }
            .navigationTitle("Search")
            .searchable(text: $query, prompt: "Albums, songs...")
            .onSubmit(of: .search) {
                Task { await performSearch() }
            }
            .onChange(of: query) { _, newValue in
                if newValue.isEmpty {
                    albums = []
                    songs = []
                    hasSearched = false
                }
            }
            .navigationDestination(for: Album.self) { album in
                AlbumDetailView(albumId: album.id)
            }
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
        HStack(spacing: 12) {
            CoverArtImage(id: song.coverArt, size: 80)
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
