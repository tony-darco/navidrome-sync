import SwiftUI

// MARK: - Sort order

enum AlbumSortOrder: String, CaseIterable {
    case alphabeticalByName
    case alphabeticalByArtist
    case newest
    case byYear
    case mostPlayed = "frequent"
    case recentlyPlayed = "recent"
    case random

    var label: String {
        switch self {
        case .alphabeticalByName:  "Album A→Z"
        case .alphabeticalByArtist:"Artist A→Z"
        case .newest:              "Recently Added"
        case .byYear:              "Year"
        case .mostPlayed:          "Most Played"
        case .recentlyPlayed:      "Recently Played"
        case .random:              "Random"
        }
    }

    var icon: String {
        switch self {
        case .alphabeticalByName:  "textformat.abc"
        case .alphabeticalByArtist:"person"
        case .newest:              "sparkles"
        case .byYear:              "calendar"
        case .mostPlayed:          "chart.bar"
        case .recentlyPlayed:      "clock"
        case .random:              "shuffle"
        }
    }
}

// MARK: - AlbumsView

struct AlbumsView: View {
    @EnvironmentObject private var store: SyncStore
    @EnvironmentObject private var musicStore: MusicLibraryStore
    @Environment(AppNavigationState.self) private var nav
    @Environment(CrateColorState.self) private var crateState

    @State private var sortOrder: AlbumSortOrder = .alphabeticalByName
    @State private var focusIndex: Int  = 0
    @State private var dragOffset: CGFloat = 0
    @State private var showSortMenu: Bool  = false

    private var albums: [Album] {
        musicStore.albumListStates[sortOrder]?.albums ?? []
    }

    /// Fractional focus position during drag (negative drag = forward through list)
    private var fractionalFocus: Double {
        Double(focusIndex) - Double(dragOffset) / Double(DesignCoverFlow.spacing)
    }

    var body: some View {
        @Bindable var nav = nav

        NavigationStack(path: $nav.albumsPath) {
            GeometryReader { geo in
                ZStack {
                    Color(hex: "#0A0A0A").ignoresSafeArea()

                    if albums.isEmpty {
                        emptyState
                    } else {
                        coverFlow(geo: geo)
                    }

                    topBar
                    bottomNav
                }
            }
            .ignoresSafeArea()
            .navigationDestination(for: Album.self) { album in
                AlbumDetailView(albumId: album.id)
            }
        }
        .task { await musicStore.loadAlbums(sortOrder: sortOrder) }
    }

    // MARK: - CoverFlow

    private func coverFlow(geo: GeometryProxy) -> some View {
        let centerY = geo.size.height * 0.46
        let visible = DesignCoverFlow.visibleRadius
        let start   = max(0, focusIndex - visible - 1)
        let end     = min(albums.count, focusIndex + visible + 2)

        return ZStack {
            ForEach(start..<end, id: \.self) { i in
                let offset  = Double(i) - fractionalFocus
                coverCard(album: albums[i], index: i, offset: offset, centerY: centerY)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .gesture(
            DragGesture()
                .onChanged { value in
                    dragOffset = value.translation.height
                }
                .onEnded { value in
                    let velocity = value.predictedEndTranslation.height - value.translation.height
                    let net      = value.translation.height + velocity * 0.3
                    let threshold = DesignCoverFlow.spacing * 0.25

                    withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                        if net < -threshold {
                            focusIndex = min(focusIndex + 1, albums.count - 1)
                        } else if net > threshold {
                            focusIndex = max(focusIndex - 1, 0)
                        }
                        dragOffset = 0
                    }

                    // Paginate near end
                    if focusIndex > albums.count - 5 {
                        Task { await musicStore.loadNextPage(sortOrder: sortOrder) }
                    }
                }
        )
    }

    // MARK: - Album cover card

    @ViewBuilder
    private func coverCard(album: Album, index: Int, offset: Double, centerY: CGFloat) -> some View {
        let abs     = Swift.abs(offset)
        let scale   = CGFloat(abs < 0.01
            ? 1.0
            : max(0.28, Double(DesignCoverFlow.sideScale) - (abs - 1) * Double(DesignCoverFlow.sideScaleDecay)))
        let opacity  = max(0.0, 1.0 - abs * DesignCoverFlow.opacityDecay)
        let rotDeg   = offset * DesignCoverFlow.sideRotateX
        let yStep    = DesignCoverFlow.spacing * 0.52
        let yPos     = centerY + CGFloat(offset * Double(yStep))
        let artSize  = DesignCoverFlow.artSize

        VStack(spacing: 0) {
            // Album art + tap handler
            Button {
                if abs < 0.5 {
                    nav.albumsPath.append(album)
                } else {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                        focusIndex = index
                        dragOffset = 0
                    }
                }
            } label: {
                CoverArtImage(id: album.coverArt, size: 400)
                    .frame(width: artSize, height: artSize)
                    .clipShape(RoundedRectangle(cornerRadius: DesignRadius.lg))
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignRadius.lg)
                            .stroke(Color.white.opacity(0.12), lineWidth: 0.5)
                    )
            }
            .buttonStyle(.plain)

