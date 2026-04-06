import SwiftUI

struct AlbumsView: View {
    @State private var albums: [Album] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

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
                        Task { await loadAlbums(force: true) }
                    }
                    .buttonStyle(.bordered)
                }
                .padding(.top, 60)
            } else {
                AlbumGridView(albums: albums)
            }
        }
        .navigationTitle("Albums")
        .task {
            await loadAlbums()
        }
    }

    private func loadAlbums(force: Bool = false) async {
        guard force || albums.isEmpty else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            albums = try await NavidromeClient.shared.getAlbums()
            if albums.isEmpty {
                errorMessage = "No albums found."
            }
        } catch {
            errorMessage = "Could not load albums.\n\(error.localizedDescription)"
        }
    }
}
