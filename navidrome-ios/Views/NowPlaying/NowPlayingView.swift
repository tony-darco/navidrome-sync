import SwiftUI

struct NowPlayingView: View {
    @EnvironmentObject private var store: SyncStore
    var onNavigateToAlbum: ((String) -> Void)? = nil
    var onNavigateToArtist: ((String, String) -> Void)? = nil
    @State private var showQueue = false
    @State private var showAddToPlaylist = false

    var body: some View {
        NavigationStack {
            Group {
                if let song = store.nowPlaying {
                    songView(song)
                } else {
                    emptyState
                }
            }
            .background(backgroundGradient)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    HStack(spacing: 6) {
                        Text("Now Playing")
                            .font(.headline)
                        if store.isConnected {
                            Circle()
                                .fill(Color.brandPink)
                                .frame(width: 8, height: 8)
                        }
                    }
                }
            }

        }
    }

    // MARK: - Background

    @ViewBuilder
    private var backgroundGradient: some View {
        store.dominantBackgroundColor
            .ignoresSafeArea()
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "music.note")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)
            Text("Nothing playing")
                .font(.title3)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Song view

    private func songView(_ song: NowPlayingSong) -> some View {
        VStack(spacing: 24) {
            Spacer()

            // Cover art
            CoverArtImage(id: song.coverArtId, size: 600)
                .frame(width: 300, height: 300)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .shadow(radius: 10)

            // Song info
            VStack(spacing: 6) {
                if let albumId = song.albumId, !albumId.isEmpty {
                    Button { onNavigateToAlbum?(albumId) } label: {
                        Text(song.title)
                            .font(.title2)
                            .fontWeight(.bold)
                            .lineLimit(1)
                    }
                    .buttonStyle(.plain)
                } else {
                    Text(song.title)
                        .font(.title2)
                        .fontWeight(.bold)
                        .lineLimit(1)
                }

                if let artistId = song.artistId, !artistId.isEmpty {
                    Button { onNavigateToArtist?(artistId, song.artist) } label: {
                        Text(song.artist)
                            .font(.title3)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    .buttonStyle(.plain)
                } else {
                    Text(song.artist)
                        .font(.title3)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                if let albumId = song.albumId, !albumId.isEmpty {
                    Button { onNavigateToAlbum?(albumId) } label: {
                        Text(song.album)
                            .font(.subheadline)
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                    }
                    .buttonStyle(.plain)
                } else {
                    Text(song.album)
                        .font(.subheadline)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }
            .padding(.horizontal)

            // Star + Add to playlist
            HStack(spacing: 24) {
                Button { store.toggleStar() } label: {
                    Image(systemName: song.starred == true ? "heart.fill" : "heart")
                        .font(.title2)
                        .foregroundStyle(song.starred == true ? .red : .secondary)
                }

                Button { showAddToPlaylist = true } label: {
                    Image(systemName: "plus.circle")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
            }

            // Progress
            if store.myRole == "active" {
                activeProgressBar(song)
            } else {
                observerProgressBar(song)
            }

            // Transport controls (both roles)
            transportControls(for: song)
            extraControls

            // Play Here (when not active)
            if store.isConnected && store.myRole != "active" {
                PlayHereButton()
            }

            Spacer()
        }
        .padding()
        .sheet(isPresented: $showQueue) {
            QueueSheet()
                .environmentObject(store)
        }
        .sheet(isPresented: $showAddToPlaylist) {
            AddToPlaylistSheet(songId: song.songId)
        }
    }

    // MARK: - Active: seekable progress

    private func activeProgressBar(_ song: NowPlayingSong) -> some View {
        VStack(spacing: 4) {
            Slider(
                value: Binding(
                    get: { store.position },
                    set: { store.seek(to: $0) }
                ),
                in: 0...max(Double(song.durationSecs), 1)
            )
            .tint(.white)

            HStack {
                Text(formatTime(store.position))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(formatTime(Double(song.durationSecs)))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal)
    }

    // MARK: - Observer: non-interactive progress

    private func observerProgressBar(_ song: NowPlayingSong) -> some View {
        VStack(spacing: 4) {
            Slider(
                value: Binding(
                    get: { store.position },
                    set: { store.seek(to: $0) }
                ),
                in: 0...max(Double(song.durationSecs), 1)
            )
            .tint(.white)

            HStack {
                Text(formatTime(store.position))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(formatTime(Double(song.durationSecs)))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal)
    }

    // MARK: - Transport controls

    private func transportControls(for song: NowPlayingSong) -> some View {
        HStack(spacing: 40) {
            Button { store.prev() } label: {
                Image(systemName: "backward.fill")
                    .font(.title)
            }

            Button {
                store.isPlaying ? store.pause() : store.play()
            } label: {
                Image(systemName: store.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 56))
            }

            Button { store.next() } label: {
                Image(systemName: "forward.fill")
                    .font(.title)
            }
        }
        .foregroundStyle(.primary)
    }

    // MARK: - Shuffle / Repeat / Queue

    private var extraControls: some View {
        HStack(spacing: 36) {
            Button { store.toggleShuffle() } label: {
                Image(systemName: "shuffle")
                    .font(.title3)
                    .foregroundStyle(store.isShuffled ? Color.brandPink : .secondary)
            }

            Spacer()

            Button { store.toggleRepeat() } label: {
                Image(systemName: store.repeatMode == .one ? "repeat.1" : "repeat")
                    .font(.title3)
                    .foregroundStyle(store.repeatMode != .off ? Color.brandPink : .secondary)
            }

            Spacer()

            Button { showQueue = true } label: {
                Image(systemName: "list.bullet")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 24)
    }

    // MARK: - Helpers

    private func formatTime(_ seconds: Double) -> String {
        let total = Int(max(seconds, 0))
        let m = total / 60
        let s = total % 60
        return String(format: "%d:%02d", m, s)
    }
}

// MARK: - Queue Sheet

struct QueueSheet: View {
    @EnvironmentObject private var store: SyncStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                // Now Playing
                if store.queueIndex < store.queue.count {
                    Section("Now Playing") {
                        queueRow(store.queue[store.queueIndex], isActive: true)
                    }
                }

                // Up Next
                let upcoming = Array(store.queue.dropFirst(store.queueIndex + 1))
                if !upcoming.isEmpty {
                    Section {
                        ForEach(Array(upcoming.enumerated()), id: \.element.songId) { offset, song in
                            Button {
                                store.playQueue(store.queue, startIndex: store.queueIndex + 1 + offset)
                            } label: {
                                queueRow(song, isActive: false)
                            }
                            .buttonStyle(.plain)
                        }
                    } header: {
                        HStack {
                            Text("Next From: \(store.nowPlaying?.album ?? "")")
                            Spacer()
                            if upcoming.count > 0 {
                                Button("Clear queue") {
                                    store.clearQueue()
                                }
                                .font(.subheadline)
                            }
                        }
                    }
                }
            }
            .listStyle(.plain)
            .navigationTitle(store.nowPlaying?.album ?? "Queue")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                    }
                }
            }
        }
    }

    private func queueRow(_ song: NowPlayingSong, isActive: Bool) -> some View {
        HStack(spacing: 12) {
            CoverArtImage(id: song.coverArtId, size: 80)
                .frame(width: 44, height: 44)
                .clipShape(RoundedRectangle(cornerRadius: 6))

            VStack(alignment: .leading, spacing: 2) {
                Text(song.title)
                    .font(.subheadline)
                    .fontWeight(isActive ? .semibold : .regular)
                    .foregroundStyle(isActive ? Color.brandPink : .primary)
                    .lineLimit(1)
                Text(song.artist)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            if isActive {
                WaveformBarsView(isAnimating: store.isPlaying, color: Color.brandPink)
                    .padding(.trailing, 4)
            }
        }
    }
}