            // Reflection
            CoverArtImage(id: album.coverArt, size: 200)
                .frame(width: artSize, height: DesignCoverFlow.reflectionHeight)
                .clipShape(Rectangle())
                .scaleEffect(x: 1, y: -1)
                .opacity(DesignCoverFlow.reflectionOpacity)
                .allowsHitTesting(false)
                .mask(
                    LinearGradient(
                        colors: [.white, .clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
        }
        .rotation3DEffect(.degrees(rotDeg), axis: (x: 1, y: 0, z: 0), perspective: 0.35)
        .scaleEffect(scale)
        .opacity(opacity)
        .position(x: UIScreen.main.bounds.width / 2, y: yPos)
        .zIndex(Double(DesignCoverFlow.visibleRadius) - abs)
    }

    // MARK: - Top bar

    private var topBar: some View {
        VStack(spacing: 0) {
            LinearGradient(
                colors: [.black.opacity(0.80), .clear],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 100)
            .overlay(alignment: .bottom) {
                HStack(alignment: .bottom) {
                    Text("Albums")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(DesignText.onDark)
                        .padding(.leading, DesignSpacing.lg)
                        .padding(.bottom, DesignSpacing.md)

                    Spacer()

                    // Sort menu button
                    Menu {
                        ForEach(AlbumSortOrder.allCases, id: \.self) { order in
                            Button {
                                guard sortOrder != order else { return }
                                sortOrder = order
                                focusIndex = 0
                                Task { await musicStore.loadAlbums(sortOrder: order) }
                            } label: {
                                Label(order.label, systemImage: order.icon)
                            }
                        }
                    } label: {
                        Image(systemName: "arrow.up.arrow.down")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(DesignText.onDark)
                            .padding(DesignSpacing.sm)
                            .background(Color.white.opacity(0.12))
                            .clipShape(Circle())
                    }
                    .padding(.trailing, DesignSpacing.lg)
                    .padding(.bottom, DesignSpacing.md)
                }
            }

            Spacer()
        }
        .allowsHitTesting(true)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    // MARK: - Bottom nav

    private var bottomNav: some View {
        VStack(spacing: 0) {
            Spacer()

            LinearGradient(
                colors: [.clear, .black.opacity(0.75)],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 80)
            .overlay(alignment: .bottom) {
                HStack {
                    Button { nav.isPopoverVisible = true } label: {
                        Image(systemName: "line.3.horizontal")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(DesignText.onDark)
                            .frame(width: 32, height: 32)
                    }
                    .buttonStyle(.plain)

                    Spacer()

                    // Focus index dots
                    albumDots

                    Spacer()

                    Text("navidrome-sync")
                        .font(.system(size: 11, weight: .semibold))
                        .tracking(DesignType.tracking(from: DesignType.sectionLabel))
                        .textCase(.uppercase)
                        .foregroundStyle(DesignText.onDark)
                }
                .padding(.horizontal, DesignSpacing.lg)
                .padding(.bottom, DesignSpacing.md)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)

        // Nav popover
        .overlay(alignment: .bottomLeading) {
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

    // MARK: - Album position dots

    private var albumDots: some View {
        // Show a sliding window of up to 9 dots around the focused album
        let maxDots  = 9
        let half     = maxDots / 2
        let start    = max(0, min(focusIndex - half, albums.count - maxDots))
        let end      = min(albums.count, start + maxDots)

        return HStack(spacing: 4) {
            ForEach(start..<end, id: \.self) { i in
                let isActive = i == focusIndex
                Circle()
                    .fill(getCrateColor(albumId: albums[i].id).dot)
                    .frame(width: isActive ? 8 : 5, height: isActive ? 8 : 5)
                    .animation(DesignAnim.crateColor, value: focusIndex)
            }
        }
    }

    // MARK: - Loading / empty state

    private var emptyState: some View {
        Group {
            if musicStore.albumListStates[sortOrder]?.isLoading == true {
                ProgressView()
                    .tint(.white)
            } else {
                VStack(spacing: DesignSpacing.md) {
                    Image(systemName: "square.stack")
                        .font(.system(size: 48))
                        .foregroundStyle(DesignText.onDarkMuted)
                    Text("No albums")
                        .font(.system(size: 15))
                        .foregroundStyle(DesignText.onDarkMuted)
                }
            }
        }
    }
}
