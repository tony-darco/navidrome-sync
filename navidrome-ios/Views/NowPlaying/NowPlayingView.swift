import SwiftUI

// MARK: - NowPlayingView

struct NowPlayingView: View {
    @EnvironmentObject private var store: SyncStore
    @Environment(AppNavigationState.self) private var nav
    @Environment(CrateColorState.self) private var crateState

    @State private var showQueue         = false
    @State private var showAddToPlaylist = false

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .bottomLeading) {
                VStack(spacing: 0) {
                    graphicZone(height: geo.size.height * 0.55)
                    bodyZone(height:   geo.size.height * 0.45)
                }

                // Nav popover — overlays both zones, anchored bottom-left
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
        .onChange(of: store.nowPlaying?.albumId) { _, newId in
            guard let id = newId else { return }
            crateState.update(albumId: id)
        }
        .onAppear {
            if let id = store.nowPlaying?.albumId {
                crateState.update(albumId: id)
            }
        }
        .sheet(isPresented: $showQueue) {
            QueueSheet().environmentObject(store)
        }
        .sheet(isPresented: $showAddToPlaylist) {
            if let songId = store.nowPlaying?.songId {
                AddToPlaylistSheet(songId: songId)
            }
        }
    }

    // MARK: - Graphic zone (top 55%)

    @ViewBuilder
    private func graphicZone(height: CGFloat) -> some View {
        ZStack(alignment: .bottom) {

            // Full-bleed album art or vinyl fallback
            Group {
                if let song = store.nowPlaying {
                    CoverArtImage(id: song.coverArtId, size: 600)
                        .scaledToFill()
                } else {
                    Rectangle().fill(DesignBg.playerDark)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: height)
            .clipped()

            // Gradient overlay
            LinearGradient(
                stops: [
                    .init(color: .black.opacity(0.10), location: 0.00),
                    .init(color: .black.opacity(0.00), location: 0.30),
                    .init(color: .black.opacity(0.62), location: 1.00),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .allowsHitTesting(false)

            // Status bar pinned to top
            statusBar
                .frame(maxWidth: .infinity, maxHeight: height, alignment: .top)

            // Track info + scrubber pinned to bottom
            if let song = store.nowPlaying {
                trackInfoBlock(song: song)
            } else {
                emptyOverlay
            }
        }
        .frame(height: height)
    }

    // MARK: - Status bar

    private var statusBar: some View {
        HStack(spacing: DesignSpacing.sm) {
            Spacer()
            Image(systemName: "wifi")
                .font(.system(size: 11))
            Image(systemName: "battery.100")
                .font(.system(size: 11))
        }
        .foregroundStyle(DesignText.onDark)
        .padding(.horizontal, DesignSpacing.xl)
        .padding(.top, 52)
    }

    // MARK: - Track info block

    private func trackInfoBlock(song: NowPlayingSong) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(song.title)
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(DesignText.onDark)
                .lineLimit(1)
            Text(song.artist)
                .font(.system(size: 12))
                .foregroundStyle(DesignText.onDark)
                .lineLimit(1)
            Text(song.album)
                .font(.system(size: 10))
                .foregroundStyle(DesignText.onDarkMuted)
                .lineLimit(1)
            progressBar(song: song)
                .padding(.top, DesignSpacing.xs)
        }
        .padding(.horizontal, DesignSpacing.lg)
        .padding(.bottom, DesignSpacing.md)
    }

    // MARK: - Empty state overlay (graphic zone)

    private var emptyOverlay: some View {
        VStack(spacing: DesignSpacing.md) {
            Image(systemName: "music.note")
                .font(.system(size: 48))
                .foregroundStyle(DesignText.onDarkMuted)
            Text("Nothing playing")
                .font(.system(size: 15))
                .foregroundStyle(DesignText.onDarkMuted)
        }
        .padding(.bottom, DesignSpacing.xl)
    }

    // MARK: - Progress scrubber (2pt bar + 8pt dot)

    private func progressBar(song: NowPlayingSong) -> some View {
        GeometryReader { geo in
            let duration  = max(1.0, Double(song.durationSecs))
            let fraction  = CGFloat(min(1.0, max(0.0, store.position / duration)))
            let fillWidth = geo.size.width * fraction

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(crateState.current.progBg)
                    .frame(height: DesignDim.miniProgressH)
                Capsule()
                    .fill(crateState.current.progFill)
                    .frame(width: fillWidth, height: DesignDim.miniProgressH)
                Circle()
                    .fill(crateState.current.progFill)
                    .frame(width: 8, height: 8)
                    .offset(x: max(0, fillWidth - 4))
            }
            .frame(height: 20, alignment: .center)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        guard store.myRole == "active" else { return }
                        let pct = min(1.0, max(0.0, Double(value.location.x / geo.size.width)))
                        store.seek(to: pct * duration)
                    }
            )
        }
        .frame(height: 20)
    }

    // MARK: - Body zone (bottom 45%)

    @ViewBuilder
    private func bodyZone(height: CGFloat) -> some View {
        ZStack(alignment: .bottom) {

            // Crate device color — transitions via CrateColorState.update()
            Rectangle().fill(crateState.current.device)

            VStack(spacing: 0) {
                Spacer()

                ClickWheelView(
                    crate:       crateState.current,
                    onCenterTap: {
                        if store.isPlaying { store.pause() } else { store.play() }
                    },
                    onTopTap:    { },   // volume — handled by hardware buttons
                    onBottomTap: { },
                    onLeftTap:   { store.prev() },
                    onRightTap:  { store.next() },
                    onScrub: { fraction in
                        guard let song = store.nowPlaying else { return }
                        store.seek(to: fraction * Double(song.durationSecs))
                    }
                )

                Spacer()
            }
            .padding(.bottom, DesignDim.bottomNavHeight)

            bottomBar
        }
        .frame(height: height)
    }

    // MARK: - Bottom bar

    private var bottomBar: some View {
        HStack {
            Button {
                nav.isPopoverVisible = true
            } label: {
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(crateState.current.text)
                    .frame(width: 44, height: 44)
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
}

// MARK: - Queue Sheet

struct QueueSheet: View {
    @EnvironmentObject private var store: SyncStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                if store.queueIndex < store.queue.count {
                    Section("Now Playing") {
                        queueRow(store.queue[store.queueIndex], isActive: true)
                    }
                }

                let upcoming = Array(store.queue.dropFirst(store.queueIndex + 1))
                if !upcoming.isEmpty {
                    Section {
                        ForEach(Array(upcoming.enumerated()), id: \.element.songId) { offset, song in
                            Button {
                                store.playQueue(store.queue, startIndex: store.queueIndex + 1 + offset)
                            } label: {
                                queueRow(song, isActive: false)
                            }
                            .buttonStyle(.plain)
                        }
                    } header: {
                        HStack {
                            Text("Next From: \(store.nowPlaying?.album ?? "")")
                            Spacer()
                            Button("Clear queue") { store.clearQueue() }
                                .font(.subheadline)
                        }
                    }
                }
            }
            .listStyle(.plain)
            .navigationTitle(store.nowPlaying?.album ?? "Queue")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { dismiss() } label: { Image(systemName: "xmark") }
                }
            }
        }
    }

    private func queueRow(_ song: NowPlayingSong, isActive: Bool) -> some View {
        HStack(spacing: 12) {
            CoverArtImage(id: song.coverArtId, size: 80)
                .frame(width: 44, height: 44)
                .clipShape(RoundedRectangle(cornerRadius: 6))
            VStack(alignment: .leading, spacing: 2) {
                Text(song.title)
                    .font(.subheadline)
                    .fontWeight(isActive ? .semibold : .regular)
                    .foregroundStyle(isActive ? Color.brandPink : .primary)
                    .lineLimit(1)
                Text(song.artist)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
        }
    }
}
