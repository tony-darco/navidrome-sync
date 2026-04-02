import SwiftUI

struct NowPlayingView: View {
    @EnvironmentObject private var store: SyncStore

    var body: some View {
        NavigationStack {
            Group {
                if let song = store.nowPlaying {
                    songView(song)
                } else {
                    emptyState
                }
            }
            .navigationTitle("Now Playing")
            .navigationBarTitleDisplayMode(.inline)
        }
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
                Text(song.title)
                    .font(.title2)
                    .fontWeight(.bold)
                    .lineLimit(1)
                Text(song.artist)
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Text(song.album)
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
            .padding(.horizontal)

            // Progress
            if store.myRole == "active" {
                activeProgressBar(song)
            } else {
                observerProgressBar(song)
            }

            // Controls or Play Here
            if store.myRole == "active" {
                transportControls
            } else {
                PlayHereButton()
            }

            // Role badge (only when sync is active)
            if store.isConnected {
                roleBadge

                // Connected clients
                clientsList
            }

            Spacer()
        }
        .padding()
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
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color(.systemGray4))
                        .frame(height: 4)
                    Capsule()
                        .fill(Color(.systemGray))
                        .frame(
                            width: song.durationSecs > 0
                                ? geo.size.width * min(store.position / Double(song.durationSecs), 1)
                                : 0,
                            height: 4
                        )
                }
            }
            .frame(height: 4)

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

    // MARK: - Transport controls (active only)

    private var transportControls: some View {
        HStack(spacing: 40) {
            Button { store.prev() } label: {
                Image(systemName: "backward.fill")
                    .font(.title)
            }

            Button { store.isPlaying ? store.pause() : store.play() } label: {
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

    // MARK: - Role badge

    private var roleBadge: some View {
        Text(store.myRole == "active" ? "Active Client" : "Observing")
            .font(.caption)
            .fontWeight(.medium)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(store.myRole == "active" ? Color.green.opacity(0.2) : Color.secondary.opacity(0.2))
            .foregroundStyle(store.myRole == "active" ? .green : .secondary)
            .clipShape(Capsule())
    }

    // MARK: - Clients list

    private var clientsList: some View {
        HStack(spacing: 8) {
            ForEach(store.connectedClients) { client in
                HStack(spacing: 4) {
                    Image(systemName: client.clientType == "ios" ? "iphone" : "desktopcomputer")
                        .font(.caption2)
                    Text(client.role == "active" ? "Active" : "Observer")
                        .font(.caption2)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(.systemGray6))
                .clipShape(Capsule())
            }
        }
    }

    // MARK: - Helpers

    private func formatTime(_ seconds: Double) -> String {
        let total = Int(max(seconds, 0))
        let m = total / 60
        let s = total % 60
        return String(format: "%d:%02d", m, s)
    }
}
