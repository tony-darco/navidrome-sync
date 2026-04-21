import SwiftUI

struct PlaylistEditView: View {
    let playlistId: String
    let onDismiss: () -> Void

    @EnvironmentObject private var store: SyncStore
    @EnvironmentObject private var playlistStore: PlaylistStore
    @State private var tracks: [Song] = []
    @State private var playlistName = ""
    @State private var pendingAdds: Set<String> = []
    @State private var pendingRemoves: Set<Int> = []
    @State private var isLoading = true
    @State private var isSaving = false
    @State private var searchQuery = ""
    @State private var searchResults: [Song] = []
    @State private var searchTask: Task<Void, Never>?

    private var originalTrackCount: Int {
        tracks.count - pendingAdds.count
    }

    var body: some View {
        VStack(spacing: 0) {
            // Search bar for adding songs
            VStack(spacing: 8) {
                TextField("Search songs to add…", text: $searchQuery)
                    .textFieldStyle(.roundedBorder)
                    .padding(.horizontal)
                    .onChange(of: searchQuery) { _, newValue in
                        debounceSearch(newValue)
                    }

                if !searchResults.isEmpty {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(searchResults) { song in
                                Button {
                                    addSong(song)
                                } label: {
                                    HStack(spacing: 8) {
                                        Image(systemName: "plus.circle.fill")
                                            .foregroundStyle(.green)
                                        Text(song.title)
                                            .font(.subheadline)
                                            .lineLimit(1)
                                        Spacer()
                                        Text(song.artist)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(1)
                                    }
                                    .padding(.horizontal)
                                    .padding(.vertical, 8)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .disabled(pendingAdds.contains(song.id))
                            }
                        }
                    }
                    .frame(maxHeight: 200)
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .padding(.horizontal)
                }
            }
            .padding(.vertical, 8)

            Divider()

            // Current track list
            if isLoading {
                Spacer()
                ProgressView()
                Spacer()
            } else {
                List {
                    ForEach(Array(tracks.enumerated()), id: \.offset) { index, song in
                        HStack(spacing: 12) {
                            CoverArtImage(id: song.coverArt, size: 80,
                                          isNowPlaying: song.id == store.nowPlaying?.songId,
                                          isPlaying: store.isPlaying)
                                .frame(width: 36, height: 36)
                                .clipShape(RoundedRectangle(cornerRadius: 4))
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
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                removeTrack(at: index)
                            } label: {
                                Label("Remove", systemImage: "trash")
                            }
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("Edit \"\(playlistName)\"")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { onDismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    Task { await save() }
                }
                .disabled(isSaving || (pendingAdds.isEmpty && pendingRemoves.isEmpty))
            }
        }
        .task {
            await loadPlaylist()
        }
    }

    private func addSong(_ song: Song) {
        pendingAdds.insert(song.id)
        tracks.append(song)
        searchQuery = ""
        searchResults = []
    }

    private func removeTrack(at index: Int) {
        let song = tracks[index]
        if pendingAdds.contains(song.id) {
            pendingAdds.remove(song.id)
        } else {
            pendingRemoves.insert(index)
        }
        tracks.remove(at: index)
    }

    private func save() async {
        isSaving = true
        do {
            try await NavidromeClient.shared.updatePlaylist(
                playlistId: playlistId,
                songIdsToAdd: Array(pendingAdds),
                songIndexesToRemove: Array(pendingRemoves)
            )
            playlistStore.notifyChanged(playlistId: playlistId, action: "updated")
            onDismiss()
        } catch {
            print("[playlist edit] save failed: \(error)")
        }
        isSaving = false
    }

    private func loadPlaylist() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let data = try await NavidromeClient.shared.getPlaylist(id: playlistId)
            playlistName = data.name
            tracks = data.entry ?? []
        } catch {
            print("[playlist edit] failed to load: \(error)")
        }
    }

    private func debounceSearch(_ query: String) {
        searchTask?.cancel()
        guard !query.isEmpty else {
            searchResults = []
            return
        }
        searchTask = Task {
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            do {
                let results = try await NavidromeClient.shared.search(query: query)
                guard !Task.isCancelled else { return }
                searchResults = results.songs
            } catch {
                print("[playlist edit] search error: \(error)")
            }
        }
    }
}
