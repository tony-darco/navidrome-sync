import SwiftUI

struct ArtistDetailView: View {
    let artistId: String
    let artistName: String

    @State private var albums: [Album] = []
    @State private var isLoading = true

    private let columns = [
        GridItem(.adaptive(minimum: 160), spacing: 16)
    ]

    var body: some View {
        ScrollView {
            if isLoading {
                ProgressView()
                    .padding(.top, 60)
            } else if albums.isEmpty {
                Text("No albums found")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.top, 60)
            } else {
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(albums) { album in
                        NavigationLink(value: album) {
                            VStack(alignment: .leading, spacing: 6) {
                                CoverArtImage(id: album.coverArt, size: 300)
                                    .aspectRatio(1, contentMode: .fill)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                Text(album.name)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .lineLimit(1)
                                Text(album.artist)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding()
            }
        }
        .navigationTitle(artistName)
        .navigationDestination(for: Album.self) { album in
            AlbumDetailView(albumId: album.id)
        }
        .task {
            await loadArtist()
        }
    }

    private func loadArtist() async {
        defer { isLoading = false }
        do {
            let detail = try await NavidromeClient.shared.getArtist(id: artistId)
            albums = detail.album ?? []
        } catch {
            print("[artist] failed to load: \(error)")
        }
    }
}
