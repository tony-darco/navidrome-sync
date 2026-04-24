import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var store: SyncStore
    @EnvironmentObject private var downloadManager: DownloadManager
    @Binding var isLoggedIn: Bool
    @State private var selectedTab = 0
    @State private var libraryPath = NavigationPath()

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $selectedTab) {
                NowPlayingView(
                    onNavigateToAlbum: { albumId in
                        withAnimation(.easeInOut(duration: 0.25)) { selectedTab = 1 }
                        libraryPath.append(Album.navigationPlaceholder(id: albumId))
                    },
                    onNavigateToArtist: { artistId, artistName in
                        withAnimation(.easeInOut(duration: 0.25)) { selectedTab = 1 }
                        libraryPath.append(ArtistID3(id: artistId, name: artistName))
                    }
                )
                .tag(0)
                .tabItem {
                    Label("Now Playing", systemImage: "music.note")
                }
                .toolbarBackground(.visible, for: .tabBar)

                NavigationStack(path: $libraryPath) {
                    LibraryView()
                }
                .tag(1)
                .tabItem {
                    Label("Library", systemImage: "books.vertical")
                }
                .toolbarBackground(.visible, for: .tabBar)
                .safeAreaInset(edge: .bottom) {
                    Color.clear.frame(height: store.nowPlaying != nil ? (store.miniPlayerCollapsed ? 6 : 68) : 0)
                }

                SearchView()
                    .tag(2)
                    .tabItem {
                        Label("Search", systemImage: "magnifyingglass")
                    }
                    .toolbarBackground(.visible, for: .tabBar)
                    .safeAreaInset(edge: .bottom) {
                        Color.clear.frame(height: store.nowPlaying != nil ? (store.miniPlayerCollapsed ? 6 : 68) : 0)
                }

                SettingsView(isLoggedIn: $isLoggedIn)
                    .tag(3)
                    .tabItem {
                        Label("Settings", systemImage: "gear")
                    }
                    .toolbarBackground(.visible, for: .tabBar)
                    .safeAreaInset(edge: .bottom) {
                        Color.clear.frame(height: store.nowPlaying != nil ? (store.miniPlayerCollapsed ? 6 : 68) : 0)
                }
            }
            .tint(Color.brandPink)
            .toolbarBackground(
                AnyShapeStyle(store.dominantBackgroundColor),
                for: .tabBar
            )
            .toolbarColorScheme(.dark, for: .tabBar)

            // Persistent mini player above tab bar (hidden on Now Playing tab)
            if store.nowPlaying != nil && selectedTab != 0 {
                VStack(spacing: 0) {
                    if store.miniPlayerCollapsed {
                        // Collapsed: thin capsule playbar sitting at the top of the tab bar
                        MiniPlayerPlaybar()
                            .padding(.horizontal, 75)
                            .transition(.opacity)
                    } else {
                        // Expanded: full pill with progress bar embedded inside
                        NowPlayingBar(selectedTab: $selectedTab, libraryPath: $libraryPath)
                            .padding(.horizontal, 12)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
                .padding(.bottom, 49) // tab bar height
                .animation(.easeInOut(duration: 0.2), value: store.miniPlayerCollapsed)
            }

            // Offline mode banner
            if AppConfig.offlineMode {
                VStack {
                    HStack(spacing: 6) {
                        Image(systemName: "wifi.slash")
                            .font(.caption)
                        Text("Offline Mode")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(Color.orange.opacity(0.9))
                    .clipShape(Capsule())
                    Spacer()
                }
                .padding(.top, 4)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: selectedTab)
        .ignoresSafeArea(.keyboard)
    }
}

// MARK: - Collapsed capsule playbar (shown at top of tab bar when pill is hidden)

struct MiniPlayerPlaybar: View {
    @EnvironmentObject private var store: SyncStore

    var body: some View {
        if let song = store.nowPlaying {
            let duration = max(Double(song.durationSecs), 1)
            let progress = min(store.position / duration, 1)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Color.brandPink.opacity(0.25)
                    Color.brandPink
                        .frame(width: geo.size.width * progress)
                }
            }
            .frame(height: 4)
            .clipShape(Capsule())
        }
    }
}

// MARK: - Mini player bar

struct NowPlayingBar: View {
    @EnvironmentObject private var store: SyncStore
    @Binding var selectedTab: Int
    @Binding var libraryPath: NavigationPath

