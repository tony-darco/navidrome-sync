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
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]

    var body: some View {
        ScrollView {
            if isLoading {
                ProgressView()
                    .padding(.top, 60)
            } else {
                VStack(spacing: 0) {
                    artistHeader
                    VStack(spacing: 0) {
                        if !topSongs.isEmpty {
                            topSongsSection
                                .padding(.top, 16)
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
                    .background(Color(.systemGroupedBackground))
                }
            }
        }
        .ignoresSafeArea(edges: .top)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .task {
            await loadArtist()
        }
    }

    // MARK: - Artist Header

    private var artistHeader: some View {
        GeometryReader { geo in
            ZStack(alignment: .bottomLeading) {
                // Background image — clipped via its own frame, not the ZStack
                if let imageURL = artistInfo?.imageURL, let url = URL(string: imageURL) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: geo.size.width, height: 320)
                                .clipped()
                        default:
                            Rectangle().fill(Color(.systemGray6))
                                .frame(width: geo.size.width, height: 320)
                        }
                    }
                } else {
                    Rectangle().fill(Color(.systemGray6))
                        .frame(width: geo.size.width, height: 320)
                }

                // Gradient and text render freely — not clipped
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0.0),
                        .init(color: .black.opacity(0.3), location: 0.4),
                        .init(color: .black.opacity(0.92), location: 1.0)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(width: geo.size.width, height: 320)

                VStack(alignment: .leading, spacing: 6) {
                    Text(artistName)
                        .font(.system(size: 38, weight: .heavy))
                        .foregroundStyle(.white)
                        .minimumScaleFactor(0.6)
                        .lineLimit(2)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
            .frame(width: geo.size.width, height: 320)
        }
        .frame(height: 320)
        .ignoresSafeArea(edges: .top)
    }

    // MARK: - Top Songs

    private var topSongsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("POPULAR")
                .font(.system(size: 11, weight: .semibold))
                .kerning(1.4)
                .foregroundStyle(Color.red)
                .padding(.horizontal, 16)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(alignment: .top, spacing: 0) {
                    ForEach(0..<columnCount, id: \.self) { col in
                        VStack(spacing: 0) {
                            ForEach(0..<4, id: \.self) { row in
                                let idx = col * 4 + row
                                if idx < topSongs.count {
                                    Button {
                                        playSong(topSongs[idx], at: idx)
                                    } label: {
                                        songRow(topSongs[idx], index: idx)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        .frame(width: UIScreen.main.bounds.width - 32)
                    }
                }
                .padding(.horizontal, 16)
            }

            HStack {
                Spacer()
                Text("SEE MORE")
                    .font(.system(size: 11, weight: .semibold))
                    .kerning(1.0)
                    .foregroundStyle(Color.red)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 10)
        }
        .padding(.bottom, 24)
    }

    private var columnCount: Int {
        (topSongs.count + 3) / 4
    }

    private func songRow(_ song: Song, index: Int) -> some View {
        let isNowPlaying = song.id == store.nowPlaying?.songId
        return HStack(spacing: 12) {
            CoverArtImage(id: song.coverArt, size: 80, isNowPlaying: isNowPlaying, isPlaying: store.isPlaying)
                .frame(width: 32, height: 32)
                .clipShape(RoundedRectangle(cornerRadius: 4))

            Text(song.title)
                .font(.system(size: 15, weight: .semibold))
                .lineLimit(1)

            Spacer()

            Text(formatDuration(song.duration))
                .font(.system(size: 13))
                .foregroundStyle(.secondary)

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
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
    }

    // MARK: - Albums

    private var albumsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("ALBUMS")
                .font(.system(size: 11, weight: .semibold))
                .kerning(1.4)
                .foregroundStyle(Color.red)
                .padding(.horizontal, 16)
                .padding(.bottom, 4)

            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(albums) { album in
                    NavigationLink(value: album) {
                        VStack(alignment: .leading, spacing: 6) {
                            CoverArtImage(id: album.coverArt, size: 300)
                                .aspectRatio(1, contentMode: .fill)
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                            Text(album.name)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.primary)
                                .lineLimit(1)
                            if let year = album.year {
                                Text(String(year))
                                    .font(.system(size: 12))
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 14)
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
