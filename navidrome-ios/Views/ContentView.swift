import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var store: SyncStore
    @Binding var isLoggedIn: Bool

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView {
                NowPlayingView()
                    .tabItem {
                        Label("Now Playing", systemImage: "music.note")
                    }

                LibraryView()
                    .tabItem {
                        Label("Library", systemImage: "books.vertical")
                    }

                SettingsView(isLoggedIn: $isLoggedIn)
                    .tabItem {
                        Label("Settings", systemImage: "gear")
                    }
            }

            // Persistent mini player bar above tab bar
            if store.nowPlaying != nil {
                NowPlayingBar()
                    .padding(.bottom, 49) // tab bar height
            }
        }

    }
}

// MARK: - Mini player bar

struct NowPlayingBar: View {
    @EnvironmentObject private var store: SyncStore

    var body: some View {
        if let song = store.nowPlaying {
            HStack(spacing: 12) {
                // Cover art thumbnail
                CoverArtImage(id: song.coverArtId, size: 80)
                    .frame(width: 44, height: 44)
                    .clipShape(RoundedRectangle(cornerRadius: 6))

                VStack(alignment: .leading, spacing: 2) {
                    Text(song.title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .lineLimit(1)
                    Text(song.artist)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                if store.isConnected {
                    // Role badge (only shown when sync service is connected)
                    Text(store.myRole == "active" ? "Active" : "Observing")
                        .font(.caption2)
                        .fontWeight(.medium)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(store.myRole == "active" ? Color.green.opacity(0.2) : Color.secondary.opacity(0.2))
                        .foregroundStyle(store.myRole == "active" ? .green : .secondary)
                        .clipShape(Capsule())

                    // Connection dot
                    Circle()
                        .fill(Color.green)
                        .frame(width: 8, height: 8)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial)
        }
    }
}

// MARK: - Reusable cover art image

struct CoverArtImage: View {
    let id: String
    var size: Int = 300

    var body: some View {
        let url = NavidromeClient.shared.coverArtURL(id: id, size: size)
        AsyncImage(url: url) { phase in
            switch phase {
            case .success(let image):
                image.resizable().aspectRatio(contentMode: .fill)
            case .failure:
                placeholder
            case .empty:
                if url != nil {
                    ProgressView()
                } else {
                    placeholder
                }
            @unknown default:
                placeholder
            }
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
