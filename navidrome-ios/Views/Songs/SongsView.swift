import SwiftUI

struct SongsView: View {
    @EnvironmentObject private var store: SyncStore
    @State private var songs: [Song] = []
    @State private var isLoading = false
    @State private var fullyLoaded = false
    @State private var selectedLetter: String?

    private let pageSize = 50

    private var groupedSongs: [(letter: String, songs: [Song])] {
        let grouped = Dictionary(grouping: songs) { song -> String in
            let first = song.title.prefix(1).uppercased()
            return first.first?.isLetter == true ? first : "#"
        }
        return grouped.sorted { $0.key < $1.key }.map { (letter: $0.key, songs: $0.value) }
    }

    private var availableLetters: [String] {
        groupedSongs.map(\.letter)
    }

    var body: some View {
        HStack(spacing: 0) {
            ScrollViewReader { proxy in
                List {
                    ForEach(groupedSongs, id: \.letter) { group in
                        Section(header: Text(group.letter).id(group.letter)) {
                            ForEach(group.songs) { song in
                                Button { playSong(song) } label: {
                                    songRow(song)
                                }
                                .listRowBackground(Color.clear)
                            }
                        }
                    }

                    if isLoading {
                        HStack {
                            Spacer()
                            ProgressView()
                            Spacer()
                        }
                        .listRowSeparator(.hidden)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .onChange(of: selectedLetter) { _, newValue in
                    if let letter = newValue {
                        withAnimation {
                            proxy.scrollTo(letter, anchor: .top)
                        }
                    }
                }
            }

            if !availableLetters.isEmpty {
                AlphabetScrubber(letters: availableLetters, selectedLetter: $selectedLetter)
            }
        }
        .background { store.dominantBackgroundColor.ignoresSafeArea() }
        .navigationTitle("Songs")
        .task {
            await loadAllSongs()
        }
    }

    private func songRow(_ song: Song) -> some View {
        HStack(spacing: 12) {
            CoverArtImage(id: song.coverArt, size: 80)
                .frame(width: 40, height: 40)
                .clipShape(RoundedRectangle(cornerRadius: 4))
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
            Text(formatDuration(song.duration))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func playSong(_ song: Song) {
        store.playSong(song.toNowPlayingSong())
    }

    private func loadAllSongs() async {
        guard songs.isEmpty else { return }
        isLoading = true
        var offset = 0
        while !fullyLoaded {
            do {
                let page = try await NavidromeClient.shared.getSongs(offset: offset, count: pageSize)
                songs.append(contentsOf: page)
                if page.count < pageSize {
                    fullyLoaded = true
                } else {
                    offset += pageSize
                }
            } catch {
                print("[songs] failed to load page at offset \(offset): \(error)")
                break
            }
        }
        isLoading = false
    }

    private func formatDuration(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%d:%02d", m, s)
    }
}
