import SwiftUI

// MARK: - PlaylistsView

struct PlaylistsView: View {
    @EnvironmentObject private var store: SyncStore
    @EnvironmentObject private var playlistStore: PlaylistStore
    @Environment(AppNavigationState.self) private var nav
    @Environment(CrateColorState.self) private var crateState

    @State private var showCreateSheet = false

    private let columns = [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)]

    var body: some View {
        @Bindable var nav = nav

        NavigationStack(path: $nav.playlistsPath) {
            ZStack(alignment: .bottomLeading) {
                DesignBg.cream.ignoresSafeArea()

                VStack(spacing: 0) {
                    topBar

                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 16) {
                            ForEach(playlistStore.playlists) { playlist in
                                Button {
                                    nav.playlistsPath.append(playlist)
                                } label: {
                                    PlaylistCardView(playlist: playlist)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, DesignSpacing.lg)
                        .padding(.top, DesignSpacing.md)
                        .padding(.bottom, 140)
                    }
                    .overlay {
                        if playlistStore.isLoading && playlistStore.playlists.isEmpty {
                            ProgressView()
                        } else if !playlistStore.isLoading && playlistStore.playlists.isEmpty {
                            ContentUnavailableView(
                                "No Playlists",
                                systemImage: "music.note.list",
                                description: Text("Tap + to create one.")
                            )
                        }
                    }
                }

                // Mini player + bottom nav stacked at bottom
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
            .navigationDestination(for: Playlist.self) { playlist in
                PlaylistDetailView(playlistId: playlist.id, playlistName: playlist.name)
            }
        }
        .sheet(isPresented: $showCreateSheet) {
            PlaylistCreateSheet()
        }
        .task { await playlistStore.fetchPlaylists() }
    }

    // MARK: - Top bar

    private var topBar: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Playlists")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(DesignText.primary)
                if !playlistStore.playlists.isEmpty {
                    Text("\(playlistStore.playlists.count) playlists")
                        .font(.system(size: 11, weight: .semibold))
                        .tracking(DesignType.tracking(from: DesignType.sectionLabel))
                        .textCase(.uppercase)
                        .foregroundStyle(DesignText.secondary)
                }
            }

            Spacer()

            Button { showCreateSheet = true } label: {
                Image(systemName: "plus")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(DesignText.primary)
                    .frame(width: 32, height: 32)
                    .background(DesignBg.creamHover)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, DesignSpacing.lg)
        .padding(.top, 60)
        .padding(.bottom, DesignSpacing.md)
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
}

// MARK: - PlaylistCardView

struct PlaylistCardView: View {
    let playlist: Playlist

    private var crate: CrateColorSet { getCrateColor(albumId: playlist.id) }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSpacing.xs) {
            artSection
                .aspectRatio(1, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: DesignRadius.lg))

            Text(playlist.name)
                .font(.system(size: DesignType.rowTitle.size, weight: DesignType.rowTitle.weight))
                .foregroundStyle(DesignText.primary)
                .lineLimit(1)

            Text("\(playlist.songCount) songs")
                .font(.system(size: DesignType.rowSub.size))
                .foregroundStyle(DesignText.secondary)
        }
    }

    @ViewBuilder
    private var artSection: some View {
        if playlist.coverArt.isEmpty {
            ZStack {
                RoundedRectangle(cornerRadius: DesignRadius.lg).fill(crate.device)
                VinylFallbackView(crate: crate, size: 140)
            }
        } else {
            // 2×2 quad grid using playlist's cover art
            Grid(horizontalSpacing: 2, verticalSpacing: 2) {
                GridRow {
                    CoverArtImage(id: playlist.coverArt, size: 150)
                        .scaledToFill()
                        .clipped()
                    CoverArtImage(id: playlist.coverArt, size: 150)
                        .scaledToFill()
                        .clipped()
                }
                GridRow {
                    CoverArtImage(id: playlist.coverArt, size: 150)
                        .scaledToFill()
                        .clipped()
                    CoverArtImage(id: playlist.coverArt, size: 150)
                        .scaledToFill()
                        .clipped()
                }
            }
        }
    }
}
