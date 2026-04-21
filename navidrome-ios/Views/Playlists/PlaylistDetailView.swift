import SwiftUI

struct PlaylistDetailView: View {
    let playlistId: String
    let playlistName: String

    @EnvironmentObject private var store: SyncStore
    @EnvironmentObject private var playlistStore: PlaylistStore
    @EnvironmentObject private var downloadManager: DownloadManager
    @State private var playlist: PlaylistWithSongs?
    @State private var isLoading = true
    @State private var showEditView = false
    @State private var showDeleteAlert = false
    @State private var dominantColor: Color = .clear

    var body: some View {
        ScrollView {
            if isLoading {
                ProgressView()
                    .padding(.top, 60)
            } else if let playlist {
                VStack(spacing: 0) {
                    playlistHeader(playlist)
                    trackList(playlist)
                        .padding(.top, 12)
                }
            }
        }
        .background(backgroundGradient)
        .navigationTitle(playlistName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button("Edit") { showEditView = true }
                Button(role: .destructive) {
                    showDeleteAlert = true
                } label: {
                    Image(systemName: "trash")
                }
            }
        }
        .alert("Delete Playlist?", isPresented: $showDeleteAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                Task {
                    await playlistStore.deletePlaylist(id: playlistId)
                }
            }
        } message: {
            Text("This cannot be undone.")
        }
        .fullScreenCover(isPresented: $showEditView) {
            NavigationStack {
                PlaylistEditView(playlistId: playlistId) {
                    showEditView = false
                    Task { await loadPlaylist() }
                }
            }
        }
        .task {
            await loadPlaylist()
            await extractDominantColor()
        }
    }

    // MARK: - Background gradient

    @ViewBuilder
    private var backgroundGradient: some View {
        if AppConfig.coloredPlaylistBackground && dominantColor != .clear {
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

    // MARK: - Header

    private func playlistHeader(_ playlist: PlaylistWithSongs) -> some View {
        VStack(spacing: 12) {
            if !playlist.coverArt.isEmpty {
                CoverArtImage(id: playlist.coverArt, size: 600)
                    .frame(width: 280, height: 280)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .shadow(radius: 10)
            }
            Text(playlist.name)
                .font(.title2)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
            Text("\(playlist.songCount) tracks")
                .font(.caption)
                .foregroundStyle(.secondary)

            // Shuffle + Play
            HStack(spacing: 24) {
                Button {
                    store.toggleShuffle()
                    playAll(playlist)
                } label: {
                    Image(systemName: "shuffle")
                        .font(.title3)
                        .frame(width: 44, height: 44)
                        .background(Color(.systemGray5))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)

                Button {
                    playAll(playlist)
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
                    let entries = playlist.entry ?? []
                    downloadManager.download(songs: entries)
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

    private func trackList(_ playlist: PlaylistWithSongs) -> some View {
        VStack(spacing: 0) {
            let entries = playlist.entry ?? []
            ForEach(Array(entries.enumerated()), id: \.element.id) { index, song in
                Button { playTrack(at: index, in: entries) } label: {
                    HStack(spacing: 12) {
                        CoverArtImage(id: song.coverArt, size: 80,
                                      isNowPlaying: song.id == store.nowPlaying?.songId,
                                      isPlaying: store.isPlaying)
                            .frame(width: 50, height: 50)
                            .clipShape(RoundedRectangle(cornerRadius: 6))

                        VStack(alignment: .leading, spacing: 2) {
                            Text(song.title)
                                .font(.body)
                                .lineLimit(1)
                            Text(song.artist)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        Spacer()
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .overlay(alignment: .trailing) {
                    HStack(spacing: 6) {
                        DownloadStatusIcon(task: downloadManager.taskMap[song.id])
                        songMenu(index: index, song: song, entries: entries)
                    }
                }
                .padding(.vertical, 6)
                .padding(.horizontal)

                if index < entries.count - 1 {
                    Divider().padding(.leading, 78)
                }
            }
        }
    }

    // MARK: - Song context menu

    private func songMenu(index: Int, song: Song, entries: [Song]) -> some View {
        Menu {
            Button {
                playTrack(at: index, in: entries)
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
            Divider()
            Button(role: .destructive) {
                Task {
                    try? await NavidromeClient.shared.updatePlaylist(
                        playlistId: playlistId,
                        songIndexesToRemove: [index]
                    )
                    await loadPlaylist()
                    playlistStore.notifyChanged(playlistId: playlistId, action: "updated")
                }
            } label: {
                Label("Remove from Playlist", systemImage: "minus.circle")
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

    private func playAll(_ playlist: PlaylistWithSongs) {
        let entries = playlist.entry ?? []
        guard !entries.isEmpty else { return }
        let queue = entries.map { $0.toNowPlayingSong() }
        store.playQueue(queue, startIndex: 0)
    }

    private func playTrack(at index: Int, in songs: [Song]) {
        let queue = songs.map { $0.toNowPlayingSong() }
        store.playQueue(queue, startIndex: index)
    }

    private func loadPlaylist() async {
        isLoading = true
        defer { isLoading = false }
        do {
            playlist = try await NavidromeClient.shared.getPlaylist(id: playlistId)
        } catch {
            print("[playlist] failed to load: \(error)")
        }
    }

    private func extractDominantColor() async {
        guard AppConfig.coloredPlaylistBackground else { return }
        let coverArtId = playlist?.coverArt ?? ""
        guard !coverArtId.isEmpty else { return }
        if let image = await NavidromeClient.shared.fetchCoverArt(id: coverArtId, size: 50) {
            dominantColor = image.dominantColor()
        }
    }
}
