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
    @State private var albums: [Album] = []
    @State private var seenIDs: Set<String> = []
    @State private var isLoading = false
    @State private var hasMore = true
    @State private var currentOffset = 0
    @State private var errorMessage: String?
    @State private var sortOrder: AlbumSortOrder = .alphabeticalByName

    private let pageSize = 500

    var body: some View {
        ScrollView {
            if isLoading && albums.isEmpty {
                ProgressView()
                    .padding(.top, 60)
            } else if let errorMessage, albums.isEmpty {
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
                        Task { await loadAllAlbums(force: true) }
                    }
                    .buttonStyle(.bordered)
                }
                .padding(.top, 60)
            } else {
                AlbumGridView(albums: albums)

                if hasMore {
                    ProgressView()
                        .padding()
                        .onAppear {
                            Task { await loadNextPage() }
                        }
                }
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
                            Task { await loadAllAlbums(force: true) }
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
            await loadAllAlbums()
        }
    }

    private func loadAllAlbums(force: Bool = false) async {
        guard force || albums.isEmpty else { return }
        albums = []
        seenIDs = []
        currentOffset = 0
        hasMore = true
        errorMessage = nil
        isLoading = true
        defer { isLoading = false }
        do {
            let batch = try await NavidromeClient.shared.getAlbums(
                type: sortOrder.rawValue, size: pageSize, offset: 0
            )
            let unique = batch.filter { seenIDs.insert($0.id).inserted }
            albums = unique
            currentOffset = batch.count
            hasMore = batch.count >= pageSize
            if albums.isEmpty {
                errorMessage = "No albums found."
            }
        } catch {
            errorMessage = "Could not load albums.\n\(error.localizedDescription)"
        }
    }

    private func loadNextPage() async {
        guard hasMore, !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let batch = try await NavidromeClient.shared.getAlbums(
                type: sortOrder.rawValue, size: pageSize, offset: currentOffset
            )
            let unique = batch.filter { seenIDs.insert($0.id).inserted }
            albums.append(contentsOf: unique)
            currentOffset += batch.count
            hasMore = batch.count >= pageSize
        } catch {
            print("[albums] failed to load page: \(error)")
        }
    }
}
