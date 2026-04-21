import SwiftUI

struct ArtistsView: View {
    @EnvironmentObject private var store: SyncStore
    @Environment(AppNavigationState.self) private var nav
    @Environment(CrateColorState.self) private var crateState

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

    private var availableLetters: [String] { groupedArtists.map(\.letter) }

    var body: some View {
        @Bindable var nav = nav

        NavigationStack(path: $nav.artistsPath) {
            ZStack(alignment: .bottomLeading) {
                DesignBg.cream.ignoresSafeArea()

                VStack(spacing: 0) {
                    // Header
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Artists")
                                .font(.system(size: 28, weight: .bold))
                                .foregroundStyle(DesignText.primary)
                            if !artists.isEmpty {
                                Text("\(artists.count) artists")
                                    .font(.system(size: 11, weight: .semibold))
                                    .tracking(DesignType.tracking(from: DesignType.sectionLabel))
                                    .textCase(.uppercase)
                                    .foregroundStyle(DesignText.secondary)
                            }
                        }
                        Spacer()
                    }
                    .padding(.horizontal, DesignSpacing.lg)
                    .padding(.top, 60)
                    .padding(.bottom, DesignSpacing.md)

                    HStack(spacing: 0) {
                        ScrollViewReader { proxy in
                            List {
                                ForEach(groupedArtists, id: \.letter) { group in
                                    Section {
                                        ForEach(group.artists) { artist in
                                            Button {
                                                nav.artistsPath.append(artist)
                                            } label: {
                                                artistRow(artist)
                                            }
                                            .buttonStyle(.plain)
                                            .listRowBackground(
                                                RoundedRectangle(cornerRadius: DesignRadius.md)
                                                    .fill(DesignBg.cream)
                                            )
                                            .listRowSeparatorTint(DesignBorder.subtle)
                                        }
                                    } header: {
                                        Text(group.letter)
                                            .font(.system(size: DesignType.sectionLabel.size,
                                                          weight: DesignType.sectionLabel.weight))
                                            .tracking(DesignType.tracking(from: DesignType.sectionLabel))
                                            .textCase(.uppercase)
                                            .foregroundStyle(DesignText.tertiary)
                                            .id(group.letter)
                                    }
                                }

                                if isLoading {
                                    HStack { Spacer(); ProgressView(); Spacer() }
                                        .listRowSeparator(.hidden)
                                        .listRowBackground(Color.clear)
                                }
                            }
                            .listStyle(.plain)
                            .scrollContentBackground(.hidden)
                            .background(DesignBg.cream)
                            .onChange(of: selectedLetter) { _, newValue in
                                if let letter = newValue {
                                    withAnimation { proxy.scrollTo(letter, anchor: .top) }
                                }
                            }
                            .overlay {
                                if !isLoading && artists.isEmpty {
                                    ContentUnavailableView("No Artists", systemImage: "music.mic")
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
                    .safeAreaInset(edge: .bottom) { Color.clear.frame(height: 110) }
                }

                VStack(spacing: 0) {
                    MiniPlayerView(
                        crate: crateState.current,
                        onTapToNowPlaying: { nav.navigate(to: .nowPlaying) }
                    )
                    .environmentObject(store)

                    bottomNav
                }
                .frame(maxWidth: .infinity)

                NavPopoverView(
                    isVisible: Binding(
                        get: { nav.isPopoverVisible },
                        set: { nav.isPopoverVisible = $0 }
                    ),
                    crate: crateState.current,
                    onNavigate: { nav.handlePopoverSelection($0) }
                )
            }
            .navigationDestination(for: ArtistID3.self) { artist in
                ArtistDetailView(artistId: artist.id, artistName: artist.name)
            }
        }
        .task { await loadArtists() }
    }

    // MARK: - Artist row (58pt)

    private func artistRow(_ artist: ArtistID3) -> some View {
        HStack(spacing: DesignSpacing.md) {
            // Circle avatar — tries artist art, falls back to initials
            ZStack {
                Circle()
                    .fill(getCrateColor(albumId: artist.id).outer)
                Text(initials(artist.name))
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(getCrateColor(albumId: artist.id).accent)
                CoverArtImage(id: artist.id, size: 80)
                    .clipShape(Circle())
            }
            .frame(width: DesignDim.thumbMd, height: DesignDim.thumbMd)

            VStack(alignment: .leading, spacing: 2) {
                Text(artist.name)
                    .font(.system(size: DesignType.rowTitle.size, weight: DesignType.rowTitle.weight))
                    .foregroundStyle(DesignText.primary)
                    .lineLimit(1)
                Text("\(artist.albumCount) albums")
                    .font(.system(size: DesignType.rowSub.size))
                    .foregroundStyle(DesignText.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(DesignText.tertiary)
        }
        .frame(height: DesignDim.listRowHeight)
        .contentShape(Rectangle())
    }

    // MARK: - Bottom nav

    private var bottomNav: some View {
        HStack {
            Button { nav.isPopoverVisible = true } label: {
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(DesignText.secondary)
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.plain)
            Spacer()
            Text("navidrome-sync")
                .font(.system(size: 11, weight: .semibold))
                .tracking(DesignType.tracking(from: DesignType.sectionLabel))
                .textCase(.uppercase)
                .foregroundStyle(DesignText.secondary)
        }
        .padding(.horizontal, DesignSpacing.lg)
        .padding(.vertical, DesignSpacing.md)
        .background(DesignBg.cream)
    }

    // MARK: - Data loading

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

    private func initials(_ name: String) -> String {
        let words = name.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
        if words.isEmpty { return "?" }
        if words.count == 1 { return String(words[0].prefix(2)).uppercased() }
        return (String(words[0].prefix(1)) + String(words[1].prefix(1))).uppercased()
    }
}