    var body: some View {
        if let song = store.nowPlaying {
            if #available(iOS 26.0, *) {
                VStack(spacing: 0) {
                    // Thin progress bar embedded at the top of the pill
                    let duration = max(Double(song.durationSecs), 1)
                    let progress = min(store.position / duration, 1)
                    GeometryReader { geo in
                        Color.brandPink
                            .frame(width: geo.size.width * progress)
                    }
                    .frame(height: 3)
                    .padding(.horizontal, 45)

                    HStack(spacing: 12) {
                    // Cover art
                    Button {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            selectedTab = 0
                        }
                    } label: {
                        CoverArtImage(id: song.coverArtId, size: 80)
                            .frame(width: 44, height: 44)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(.plain)

                    // Song info — title and artist are separate tap targets
                    VStack(alignment: .leading, spacing: 2) {
                        if let albumId = song.albumId, !albumId.isEmpty {
                            Button {
                                withAnimation(.easeInOut(duration: 0.25)) { selectedTab = 1 }
                                libraryPath.append(Album.navigationPlaceholder(id: albumId))
                            } label: {
                                Text(song.title)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .lineLimit(1)
                                    .foregroundStyle(.primary)
                            }
                            .buttonStyle(.plain)
                        } else {
                            Text(song.title)
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .lineLimit(1)
                                .foregroundStyle(.primary)
                        }

                        Button {
                            if let artistId = song.artistId, !artistId.isEmpty {
                                withAnimation(.easeInOut(duration: 0.25)) { selectedTab = 1 }
                                libraryPath.append(ArtistID3(id: artistId, name: song.artist))
                            } else {
                                let firstName = song.artist.split(separator: ";").first.map { $0.trimmingCharacters(in: .whitespaces) } ?? song.artist
                                Task {
                                    if let found = try? await NavidromeClient.shared.searchArtist(name: firstName) {
                                        withAnimation(.easeInOut(duration: 0.25)) { selectedTab = 1 }
                                        libraryPath.append(ArtistID3(id: found.id, name: found.name))
                                    }
                                }
                            }
                        } label: {
                            Text(song.artist)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        .buttonStyle(.plain)
                    }

                    Spacer()

                    // Playback controls — plain icons, brandPink tint, no circles
                    HStack(spacing: 4) {
                        Button {
                            store.prev()
                        } label: {
                            Image(systemName: "backward.end.fill")
                                .font(.title3)
                                .frame(width: 36, height: 36)
                        }

                        Button {
                            if store.isPlaying { store.pause() } else { store.play() }
                        } label: {
                            Image(systemName: store.isPlaying ? "pause.fill" : "play.fill")
                                .font(.title3)
                                .frame(width: 36, height: 36)
                                .contentTransition(.symbolEffect(.replace))
                        }

                        Button {
                            store.next()
                        } label: {
                            Image(systemName: "forward.end.fill")
                                .font(.title3)
                                .frame(width: 36, height: 36)
                        }
                    }
                    .tint(Color.brandPink)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                } // end VStack
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.25)) { selectedTab = 0 }
                }
                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 28))
            } else {
                // Fallback on earlier versions
            }
        }
    }
}

// MARK: - Navigation helpers

private extension Album {
    /// Creates a minimal placeholder used purely for navigation; `AlbumDetailView` only needs the id.
    static func navigationPlaceholder(id: String) -> Album {
        Album(id: id, name: "", artist: "", coverArt: "", songCount: 0, year: nil)
    }
}

// MARK: - Reusable cover art image

struct CoverArtImage: View {
    let id: String
    var size: Int = 300
    var isNowPlaying: Bool = false
    var isPlaying: Bool = false

    @State private var image: UIImage?
    @State private var isLoading = false

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else if isLoading {
                ProgressView()
            } else {
                placeholder
            }
        }
        .overlay { NowPlayingOverlay(isNowPlaying: isNowPlaying, isPlaying: isPlaying) }
        .task(id: id) {
            guard !id.isEmpty, !isLoading else { return }
            isLoading = true
            image = await ImageCache.shared.image(for: id, size: size)
            isLoading = false
        }
    }

    private var placeholder: some View {
        Rectangle()
            .fill(Color(.systemGray5))
            .overlay {
                Image(systemName: "music.note")
                    .foregroundStyle(.secondary)
            }
    }
}
