import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var store: SyncStore
    @EnvironmentObject private var downloadManager: DownloadManager
    @Binding var isLoggedIn: Bool

    @State private var nav = AppNavigationState()
    @State private var crateState = CrateColorState()

    var body: some View {
        // @Bindable lets us pass $nav.xPath bindings into NavigationStack
        @Bindable var nav = nav

        ZStack(alignment: .top) {
            // ── Device shell: left rail + content + right rail ────────────────
            HStack(spacing: 0) {

                // Left rail — 14 pt, crate.outer, animated on track change
                Rectangle()
                    .fill(crateState.current.outer)
                    .frame(width: DesignDim.sideBarWidth)
                    .animation(DesignAnim.crateColor, value: crateState.current.name)
                    .ignoresSafeArea()

                // ── Top-level view switcher ───────────────────────────────────
                Group {
                    switch nav.currentView {
                    case .nowPlaying:
                        NowPlayingView()

                    case .library:
                        LibraryView()

                    case .albums:
                        NavigationStack(path: $nav.albumsPath) {
                            AlbumsView()
                        }

                    case .playlists:
                        NavigationStack(path: $nav.playlistsPath) {
                            PlaylistsView()
                        }

                    case .songs:
                        NavigationStack(path: $nav.songsPath) {
                            SongsView()
                        }

                    case .artists:
                        NavigationStack(path: $nav.artistsPath) {
                            ArtistsView()
                        }

                    case .search:
                        NavigationStack(path: $nav.searchPath) {
                            SearchView()
                        }

                    case .settings:
                        NavigationStack(path: $nav.settingsPath) {
                            SettingsView(isLoggedIn: $isLoggedIn)
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                // Right rail — mirrors left rail
                Rectangle()
                    .fill(crateState.current.outer)
                    .frame(width: DesignDim.sideBarWidth)
                    .animation(DesignAnim.crateColor, value: crateState.current.name)
                    .ignoresSafeArea()
            }
            .ignoresSafeArea(edges: .bottom)
            .environment(nav)
            .environment(crateState)

            // ── Offline mode banner ───────────────────────────────────────────
            if AppConfig.offlineMode {
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
                .padding(.top, 4)
            }
        }
    }
}

// MARK: - Reusable cover art image

struct CoverArtImage: View {
    let id: String
    var size: Int = 300

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
