import SwiftUI

struct AlbumDetailView: View {
    let albumId: String

    @EnvironmentObject private var store: SyncStore
    @EnvironmentObject private var downloadManager: DownloadManager
    @State private var album: Album?
    @State private var songs: [Song] = []
    @State private var isLoading = true
    @State private var dominantColor: Color = .clear

    var body: some View {
        ScrollView {
            if isLoading {
                ProgressView()
                    .padding(.top, 60)
            } else if let album {
                VStack(spacing: 0) {
                    albumHeader(album)
                    trackList
                        .padding(.top, 12)
                }
            }
        }
        .background(backgroundGradient)
        .navigationTitle(album?.name ?? "Album")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadAlbum()
            await extractDominantColor()
        }
    }

    // MARK: - Background gradient

    @ViewBuilder
    private var backgroundGradient: some View {
        if AppConfig.coloredAlbumBackground && dominantColor != .clear {
            LinearGradient(
                colors: [dominantColor.opacity(0.7), .black],
                startPoint: .top,
                endPoint: .center
            )
            .ignoresSafeArea()
        } else {
            Color.black.ignoresSafeArea()
        }
    }

    // MARK: - Album header

    private func albumHeader(_ album: Album) -> some View {
        VStack(spacing: 12) {
            CoverArtImage(id: album.coverArt, size: 600)
                .frame(width: 280, height: 280)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .shadow(radius: 10)

            Text(album.name)
                .font(.title2)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)

            Text(album.artist)
                .font(.headline)
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                if let year = album.year {
                    Text(String(year))
                }
                if album.year != nil {
                    Text("·")
                }
                Text("\(album.songCount) tracks")
            }
            .font(.caption)
            .foregroundStyle(.tertiary)

            // Shuffle + Play
            HStack(spacing: 24) {
                Button {
                    store.toggleShuffle()
                    playAll()
                } label: {
                    Image(systemName: "shuffle")
                        .font(.title3)
                        .frame(width: 44, height: 44)
                        .background(Color(.systemGray5))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)

                Button {
                    playAll()
                } label: {
                    Label("Play", systemImage: "play.fill")
                        .font(.headline)
                        .padding(.horizontal, 32)
                        .padding(.vertical, 12)
                        .background(Color(.systemGray5))
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)

                Button {
                    downloadManager.download(songs: songs)
                } label: {
                    Image(systemName: "arrow.down.circle")
                        .font(.title3)
                        .frame(width: 44, height: 44)
                        .background(Color(.systemGray5))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 4)
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }

    // MARK: - Track list

    private var trackList: some View {
        VStack(spacing: 0) {
            ForEach(Array(songs.enumerated()), id: \.element.id) { index, song in
                Button { playTrack(at: index) } label: {
                    HStack(spacing: 12) {
                        Text("\(song.track)")
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .frame(width: 28, alignment: .leading)

                        Text(song.title)
                            .font(.body)
                            .lineLimit(1)

                        Spacer()
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .overlay(alignment: .trailing) {
                    HStack(spacing: 6) {
                        DownloadStatusIcon(task: downloadManager.taskMap[song.id])
                        songMenu(index: index, song: song)
                    }
                }
                .padding(.vertical, 10)
                .padding(.horizontal)

                if index < songs.count - 1 {
                    Divider().padding(.leading, 56)
                }
            }
        }
    }

    // MARK: - Song context menu

    private func songMenu(index: Int, song: Song) -> some View {
        Menu {
            Button {
                playTrack(at: index)
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
                .font(.body)
                .foregroundStyle(.secondary)
                .frame(width: 36, height: 36)
                .contentShape(Rectangle())
        }
    }

    // MARK: - Actions

    private func playAll() {
        guard !songs.isEmpty else { return }
        let queue = songs.map { $0.toNowPlayingSong() }
        store.playQueue(queue, startIndex: 0)
    }

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

    private func extractDominantColor() async {
        guard AppConfig.coloredAlbumBackground else { return }
        let coverArtId = album?.coverArt ?? ""
        guard !coverArtId.isEmpty else { return }
        if let image = await NavidromeClient.shared.fetchCoverArt(id: coverArtId, size: 50) {
            dominantColor = image.dominantColor()
        }
    }
}
