import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var store: SyncStore
    @Binding var isLoggedIn: Bool
    @State private var selectedTab = 0

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $selectedTab) {
                NowPlayingView()
                    .tag(0)
                    .tabItem {
                        Label("Now Playing", systemImage: "music.note")
                    }
                    .toolbarBackground(.visible, for: .tabBar)

                LibraryView()
                    .tag(1)
                    .tabItem {
                        Label("Library", systemImage: "books.vertical")
                    }
                    .toolbarBackground(.visible, for: .tabBar)

                SettingsView(isLoggedIn: $isLoggedIn)
                    .tag(2)
                    .tabItem {
                        Label("Settings", systemImage: "gear")
                    }
                    .toolbarBackground(.visible, for: .tabBar)
            }
            .tint(Color.brandPink)
            .toolbarBackground(
                AnyShapeStyle(store.dominantBackgroundColor),
                for: .tabBar
            )
            .toolbarColorScheme(.dark, for: .tabBar)

            // Persistent mini player bar above tab bar (hidden on Now Playing tab)
            if store.nowPlaying != nil && selectedTab != 0 {
                NowPlayingBar(selectedTab: $selectedTab)
                    .padding(.bottom, 49) // tab bar height
            }
        }

    }
}

// MARK: - Mini player bar

struct NowPlayingBar: View {
    @EnvironmentObject private var store: SyncStore
    @Binding var selectedTab: Int

    var body: some View {
        if let song = store.nowPlaying {
            HStack(spacing: 12) {
                // Tappable area — navigates to Now Playing
                Button {
                    selectedTab = 0
                } label: {
                    HStack(spacing: 12) {
                        CoverArtImage(id: song.coverArtId, size: 80)
                            .frame(width: 44, height: 44)
                            .clipShape(RoundedRectangle(cornerRadius: 6))

                        VStack(alignment: .leading, spacing: 2) {
                            Text(song.title)
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .lineLimit(1)
                                .foregroundStyle(.primary)
                            Text(song.artist)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }

                        Spacer()
                    }
                }
                .buttonStyle(.plain)

                // Playback controls
                Button {
                    store.prev()
                } label: {
                    Image(systemName: "backward.fill")
                        .font(.title3)
                        .frame(width: 36, height: 36)
                }
                .buttonStyle(.plain)

                Button {
                    if store.isPlaying { store.pause() } else { store.play() }
                } label: {
                    Image(systemName: store.isPlaying ? "pause.fill" : "play.fill")
                        .font(.title3)
                        .frame(width: 36, height: 36)
                }
                .buttonStyle(.plain)

                Button {
                    store.next()
                } label: {
                    Image(systemName: "forward.fill")
                        .font(.title3)
                        .frame(width: 36, height: 36)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background {
                store.dominantBackgroundColor
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
