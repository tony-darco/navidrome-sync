import SwiftUI

struct ArtistsView: View {
    @EnvironmentObject private var store: SyncStore
    @State private var artistIndexes: [ArtistIndex] = []
    @State private var isLoading = false
    @State private var selectedLetter: String?

    private var availableLetters: [String] {
        artistIndexes.map(\.name)
    }

    var body: some View {
        HStack(spacing: 0) {
            ScrollViewReader { proxy in
                List {
                    ForEach(artistIndexes) { index in
                        Section(header: Text(index.name).id(index.name)) {
                            ForEach(index.artist) { artist in
                                NavigationLink(value: artist) {
                                    ArtistRowView(artist: artist)
                                }
                                .listRowBackground(Color.clear)
                            }
                        }
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
        .navigationTitle("Artists")
        .navigationDestination(for: ArtistID3.self) { artist in
            ArtistDetailView(artistId: artist.id, artistName: artist.name)
        }
        .overlay {
            if isLoading && artistIndexes.isEmpty {
                ProgressView()
            }
        }
        .task {
            await loadArtists()
        }
    }

    private func loadArtists() async {
        guard artistIndexes.isEmpty else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            artistIndexes = try await NavidromeClient.shared.getArtists()
        } catch {
            print("[artists] failed to load: \(error)")
        }
    }
}
