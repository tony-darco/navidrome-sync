import SwiftUI

struct ArtistsView: View {
    @EnvironmentObject private var store: SyncStore
    @State private var artists: [ArtistID3] = []
    @State private var isLoading = false
    @State private var selectedLetter: String?

    private var groupedArtists: [(letter: String, artists: [ArtistID3])] {
        let grouped = Dictionary(grouping: artists) { artist -> String in
            let first = artist.name.prefix(1).uppercased()
            return first.first?.isLetter == true ? first : "#"
        }
        return grouped.sorted { lhs, rhs in
            if lhs.key == "#" { return true }
            if rhs.key == "#" { return false }
            return lhs.key < rhs.key
        }.map { (letter: $0.key, artists: $0.value) }
    }

    private var availableLetters: [String] {
        groupedArtists.map(\.letter)
    }

    var body: some View {
        HStack(spacing: 0) {
            ScrollViewReader { proxy in
                List {
                    ForEach(groupedArtists, id: \.letter) { group in
                        Section(header: Text(group.letter).id(group.letter)) {
                            ForEach(group.artists) { artist in
                                NavigationLink(value: artist) {
                                    ArtistRowView(artist: artist)
                                }
                                .listRowBackground(Color.clear)
                                .listRowInsets(EdgeInsets())
                                .listRowSeparator(.hidden)
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
                .miniPlayerScrollObserver()
                .onChange(of: selectedLetter) { _, newValue in
                    if let letter = newValue {
                        withAnimation {
                            proxy.scrollTo(letter, anchor: .top)
                        }
                    }
                }
                .overlay {
                    if !isLoading && artists.isEmpty {
                        ContentUnavailableView(
                            "No Artists",
                            systemImage: "music.mic"
                        )
                    }
                }
            }

            if !availableLetters.isEmpty {
                AlphabetScrubber(
                    letters: availableLetters,
                    activeLetters: Set(availableLetters),
                    selectedLetter: $selectedLetter
                )
            }
        }
        .background { store.dominantBackgroundColor.ignoresSafeArea() }
        .navigationTitle("Artists")
        .task {
            await loadArtists()
        }
    }

    private func loadArtists() async {
        guard artists.isEmpty else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let indexes = try await NavidromeClient.shared.getArtists()
            artists = indexes.flatMap(\.artist)
        } catch {
            print("[artists] failed to load: \(error)")
        }
    }
}
