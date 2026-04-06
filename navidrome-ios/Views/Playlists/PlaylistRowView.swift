import SwiftUI

struct PlaylistRowView: View {
    let playlist: Playlist

    var body: some View {
        HStack(spacing: 12) {
            if !playlist.coverArt.isEmpty {
                CoverArtImage(id: playlist.coverArt, size: 80)
                    .frame(width: 48, height: 48)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            } else {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(.systemGray5))
                    .frame(width: 48, height: 48)
                    .overlay {
                        Image(systemName: "music.note.list")
                            .foregroundStyle(.secondary)
                    }
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(playlist.name)
                    .font(.body)
                    .lineLimit(1)
                Text("\(playlist.songCount) tracks")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}
