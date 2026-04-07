import SwiftUI

struct AlbumsView: View {
    @EnvironmentObject private var store: SyncStore
    @State private var albums: [Album] = []
    @State private var isLoading = false
    @State private var hasMore = true
    @State private var errorMessage: String?

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
        .task {
            await loadAllAlbums()
        }
    }

    private func loadAllAlbums(force: Bool = false) async {
        guard force || albums.isEmpty else { return }
        albums = []
        hasMore = true
        errorMessage = nil
        isLoading = true
        defer { isLoading = false }
        do {
            let batch = try await NavidromeClient.shared.getAlbums(
                type: "alphabeticalByName", size: pageSize, offset: 0
            )
            albums = batch
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
                type: "alphabeticalByName", size: pageSize, offset: albums.count
            )
            albums.append(contentsOf: batch)
            hasMore = batch.count >= pageSize
        } catch {
            print("[albums] failed to load page: \(error)")
        }
    }
}
