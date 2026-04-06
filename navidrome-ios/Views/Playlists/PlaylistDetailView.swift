import SwiftUI

struct PlaylistDetailView: View {
    let playlistId: String
    let playlistName: String

    @EnvironmentObject private var store: SyncStore
    @EnvironmentObject private var playlistStore: PlaylistStore
    @State private var playlist: PlaylistWithSongs?
    @State private var isLoading = true
    @State private var showEditView = false
    @State private var showDeleteAlert = false

    var body: some View {
        ScrollView {
            if isLoading {
                ProgressView()
                    .padding(.top, 60)
            } else if let playlist {
                VStack(spacing: 20) {
                    playlistHeader(playlist)
                    trackList(playlist)
                }
                .padding()
            }
        }
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
        }
    }

    private func playlistHeader(_ playlist: PlaylistWithSongs) -> some View {
        VStack(spacing: 12) {
            if !playlist.coverArt.isEmpty {
                CoverArtImage(id: playlist.coverArt, size: 600)
                    .frame(width: 200, height: 200)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .shadow(radius: 8)
            }
            Text(playlist.name)
                .font(.title2)
                .fontWeight(.bold)
            Text("\(playlist.songCount) tracks")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Button {
                playAll(playlist)
            } label: {
                Label("Play All", systemImage: "play.fill")
                    .font(.headline)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 10)
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private func trackList(_ playlist: PlaylistWithSongs) -> some View {
        VStack(spacing: 0) {
            let entries = playlist.entry ?? []
            ForEach(Array(entries.enumerated()), id: \.element.id) { index, song in
                Button { playTrack(at: index, in: entries) } label: {
                    HStack(spacing: 12) {
                        Text("\(index + 1)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .frame(width: 24, alignment: .trailing)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(song.title)
                                .font(.subheadline)
                                .lineLimit(1)
                            Text(song.artist)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        Spacer()
                        Text(formatDuration(song.duration))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 10)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                if index < entries.count - 1 {
                    Divider().padding(.leading, 36)
                }
            }
        }
    }

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

    private func formatDuration(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%d:%02d", m, s)
    }
}
