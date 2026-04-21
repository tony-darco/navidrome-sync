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

    @AppStorage("albumSortOrder") private var sortOrderRaw: String = AlbumSortOrder.alphabeticalByName.rawValue
    @AppStorage("albumIsGrid") private var isGrid: Bool = false

    @State private var focusIndex: Int  = 0
    @State private var dragOffset: CGFloat = 0
    @State private var selectedLetter: String? = nil

    private var sortOrder: AlbumSortOrder {
        AlbumSortOrder(rawValue: sortOrderRaw) ?? .alphabeticalByName
    }

    private var albums: [Album] {
        musicStore.albumListStates[sortOrder]?.albums ?? []
    }

    /// Fractional focus position during drag (negative drag = forward through list)
    private var fractionalFocus: Double {
        Double(focusIndex) - Double(dragOffset) / Double(DesignCoverFlow.spacing)
    }

    var body: some View {
        @Bindable var nav = nav

        GeometryReader { geo in
            ZStack {
                Color(hex: "#0A0A0A").ignoresSafeArea()

                if albums.isEmpty {
                    emptyState
                } else if isGrid {
                    gridView
                } else {
                    coverFlow(geo: geo)
                }

                topBar

                // Alphabet scrubber — right edge, only for alpha-sorted CoverFlow
                if !isGrid, (sortOrder == .alphabeticalByName || sortOrder == .alphabeticalByArtist) {
                    HStack {
                        Spacer()
                        AlphabetScrubber(
                            letters: scrubberLetters,
                            activeLetters: Set(scrubberLetters),
                            selectedLetter: $selectedLetter
                        )
                        .padding(.trailing, 4)
                        .padding(.top, 100)
                        .padding(.bottom, 20)
                    }
                    .allowsHitTesting(true)
                }

                NavPopoverView(
                    isVisible: Binding(
                        get: { nav.isPopoverVisible },
                        set: { nav.isPopoverVisible = $0 }
                    ),
                    crate: crateState.current,
                    onNavigate: { nav.handlePopoverSelection($0) },
                    bottomInset: 0
                )
            }
        }
        .ignoresSafeArea()
        .navigationDestination(for: Album.self) { album in
            AlbumDetailView(albumId: album.id)
        }
        .task { await musicStore.loadAlbums(sortOrder: sortOrder) }
        .onChange(of: selectedLetter) { _, letter in
            guard let letter else { return }
            jumpToLetter(letter)
        }
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

    // MARK: - Grid view

    private var gridView: some View {
        ScrollView {
            AlbumGridView(albums: albums)
                .padding(.top, 100)
                .padding(.bottom, 20)
        }
        .background(Color(hex: "#0A0A0A"))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
                    // Hamburger — opens nav popover
                    Button { nav.isPopoverVisible = true } label: {
                        Image(systemName: "line.3.horizontal")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(DesignText.onDark)
                            .padding(DesignSpacing.sm)
                            .background(Color.white.opacity(0.12))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .padding(.leading, DesignSpacing.lg)
                    .padding(.bottom, DesignSpacing.md)

                    Spacer()

                    Text("Albums")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(DesignText.onDark)
                        .padding(.bottom, DesignSpacing.md)

                    Spacer()

                    HStack(spacing: DesignSpacing.sm) {
                        // Now Playing button — only when a track is loaded
                        if store.nowPlaying != nil {
                            Button { nav.navigate(to: .nowPlaying) } label: {
                                Image(systemName: "music.note")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundStyle(DesignText.onDark)
                                    .padding(DesignSpacing.sm)
                                    .background(Color.white.opacity(0.12))
                                    .clipShape(Circle())
                            }
                            .buttonStyle(.plain)
                            .transition(.scale.combined(with: .opacity))
                        }

                        // Sort menu
                        Menu {
                            ForEach(AlbumSortOrder.allCases, id: \.self) { order in
                                Button {
                                    guard sortOrder != order else { return }
                                    sortOrderRaw = order.rawValue
                                    focusIndex = 0
                                    selectedLetter = nil
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
                    }
                    .padding(.trailing, DesignSpacing.lg)
                    .padding(.bottom, DesignSpacing.md)
                    .animation(.easeInOut(duration: 0.2), value: store.nowPlaying != nil)
                }
            }

            Spacer()
        }
        .allowsHitTesting(true)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    // MARK: - Alphabet scrubber support

    private var scrubberLetters: [String] {
        let isArtistSort = sortOrder == .alphabeticalByArtist
        var seen = Set<String>()
        var result: [String] = []
        for album in albums {
            let raw = isArtistSort ? album.artist : album.name
            let first = raw.prefix(1).uppercased()
            let token = first.first?.isLetter == true ? first : "#"
            if seen.insert(token).inserted { result.append(token) }
        }
        return result
    }

    private func jumpToLetter(_ letter: String) {
        let isArtistSort = sortOrder == .alphabeticalByArtist
        let token = letter.first?.isLetter == true ? letter : "#"
        if let idx = albums.firstIndex(where: { album in
            let raw = isArtistSort ? album.artist : album.name
            let first = raw.prefix(1).uppercased()
            let t = first.first?.isLetter == true ? first : "#"
            return t == token
        }) {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                focusIndex = idx
                dragOffset = 0
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
