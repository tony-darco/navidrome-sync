import SwiftUI

// MARK: - LibraryView

struct LibraryView: View {
    @EnvironmentObject private var store: SyncStore
    @Environment(AppNavigationState.self) private var nav
    @Environment(CrateColorState.self) private var crateState

    @State private var showGenres   = false
    @State private var showDownloads = false

    // Section counts (loaded on appear)
    @State private var albumCount:    Int = 0
    @State private var songCount:     Int = 0
    @State private var artistCount:   Int = 0
    @State private var playlistCount: Int = 0

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .bottomLeading) {
                VStack(spacing: 0) {
                    graphicZone(height: geo.size.height * 0.55)
                    bodyZone(height:   geo.size.height * 0.45)
                }

                NavPopoverView(
                    isVisible: Binding(
                        get: { nav.isPopoverVisible },
                        set: { nav.isPopoverVisible = $0 }
                    ),
                    crate: crateState.current,
                    onNavigate: { nav.handlePopoverSelection($0) }
                )
            }
        }
        .ignoresSafeArea()
        .fullScreenCover(isPresented: $showGenres) {
            NavigationStack { GenresView() }
                .environmentObject(store)
        }
        .fullScreenCover(isPresented: $showDownloads) {
            NavigationStack { DownloadsView() }
                .environmentObject(store)
        }
        .task { await loadCounts() }
    }

    // MARK: - Graphic zone (top 55%)

    @ViewBuilder
    private func graphicZone(height: CGFloat) -> some View {
        ZStack {
            // Dark crate artBg
            Rectangle().fill(crateState.current.artBg)

            // Vinyl texture watermark at 8% opacity
            VinylFallbackView(crate: crateState.current, size: height)
                .opacity(0.08)
                .allowsHitTesting(false)

            // Section bands + mini strip pushed to bottom
            VStack(spacing: 0) {
                Spacer(minLength: 0)

                sectionBand(icon: "square.stack",    label: "Albums",    count: albumCount,    dest: .albums)
                Divider().background(DesignBorder.onDark)
                sectionBand(icon: "music.note.list", label: "Playlists", count: playlistCount, dest: .playlists)
                Divider().background(DesignBorder.onDark)
                sectionBand(icon: "music.mic",       label: "Artists",   count: artistCount,   dest: .artists)
                Divider().background(DesignBorder.onDark)
                sectionBand(icon: "music.note",      label: "Songs",     count: songCount,     dest: .songs)
                Divider().background(DesignBorder.onDark)
                secondaryBand(icon: "guitars",             label: "Genres")    { showGenres    = true }
                Divider().background(DesignBorder.onDark)
                secondaryBand(icon: "arrow.down.circle",  label: "Downloads") { showDownloads = true }

                MiniTrackStripView(onTap: { nav.navigate(to: .nowPlaying) })
                    .environmentObject(store)
            }
        }
        .frame(height: height)
    }

    // MARK: - Section band (primary nav row)

    private func sectionBand(icon: String, label: String, count: Int, dest: AppView) -> some View {
        Button { nav.navigate(to: dest) } label: {
            HStack(spacing: DesignSpacing.md) {
                ZStack {
                    RoundedRectangle(cornerRadius: DesignRadius.sm)
                        .fill(crateState.current.outer)
                        .frame(width: 30, height: 30)
                    Image(systemName: icon)
                        .font(.system(size: 14))
                        .foregroundStyle(crateState.current.accent)
                }

                Text(label)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(DesignText.onDark)

                Spacer()

                if count > 0 {
                    Text("\(count)")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(DesignText.onDarkMuted)
                }

                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(DesignText.onDarkMuted)
            }
            .padding(.horizontal, DesignSpacing.lg)
            .frame(height: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Secondary band (Genres / Downloads)

    private func secondaryBand(icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: DesignSpacing.md) {
                ZStack {
                    RoundedRectangle(cornerRadius: DesignRadius.sm)
                        .fill(crateState.current.outer)
                        .frame(width: 30, height: 30)
                    Image(systemName: icon)
                        .font(.system(size: 14))
                        .foregroundStyle(crateState.current.accent)
                }

                Text(label)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(DesignText.onDark)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(DesignText.onDarkMuted)
            }
            .padding(.horizontal, DesignSpacing.lg)
            .frame(height: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Body zone (bottom 45%)

    @ViewBuilder
    private func bodyZone(height: CGFloat) -> some View {
        ZStack(alignment: .bottom) {
            Rectangle().fill(crateState.current.device)

            VStack(spacing: DesignSpacing.md) {
                Spacer(minLength: DesignSpacing.lg)

                ClickWheelView(
                    crate:       crateState.current,
                    onCenterTap: {
                        if store.isPlaying { store.pause() } else { store.play() }
                    },
                    onTopTap:    { },
                    onBottomTap: { },
                    onLeftTap:   { store.prev() },
                    onRightTap:  { store.next() },
                    onScrub: { fraction in
                        guard let song = store.nowPlaying else { return }
                        store.seek(to: fraction * Double(song.durationSecs))
                    }
                )

                navDots

                Spacer(minLength: DesignSpacing.xxl)
            }

            bottomBar
        }
        .frame(height: height)
    }

    // MARK: - Nav dots (Library = active)

    private var navDots: some View {
        // 5 dots: nowPlaying, library, albums, search, settings
        let items: [(AppView, Int)] = [
            (.nowPlaying, 0), (.library, 1), (.albums, 2), (.search, 3), (.settings, 4)
        ]
        return HStack(spacing: 5) {
            ForEach(items, id: \.0) { view, idx in
                let isActive = view == .library
                Circle()
                    .fill(getCrateColor(albumId: String(idx)).dot)
                    .opacity(isActive ? 1.0 : 0.5)
                    .frame(width: isActive ? 9 : 6, height: isActive ? 9 : 6)
            }
        }
    }

    // MARK: - Bottom bar

    private var bottomBar: some View {
        HStack {
            Button { nav.isPopoverVisible = true } label: {
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(crateState.current.text)
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.plain)

            Spacer()

            Text("navidrome-sync")
                .font(.system(size: 11, weight: .semibold))
                .tracking(DesignType.tracking(from: DesignType.sectionLabel))
                .textCase(.uppercase)
                .foregroundStyle(crateState.current.text)
        }
        .padding(.horizontal, DesignSpacing.lg)
        .padding(.bottom, DesignSpacing.md)
    }

    // MARK: - Count loading

    private func loadCounts() async {
        async let al = try? NavidromeClient.shared.getAlbums(type: "alphabeticalByName", size: 500)
        async let ar = try? NavidromeClient.shared.getArtists()
        async let so = try? NavidromeClient.shared.getSongs(count: 500)
        async let pl = try? NavidromeClient.shared.getPlaylists()

        albumCount    = (await al)?.count ?? 0
        artistCount   = (await ar)?.flatMap(\.artist).count ?? 0
        songCount     = (await so)?.count ?? 0
        playlistCount = (await pl)?.count ?? 0
    }
}

// MARK: - Album Hashable (required for NavigationLink value in detail views)

extension Album: Hashable {
    static func == (lhs: Album, rhs: Album) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}
