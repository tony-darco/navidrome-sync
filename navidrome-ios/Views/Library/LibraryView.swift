import SwiftUI

struct LibraryView: View {
    @EnvironmentObject private var store: SyncStore
    @State private var recentAlbums: [Album] = []
    @State private var isLoading = false

    private let libraryRows: [(icon: String, title: String)] = [
        ("music.note.list", "Playlists"),
        ("music.mic", "Artists"),
        ("square.stack", "Albums"),
        ("music.note", "Songs"),
    ]

    private let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16),
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // Navigation rows
                    VStack(spacing: 0) {
                        ForEach(libraryRows, id: \.title) { row in
                            NavigationLink(value: row.title) {
                                HStack {
                                    Image(systemName: row.icon)
                                        .foregroundColor(Color.brandPink)
                                        .font(.title2)
                                        .frame(width: 32, height: 32)
                                    Text(row.title)
                                        .font(.title3)
                                        .foregroundColor(.primary)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .foregroundColor(.secondary)
                                        .font(.body)
                                }
                                .padding(.vertical, 8)
                                .padding(.horizontal, 0)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            if row.title != libraryRows.last?.title {
                                Divider().padding(.leading, 48)
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 4)

                    // Recently Added
                    if !recentAlbums.isEmpty {
                        Text("Recently Added")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                            .padding(.horizontal, 16)
                            .padding(.top, 24)
                            .padding(.bottom, 8)

                        LazyVGrid(columns: columns, spacing: 16) {
                            ForEach(recentAlbums) { album in
                                NavigationLink(value: album) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        CoverArtImage(id: album.coverArt, size: 300)
                                            .aspectRatio(1, contentMode: .fit)
                                            .clipShape(RoundedRectangle(cornerRadius: 8))

                                        Text(album.name)
                                            .font(.caption)
                                            .fontWeight(.medium)
                                            .foregroundColor(.primary)
                                            .lineLimit(1)

                                        Text(album.artist)
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                            .lineLimit(1)
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                }
            }
            .background {
                store.dominantBackgroundColor
                    .ignoresSafeArea()
            }
            .navigationTitle("Library")
            .navigationBarTitleDisplayMode(.large)
            .navigationDestination(for: String.self) { destination in
                switch destination {
                case "Playlists": PlaylistsView()
                case "Artists": ArtistsView()
                case "Albums": AlbumsView()
                case "Songs": SongsView()
                default: EmptyView()
                }
            }
            .navigationDestination(for: Album.self) { album in
                AlbumDetailView(albumId: album.id)
            }
            .task {
                await loadRecentAlbums()
            }
        }
    }

    private func loadRecentAlbums() async {
        guard recentAlbums.isEmpty else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            recentAlbums = try await NavidromeClient.shared.getAlbums(type: "newest", size: 20)
        } catch {
            print("[library] failed to load recent albums: \(error)")
        }
    }
}

// Make Album Hashable for NavigationLink value
extension Album: Hashable {
    static func == (lhs: Album, rhs: Album) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}
