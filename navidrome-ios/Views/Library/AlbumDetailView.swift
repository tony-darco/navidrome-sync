import SwiftUI

struct AlbumDetailView: View {
    let albumId: String

    @EnvironmentObject private var store: SyncStore
    @State private var album: Album?
    @State private var songs: [Song] = []
    @State private var isLoading = true

    var body: some View {
        ScrollView {
            if isLoading {
                ProgressView()
                    .padding(.top, 60)
            } else if let album {
                VStack(spacing: 20) {
                    albumHeader(album)
                    trackList
                }
                .padding()
            }
        }
        .navigationTitle(album?.name ?? "Album")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadAlbum()
        }
    }

    // MARK: - Album header

    private func albumHeader(_ album: Album) -> some View {
        VStack(spacing: 12) {
            CoverArtImage(id: album.coverArt, size: 600)
                .frame(width: 220, height: 220)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .shadow(radius: 8)

            Text(album.name)
                .font(.title2)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)

            Text(album.artist)
                .font(.title3)
                .foregroundStyle(.secondary)

            HStack(spacing: 16) {
                if let year = album.year {
                    Text(String(year))
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                Text("\(album.songCount) tracks")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    // MARK: - Track list

    private var trackList: some View {
        VStack(spacing: 0) {
            ForEach(Array(songs.enumerated()), id: \.element.id) { index, song in
                Button { playTrack(at: index) } label: {
                    trackRow(song)
                }
                .buttonStyle(.plain)

                if index < songs.count - 1 {
                    Divider().padding(.leading, 36)
                }
            }
        }
    }

    private func trackRow(_ song: Song) -> some View {
        HStack(spacing: 12) {
            Text("\(song.track)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(width: 24, alignment: .trailing)

            VStack(alignment: .leading, spacing: 2) {
                Text(song.title)
                    .font(.subheadline)
                    .lineLimit(1)
                if song.artist != album?.artist {
                    Text(song.artist)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            Text(formatDuration(song.duration))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }

    // MARK: - Actions

    private func playTrack(at index: Int) {
        let queue = songs.map { $0.toNowPlayingSong() }
        store.playQueue(queue, startIndex: index)
    }

    private func loadAlbum() async {
        defer { isLoading = false }
        do {
            let result = try await NavidromeClient.shared.getAlbum(id: albumId)
            album = result.album
            songs = result.songs
        } catch {
            print("[album] failed to load: \(error)")
        }
    }

    private func formatDuration(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%d:%02d", m, s)
    }
}
