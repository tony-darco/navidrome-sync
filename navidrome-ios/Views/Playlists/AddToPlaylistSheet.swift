import SwiftUI

struct AddToPlaylistSheet: View {
    let songId: String
    @EnvironmentObject private var playlistStore: PlaylistStore
    @Environment(\.dismiss) private var dismiss
    @State private var isAdding: String?
    @State private var added: Set<String> = []
    @State private var showCreate = false

    var body: some View {
        NavigationStack {
            List {
                if playlistStore.playlists.isEmpty && !playlistStore.isLoading {
                    Text("No playlists yet")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(playlistStore.playlists) { playlist in
                        Button {
                            Task { await addSong(to: playlist) }
                        } label: {
                            HStack(spacing: 12) {
                                CoverArtImage(id: playlist.coverArt, size: 80)
                                    .frame(width: 44, height: 44)
                                    .clipShape(RoundedRectangle(cornerRadius: 6))

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(playlist.name)
                                        .font(.body)
                                        .foregroundStyle(.primary)
                                    Text("\(playlist.songCount) songs")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                if added.contains(playlist.id) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.green)
                                } else if isAdding == playlist.id {
                                    ProgressView()
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        .disabled(isAdding != nil)
                    }
                }
            }
            .listStyle(.plain)
            .navigationTitle("Add to Playlist")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showCreate = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .task {
                if playlistStore.playlists.isEmpty {
                    await playlistStore.fetchPlaylists()
                }
            }
            .sheet(isPresented: $showCreate) {
                PlaylistCreateSheet()
                    .environmentObject(playlistStore)
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func addSong(to playlist: Playlist) async {
        isAdding = playlist.id
        defer { isAdding = nil }
        do {
            try await NavidromeClient.shared.updatePlaylist(
                playlistId: playlist.id,
                songIdsToAdd: [songId]
            )
            added.insert(playlist.id)
            playlistStore.notifyChanged(playlistId: playlist.id, action: "updated")
        } catch {
            print("[add-to-playlist] error: \(error)")
        }
    }
}
