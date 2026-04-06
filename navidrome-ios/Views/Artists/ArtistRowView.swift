import SwiftUI

struct ArtistRowView: View {
    let artist: ArtistID3

    var body: some View {
        HStack {
            Text(artist.name)
                .font(.body)
            Spacer()
            Text("\(artist.albumCount) albums")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}
