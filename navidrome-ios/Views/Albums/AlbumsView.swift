import SwiftUI

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
        case .alphabeticalByName: "Name"
        case .alphabeticalByArtist: "Artist"
        case .newest: "Recently Added"
        case .byYear: "Year"
        case .mostPlayed: "Most Played"
        case .recentlyPlayed: "Recently Played"
        case .random: "Random"
        }
    }

    var icon: String {
        switch self {
        case .alphabeticalByName: "textformat.abc"
        case .alphabeticalByArtist: "person"
        case .newest: "sparkles"
        case .byYear: "calendar"
        case .mostPlayed: "chart.bar"
        case .recentlyPlayed: "clock"
        case .random: "shuffle"
        }
    }
}

struct AlbumsView: View {
    @EnvironmentObject private var store: SyncStore
    @EnvironmentObject private var musicStore: MusicLibraryStore
    @State private var sortOrder: AlbumSortOrder = .alphabeticalByName

    private let columns = [GridItem(.adaptive(minimum: 160), spacing: 16)]

    private var currentState: MusicLibraryStore.AlbumListState? {
        musicStore.albumListStates[sortOrder]
    }

    var body: some View {
        ScrollView {
            if let state = currentState {
                if state.isLoading && state.albums.isEmpty {
                    ProgressView()
                        .padding(.top, 60)
                } else if let errorMessage = state.errorMessage, state.albums.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.largeTitle)
                            .foregroundStyle(.secondary)
                        Text(errorMessage)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        Button("Retry") {
                            Task { await musicStore.loadAlbums(sortOrder: sortOrder, force: true) }
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding(.top, 60)
                } else {
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(state.albums) { album in
                            NavigationLink(value: album) {
                                albumCell(album)
                            }
                            .buttonStyle(.plain)
                            .onAppear {
                                if album.id == state.albums.last?.id {
                                    Task { await musicStore.loadNextPage(sortOrder: sortOrder) }
                                }
                            }
                        }
                    }
                    .padding()

                    if state.isLoading {
                        ProgressView()
                            .padding(.bottom, 16)
                    }
                }
            } else {
                ProgressView()
                    .padding(.top, 60)
            }
        }
        .background { store.dominantBackgroundColor.ignoresSafeArea() }
        .navigationTitle("Albums")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    ForEach(AlbumSortOrder.allCases, id: \.self) { order in
                        Button {
                            guard sortOrder != order else { return }
                            sortOrder = order
                            Task { await musicStore.loadAlbums(sortOrder: order) }
                        } label: {
                            Label(order.label, systemImage: order.icon)
                        }
                    }
                } label: {
                    Label("Sort", systemImage: "arrow.up.arrow.down")
                        .labelStyle(.iconOnly)
                }
            }
        }
        .task {
            await musicStore.loadAlbums(sortOrder: sortOrder)
        }
    }

    private func albumCell(_ album: Album) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            CoverArtImage(id: album.coverArt, size: 300)
                .aspectRatio(1, contentMode: .fill)
                .clipShape(RoundedRectangle(cornerRadius: 8))

            Text(album.name)
                .font(.subheadline)
                .fontWeight(.medium)
                .lineLimit(1)

            Text(album.artist)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }
}
