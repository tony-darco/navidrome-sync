import SwiftUI

struct DownloadsView: View {
    @EnvironmentObject private var downloadManager: DownloadManager
    @EnvironmentObject private var store: SyncStore
    @State private var showRemoveAllAlert = false

    private var activeTasks: [DownloadTask] {
        downloadManager.taskMap.values
            .filter { $0.isActive || isPending($0) }
            .sorted { $0.createdAt < $1.createdAt }
    }

    private var completedTasks: [DownloadTask] {
        downloadManager.taskMap.values
            .filter(\.isCompleted)
            .sorted { $0.createdAt > $1.createdAt }
    }

    private var failedTasks: [DownloadTask] {
        downloadManager.taskMap.values
            .filter { if case .failed = $0.status { return true }; return false }
            .sorted { $0.createdAt > $1.createdAt }
    }

    private var pausedTasks: [DownloadTask] {
        downloadManager.taskMap.values
            .filter { if case .paused = $0.status { return true }; return false }
            .sorted { $0.createdAt > $1.createdAt }
    }

    var body: some View {
        List {
            if activeTasks.isEmpty && completedTasks.isEmpty && failedTasks.isEmpty && pausedTasks.isEmpty {
                Section {
                    Text("No downloads")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .listRowBackground(Color.clear)
                }
            }

            if !activeTasks.isEmpty {
                Section("Downloading") {
                    ForEach(activeTasks) { task in
                        downloadRow(task)
                            .listRowBackground(Color.clear)
                    }
                }
            }

            if !pausedTasks.isEmpty {
                Section("Paused") {
                    ForEach(pausedTasks) { task in
                        downloadRow(task)
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    downloadManager.cancel(songId: task.songId)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                                Button {
                                    downloadManager.resume(songId: task.songId)
                                } label: {
                                    Label("Resume", systemImage: "play.fill")
                                }
                                .tint(.blue)
                            }
                            .listRowBackground(Color.clear)
                    }
                }
            }

            if !failedTasks.isEmpty {
                Section("Failed") {
                    ForEach(failedTasks) { task in
                        HStack {
                            downloadRow(task)
                            Spacer()
                            Button {
                                downloadManager.retryFailed(songId: task.songId)
                            } label: {
                                Text("Retry")
                                    .font(.caption)
                                    .foregroundStyle(.blue)
                            }
                            .buttonStyle(.plain)
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                downloadManager.cancel(songId: task.songId)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                        .listRowBackground(Color.clear)
                    }
                }
            }

            if !completedTasks.isEmpty {
                Section("Completed (\(completedTasks.count))") {
                    ForEach(completedTasks) { task in
                        downloadRow(task)
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    downloadManager.remove(songId: task.songId)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                            .listRowBackground(Color.clear)
                    }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .miniPlayerScrollObserver()
        .background { store.dominantBackgroundColor.ignoresSafeArea() }
        .navigationTitle("Downloads")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    if activeTasks.isEmpty && !pausedTasks.isEmpty {
                        Button {
                            for task in pausedTasks {
                                downloadManager.resume(songId: task.songId)
                            }
                        } label: {
                            Label("Resume All", systemImage: "play.fill")
                        }
                    }
                    if !activeTasks.isEmpty {
                        Button {
                            for task in activeTasks {
                                downloadManager.pause(songId: task.songId)
                            }
                        } label: {
                            Label("Pause All", systemImage: "pause.fill")
                        }
                    }
                    if !failedTasks.isEmpty {
                        Button {
                            for task in failedTasks {
                                downloadManager.retryFailed(songId: task.songId)
                            }
                        } label: {
                            Label("Retry All Failed", systemImage: "arrow.clockwise")
                        }
                    }
                    if !downloadManager.taskMap.isEmpty {
                        Button(role: .destructive) {
                            showRemoveAllAlert = true
                        } label: {
                            Label("Remove All", systemImage: "trash")
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .disabled(downloadManager.taskMap.isEmpty)
            }
        }
        .alert("Remove All Downloads?", isPresented: $showRemoveAllAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Remove All", role: .destructive) {
                downloadManager.removeAll()
            }
        } message: {
            Text("This will delete all downloaded files.")
        }
    }

    // MARK: - Row

    private func downloadRow(_ task: DownloadTask) -> some View {
        let isNowPlaying = task.songId == store.nowPlaying?.songId
        return HStack(spacing: 12) {
            CoverArtImage(id: task.coverArt, size: 80, isNowPlaying: isNowPlaying, isPlaying: store.isPlaying)
                .frame(width: 40, height: 40)
                .clipShape(RoundedRectangle(cornerRadius: 4))

            VStack(alignment: .leading, spacing: 2) {
                Text(task.title)
                    .font(.body)
                    .lineLimit(1)
                HStack(spacing: 4) {
                    Text(task.artist)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    if let bytes = task.totalBytes, task.isCompleted {
                        Text("·")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(formatBytes(bytes))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer()

            DownloadStatusIcon(task: task)
        }
    }

    // MARK: - Helpers

    private func isPending(_ task: DownloadTask) -> Bool {
        if case .pending = task.status { return true }
        return false
    }

    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}
