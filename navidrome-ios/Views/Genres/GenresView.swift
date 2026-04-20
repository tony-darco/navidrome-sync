import SwiftUI

struct GenresView: View {
    @EnvironmentObject private var store: SyncStore
    @State private var genres: [Genre] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        List {
            if isLoading && genres.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.top, 40)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            } else if let errorMessage, genres.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    Text(errorMessage)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    Button("Retry") {
                        Task { await loadGenres(force: true) }
                    }
                    .buttonStyle(.bordered)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 40)
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            } else {
                ForEach(genres) { genre in
                    NavigationLink(value: genre) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(genre.name)
                                    .font(.body)
                                    .foregroundColor(.primary)
                                Text("\(genre.albumCount) albums · \(genre.songCount) songs")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                        }
                        .padding(.vertical, 4)
                    }
                    .listRowBackground(Color.clear)
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background { store.dominantBackgroundColor.ignoresSafeArea() }
        .navigationTitle("Genres")
        .navigationDestination(for: Genre.self) { genre in
            GenreDetailView(genre: genre)
        }
        .task {
            await loadGenres()
        }
    }

    private func loadGenres(force: Bool = false) async {
        guard force || genres.isEmpty else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let result = try await NavidromeClient.shared.getGenres()
            genres = result.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            if genres.isEmpty {
                errorMessage = "No genres found. Your music files may not have genre tags."
            }
        } catch {
            errorMessage = "Could not load genres.\n\(error.localizedDescription)"
        }
    }
}
