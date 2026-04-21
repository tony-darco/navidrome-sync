import SwiftUI

struct AlbumGridView: View {
    let albums: [Album]

    private let columns = [
        GridItem(.adaptive(minimum: 160), spacing: 16)
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 16) {
            ForEach(albums) { album in
                NavigationLink(value: album) {
                    albumCell(album)
                }
                .buttonStyle(.plain)
            }
        }
        .padding()
    }

    private func albumCell(_ album: Album) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            CoverArtImage(id: album.coverArt, size: 300)
                .aspectRatio(1, contentMode: .fill)
                .clipShape(RoundedRectangle(cornerRadius: 8))

            Text(album.name)
                .font(.subheadline)
                .fontWeight(.medium)
                .lineLimit(1)
                .foregroundStyle(DesignText.onDark)

            Text(album.artist)
                .font(.caption)
                .foregroundStyle(DesignText.onDarkMuted)
                .lineLimit(1)
        }
    }
}
