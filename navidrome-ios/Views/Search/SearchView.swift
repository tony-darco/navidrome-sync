import SwiftUI

struct SearchView: View {
    @EnvironmentObject private var store: SyncStore
    @Environment(AppNavigationState.self) private var nav
    @Environment(CrateColorState.self) private var crateState

    @State private var query       = ""
    @State private var albums: [Album] = []
    @State private var songs: [Song]   = []
    @State private var isSearching     = false
    @State private var hasSearched     = false
    @FocusState private var fieldFocused: Bool

    var body: some View {
        @Bindable var nav = nav

        NavigationStack(path: $nav.searchPath) {
            ZStack(alignment: .bottomLeading) {
                DesignBg.cream.ignoresSafeArea()

                VStack(spacing: 0) {
                    // Header + search bar
                    VStack(alignment: .leading, spacing: DesignSpacing.md) {
                        Text("Search")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundStyle(DesignText.primary)

                        searchBar
                    }
                    .padding(.horizontal, DesignSpacing.lg)
                    .padding(.top, 60)
                    .padding(.bottom, DesignSpacing.md)

                    // Results
                    ScrollView {
                        if hasSearched && albums.isEmpty && songs.isEmpty && !isSearching {
                            VStack(spacing: DesignSpacing.md) {
                                Image(systemName: "magnifyingglass")
                                    .font(.system(size: 36))
                                    .foregroundStyle(DesignText.tertiary)
                                Text("No results for \"\(query)\"")
                                    .font(.system(size: 15))
                                    .foregroundStyle(DesignText.secondary)
                            }
                            .padding(.top, 60)
                        } else if !hasSearched {
                            VStack(spacing: DesignSpacing.md) {
                                Image(systemName: "magnifyingglass")
                                    .font(.system(size: 36))
                                    .foregroundStyle(DesignText.tertiary)
                                Text("Search albums and songs")
                                    .font(.system(size: 15))
                                    .foregroundStyle(DesignText.secondary)
                            }
                            .padding(.top, 60)
                        } else {
                            resultSections
                        }
                    }
                    .safeAreaInset(edge: .bottom) { Color.clear.frame(height: 110) }
                }

                // Mini player + bottom nav
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
            .navigationDestination(for: Album.self) { album in
                AlbumDetailView(albumId: album.id)
            }
        }
        .onChange(of: query) { _, newValue in
            if newValue.isEmpty { albums = []; songs = []; hasSearched = false }
        }
    }

    // MARK: - Search bar

    private var searchBar: some View {
        HStack(spacing: DesignSpacing.sm) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14))
                .foregroundStyle(DesignText.secondary)

            TextField("Albums, songs...", text: $query)
                .font(.system(size: 15))
                .foregroundStyle(DesignText.primary)
                .tint(crateState.current.accent)
                .focused($fieldFocused)
                .onSubmit { Task { await performSearch() } }
                .submitLabel(.search)

            if !query.isEmpty {
                Button { query = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(DesignText.tertiary)
                }
                .buttonStyle(.plain)
            }

            if isSearching {
                ProgressView().scaleEffect(0.7)
            }
        }
        .padding(.horizontal, DesignSpacing.md)
        .padding(.vertical, DesignSpacing.sm)
        .background(Color.black.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: DesignRadius.pill))
    }

    // MARK: - Result sections

    @ViewBuilder
    private var resultSections: some View {
        VStack(alignment: .leading, spacing: 0) {
            if !albums.isEmpty {
                // Albums section header
                sectionHeader(label: "Albums", count: albums.count)

                // Horizontal scroll strip of 80×80 chips
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: DesignSpacing.md) {
                        ForEach(albums) { album in
                            Button {
                                nav.searchPath.append(album)
                            } label: {
                                albumChip(album)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, DesignSpacing.lg)
                    .padding(.vertical, DesignSpacing.sm)
                }
                .padding(.bottom, DesignSpacing.md)
            }

            if !songs.isEmpty {
                sectionHeader(label: "Songs", count: songs.count)

                VStack(spacing: 0) {
                    ForEach(songs) { song in
                        Button { store.playSong(song.toNowPlayingSong()) } label: {
                            songRow(song)
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, DesignSpacing.lg)

                        Divider()
                            .padding(.leading, DesignSpacing.lg + DesignDim.thumbMd + DesignSpacing.md)
                    }
                }
            }
        }
    }

    // MARK: - Album chip (80×80)

    private func albumChip(_ album: Album) -> some View {
        VStack(alignment: .leading, spacing: DesignSpacing.xs) {
            CoverArtImage(id: album.coverArt, size: 160)
                .frame(width: DesignDim.albumChipSize, height: DesignDim.albumChipSize)
                .clipShape(RoundedRectangle(cornerRadius: DesignRadius.md))

            Text(album.name)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(DesignText.primary)
                .lineLimit(1)
                .frame(width: DesignDim.albumChipSize, alignment: .leading)

            Text(album.artist)
                .font(.system(size: 10))
                .foregroundStyle(DesignText.secondary)
                .lineLimit(1)
                .frame(width: DesignDim.albumChipSize, alignment: .leading)
        }
    }

    // MARK: - Song row (36×36 square art)

    private func songRow(_ song: Song) -> some View {
        HStack(spacing: DesignSpacing.md) {
            CoverArtImage(id: song.coverArt, size: 80)
                .frame(width: DesignDim.thumbMd, height: DesignDim.thumbMd)
                .clipShape(RoundedRectangle(cornerRadius: DesignRadius.sm))

            VStack(alignment: .leading, spacing: 2) {
                Text(song.title)
                    .font(.system(size: DesignType.rowTitle.size, weight: DesignType.rowTitle.weight))
                    .foregroundStyle(DesignText.primary)
                    .lineLimit(1)
                Text("\(song.artist) · \(song.album)")
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

    // MARK: - Section header

    private func sectionHeader(label: String, count: Int) -> some View {
        HStack {
            Text(label)
                .font(.system(size: DesignType.sectionLabel.size,
                              weight: DesignType.sectionLabel.weight))
                .tracking(DesignType.tracking(from: DesignType.sectionLabel))
                .textCase(.uppercase)
                .foregroundStyle(DesignText.secondary)
            Spacer()
            Text("\(count)")
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(DesignText.tertiary)
        }
        .padding(.horizontal, DesignSpacing.lg)
        .padding(.top, DesignSpacing.lg)
        .padding(.bottom, DesignSpacing.xs)
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

    // MARK: - Search

    private func performSearch() async {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        isSearching = true
        hasSearched = true
        defer { isSearching = false }
        do {
            let result = try await NavidromeClient.shared.search(query: trimmed)
            albums = result.albums
            songs  = result.songs
        } catch {
            print("[search] error: \(error)")
        }
    }
}
