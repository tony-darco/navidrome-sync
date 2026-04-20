import SwiftUI

struct GenreDetailView: View {
    @EnvironmentObject private var store: SyncStore
    let genre: Genre

    @State private var albums: [Album] = []
    @State private var songs: [Song] = []
    @State private var isLoadingAlbums = false
    @State private var isLoadingSongs = false
    @State private var selectedTab = 0

    private let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16),
    ]

    var body: some View {
        VStack(spacing: 0) {
            Picker("View", selection: $selectedTab) {
                Text("Albums").tag(0)
                Text("Songs").tag(1)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.vertical, 8)

            ScrollView {
                if selectedTab == 0 {
                    albumsContent
                } else {
                    songsContent
                }
            }
        }
        .background { store.dominantBackgroundColor.ignoresSafeArea() }
        .navigationTitle(genre.name)
        .task {
            await loadAlbums()
            await loadSongs()
        }
    }

    @ViewBuilder
    private var albumsContent: some View {
        if isLoadingAlbums && albums.isEmpty {
            ProgressView()
                .padding(.top, 40)
        } else if albums.isEmpty {
            Text("No albums in this genre.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.top, 40)
        } else {
            AlbumGridView(albums: albums)
        }
    }

    @ViewBuilder
    private var songsContent: some View {
        if isLoadingSongs && songs.isEmpty {
            ProgressView()
                .padding(.top, 40)
        } else if songs.isEmpty {
            Text("No songs in this genre.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.top, 40)
        } else {
            LazyVStack(spacing: 0) {
                ForEach(songs) { song in
                    songRow(song)
                    if song.id != songs.last?.id {
                        Divider().padding(.leading, 56)
                    }
                }
            }
            .padding(.horizontal)
        }
    }

    private func songRow(_ song: Song) -> some View {
        HStack(spacing: 12) {
            CoverArtImage(id: song.coverArt, size: 80)
                .frame(width: 44, height: 44)
                .clipShape(RoundedRectangle(cornerRadius: 6))

            VStack(alignment: .leading, spacing: 2) {
                Text(song.title)
                    .font(.body)
                    .lineLimit(1)
                Text(song.artist)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Text(formatDuration(song.duration))
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .onTapGesture {
            store.playQueue(songs.map { $0.toNowPlayingSong() },
                            startIndex: songs.firstIndex(where: { $0.id == song.id }) ?? 0)
        }
    }

    private func formatDuration(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%d:%02d", m, s)
    }

    private func loadAlbums() async {
        isLoadingAlbums = true
        defer { isLoadingAlbums = false }
        do {
            albums = try await NavidromeClient.shared.getAlbums(
                type: "byGenre", size: 500, offset: 0, genre: genre.name
            )
        } catch {
            print("[genre] failed to load albums: \(error)")
        }
    }

    private func loadSongs() async {
        isLoadingSongs = true
        defer { isLoadingSongs = false }
        do {
            songs = try await NavidromeClient.shared.getSongsByGenre(
                genre: genre.name, count: 200
            )
        } catch {
            print("[genre] failed to load songs: \(error)")
        }
    }
}
