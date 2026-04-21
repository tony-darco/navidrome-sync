import SwiftUI

struct SongsView: View {
    @EnvironmentObject private var store: SyncStore
    @EnvironmentObject private var downloadManager: DownloadManager
    @Environment(AppNavigationState.self) private var nav
    @Environment(CrateColorState.self) private var crateState

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

    private var availableLetters: [String] { groupedSongs.map(\.letter) }

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            DesignBg.cream.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Songs")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundStyle(DesignText.primary)
                        if !songs.isEmpty {
                            Text("\(songs.count) songs")
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
                            ForEach(groupedSongs, id: \.letter) { group in
                                Section {
                                    ForEach(group.songs) { song in
                                        Button { playSong(song) } label: {
                                            songRow(song)
                                        }
                                        .contextMenu {
                                            Button {
                                                playSong(song)
                                            } label: {
                                                Label("Play", systemImage: "play.fill")
                                            }
                                            Button {
                                                store.appendToQueue(song.toNowPlayingSong())
                                            } label: {
                                                Label("Add to Queue", systemImage: "text.badge.plus")
                                            }
                                            Divider()
                                            if downloadManager.isDownloaded(songId: song.id) {
                                                Button(role: .destructive) {
                                                    downloadManager.remove(songId: song.id)
                                                } label: {
                                                    Label("Remove Download", systemImage: "trash")
                                                }
                                            } else {
                                                Button {
                                                    downloadManager.download(song: song)
                                                } label: {
                                                    Label("Download", systemImage: "arrow.down.circle")
                                                }
                                            }
                                        }
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
                    }

                    if !availableLetters.isEmpty {
                        AlphabetScrubber(
                            letters: availableLetters,
                            activeLetters: Set(availableLetters),
                            selectedLetter: $selectedLetter
                        )
                    }
                }
                // Leave room for mini player + bottom nav
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
        .task { await loadAllSongs() }
    }

    // MARK: - Song row (58pt)

    private func songRow(_ song: Song) -> some View {
        HStack(spacing: DesignSpacing.md) {
            // Track number
            Text(song.track > 0 ? String(song.track) : "·")
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(DesignText.tertiary)
                .frame(width: 22, alignment: .trailing)

            // Album art thumbnail
            CoverArtImage(id: song.coverArt, size: 80)
                .frame(width: DesignDim.thumbMd, height: DesignDim.thumbMd)
                .clipShape(RoundedRectangle(cornerRadius: DesignRadius.sm))

            // Title + artist · album
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

            DownloadStatusIcon(task: downloadManager.taskMap[song.id])

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
                if page.count < pageSize { fullyLoaded = true } else { offset += pageSize }
            } catch {
                print("[songs] failed to load page at offset \(offset): \(error)")
                break
            }
        }
        isLoading = false
    }
}
