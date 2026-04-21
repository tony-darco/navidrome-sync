import SwiftUI

struct ArtistDetailView: View {
    let artistId: String
    let artistName: String

    @EnvironmentObject private var store: SyncStore
    @EnvironmentObject private var downloadManager: DownloadManager

    @State private var albums: [Album] = []
    @State private var topSongs: [Song] = []
    @State private var artistInfo: ArtistInfo2?
    @State private var isLoading = true

    private let columns = [
        GridItem(.adaptive(minimum: 160), spacing: 16)
    ]

    var body: some View {
        ScrollView {
            if isLoading {
                ProgressView()
                    .padding(.top, 60)
            } else {
                VStack(spacing: 0) {
                    artistHeader
                    if !topSongs.isEmpty {
                        topSongsSection
                    }
                    if !albums.isEmpty {
                        albumsSection
                    }
                    if topSongs.isEmpty && albums.isEmpty {
                        Text("No content found")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .padding(.top, 40)
                    }
                }
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadArtist()
        }
    }

    // MARK: - Artist Header

    private var artistHeader: some View {
        ZStack(alignment: .bottomLeading) {
            if let imageURL = artistInfo?.imageURL, let url = URL(string: imageURL) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    default:
                        artistPlaceholder
                    }
                }
            } else {
                artistPlaceholder
            }

            // Gradient overlay for text legibility
            LinearGradient(
                colors: [.clear, .black.opacity(0.7)],
                startPoint: .center,
                endPoint: .bottom
            )

            Text(artistName)
                .font(.system(size: 34, weight: .bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
        }
        .frame(height: 400)
        .frame(maxWidth: .infinity)
        .clipped()
    }

    private var artistPlaceholder: some View {
        Rectangle()
            .fill(Color(.systemGray5))
            .overlay {
                Image(systemName: "person.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(.secondary)
            }
    }

    // MARK: - Top Songs

    private var topSongsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Top Songs")
                    .font(.title2)
                    .fontWeight(.bold)
                Image(systemName: "chevron.right")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal)

            let songRows = min(topSongs.count, 4)
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(alignment: .top, spacing: 12) {
                    ForEach(0..<(topSongs.count + songRows - 1) / songRows, id: \.self) { col in
                        VStack(spacing: 0) {
                            ForEach(0..<songRows, id: \.self) { row in
                                let idx = col * songRows + row
                                if idx < topSongs.count {
                                    Button {
                                        playSong(topSongs[idx], at: idx)
                                    } label: {
                                        songRow(topSongs[idx])
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
        .padding(.bottom, 24)
    }

    private func songRow(_ song: Song) -> some View {
        let isNowPlaying = song.id == store.nowPlaying?.songId
        return HStack(spacing: 12) {
            CoverArtImage(id: song.coverArt, size: 80, isNowPlaying: isNowPlaying, isPlaying: store.isPlaying)
                .frame(width: 44, height: 44)
                .clipShape(RoundedRectangle(cornerRadius: 6))

            VStack(alignment: .leading, spacing: 2) {
                Text(song.title)
                    .font(.body)
                    .lineLimit(1)
                Text(song.album)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            DownloadStatusIcon(task: downloadManager.taskMap[song.id])

            Menu {
                Button {
                    playSong(song, at: topSongs.firstIndex(where: { $0.id == song.id }) ?? 0)
                } label: {
                    Label("Play", systemImage: "play.fill")
                }
                Button {
                    store.appendToQueue(song.toNowPlayingSong())
                } label: {
                    Label("Add to Queue", systemImage: "text.badge.plus")
                }
                Divider()
                if downloadManager.isDownloaded(songId: song.id) {
                    Button(role: .destructive) {
                        downloadManager.remove(songId: song.id)
                    } label: {
                        Label("Remove Download", systemImage: "trash")
                    }
                } else {
                    Button {
                        downloadManager.download(song: song)
                    } label: {
                        Label("Download", systemImage: "arrow.down.circle")
                    }
                }
            } label: {
                Image(systemName: "ellipsis")
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 300)
        .padding(.vertical, 8)
    }

    // MARK: - Albums

    private var albumsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Albums")
                .font(.title2)
                .fontWeight(.bold)
                .padding(.horizontal)

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
                            if let year = album.year {
                                Text(String(year))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
        }
        .padding(.bottom, 24)
    }

    // MARK: - Actions

    private func playSong(_ song: Song, at index: Int) {
        let nowPlayingSongs = topSongs.map { $0.toNowPlayingSong() }
        store.playQueue(nowPlayingSongs, startIndex: index)
    }

    private func loadArtist() async {
        defer { isLoading = false }
        do {
            async let detailResult = NavidromeClient.shared.getArtist(id: artistId)
            async let infoResult = NavidromeClient.shared.getArtistInfo2(id: artistId)
            async let topResult = NavidromeClient.shared.getTopSongs(artistName: artistName, count: 10)

            let detail = try await detailResult
            let info = try? await infoResult
            let top = (try? await topResult) ?? []

            albums = (detail.album ?? []).sorted { ($0.year ?? 9999) < ($1.year ?? 9999) }
            artistInfo = info
            topSongs = top
        } catch {
            print("[artist] failed to load: \(error)")
        }
    }

    private func formatDuration(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%d:%02d", m, s)
    }
}
