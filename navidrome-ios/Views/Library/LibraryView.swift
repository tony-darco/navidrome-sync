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

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // Navigation rows
                    VStack(spacing: 0) {
                        ForEach(libraryRows, id: \.title) { row in
                            NavigationLink(value: row.title) {
                                HStack(spacing: 12) {
                                    Image(systemName: row.icon)
                                        .foregroundStyle(.accent)
                                        .frame(width: 24)
                                    Text(row.title)
                                        .font(.body)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundStyle(.tertiary)
                                }
                                .padding(.vertical, 12)
                                .padding(.horizontal, 16)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            if row.title != libraryRows.last?.title {
                                Divider().padding(.leading, 52)
                            }
                        }
                    }
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .padding(.horizontal)
                    .padding(.top, 8)

                    // Recently Added
                    if !recentAlbums.isEmpty {
                        Text("Recently Added")
                            .font(.title3)
                            .fontWeight(.bold)
                            .padding(.horizontal)
                            .padding(.top, 24)
                            .padding(.bottom, 8)

                        ScrollView(.horizontal, showsIndicators: false) {
                            LazyHStack(spacing: 12) {
                                ForEach(recentAlbums) { album in
                                    NavigationLink(value: album) {
                                        VStack(alignment: .leading, spacing: 4) {
                                            CoverArtImage(id: album.coverArt, size: 300)
                                                .frame(width: 140, height: 140)
                                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                            Text(album.name)
                                                .font(.caption)
                                                .fontWeight(.medium)
                                                .lineLimit(1)
                                            Text(album.artist)
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)
                                                .lineLimit(1)
                                        }
                                        .frame(width: 140)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Library")
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
