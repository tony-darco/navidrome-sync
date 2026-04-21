import Combine
import Foundation

@MainActor
protocol DownloadManaging: AnyObject {
    func enqueueIfAutoCache(song: NowPlayingSong)
    func isDownloaded(songId: String) -> Bool
    func localURL(for songId: String) -> URL?
}

/// Manages song downloads using a background URLSession.
/// Files are stored in Documents/Downloads/Songs/{songId}.{ext}.
/// Metadata is persisted to Documents/Downloads/metadata.json.
@MainActor
final class DownloadManager: NSObject, ObservableObject, DownloadManaging {

    nonisolated let objectWillChange = ObservableObjectPublisher()

    static let shared = DownloadManager()

    // MARK: - Published state

    /// Keyed by songId — views subscribe per-entry to avoid full-list re-renders.
    @Published private(set) var taskMap: [String: DownloadTask] = [:]

    /// Set of completed songIds for O(1) offline-mode filtering.
    @Published private(set) var completedDownloads: Set<String> = []

    /// Set by AppDelegate when iOS delivers background session events.
    @MainActor
    var backgroundCompletionHandler: (() -> Void)?

    // MARK: - Private

    /// Maps URLSessionTask.taskIdentifier → songId for delegate callbacks.
    private var taskIdentifierToSongId: [Int: String] = [:]

    /// Tracks last progress publish time per songId for throttling.
    private var lastProgressUpdate: [String: Date] = [:]

    /// Maximum number of concurrent downloads.
    private let maxConcurrent = 3

    /// Minimum disk space required to enqueue a download (50 MB).
    private let minimumDiskSpace: Int64 = 50 * 1024 * 1024

    /// Debounce timer for metadata persistence.
    private var persistTimer: Timer?

    private let navidromeClient: NavidromeClientProtocol
    private let sessionConfiguration: URLSessionConfiguration

    private lazy var backgroundSession: URLSession = {
        return URLSession(configuration: sessionConfiguration, delegate: self, delegateQueue: nil)
    }()

    // MARK: - Directories

    private let downloadsDirectory: URL = {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir = docs.appendingPathComponent("Downloads/Songs", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    private var metadataURL: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent("Downloads/metadata.json")
    }

    // MARK: - Init

    init(
        sessionConfiguration: URLSessionConfiguration = {
            let config = URLSessionConfiguration.background(withIdentifier: "com.navidromesync.downloads")
            config.isDiscretionary = false
            config.sessionSendsLaunchEvents = true
            return config
        }(),
        navidromeClient: NavidromeClientProtocol = NavidromeClient.shared
    ) {
        self.sessionConfiguration = sessionConfiguration
        self.navidromeClient = navidromeClient
        super.init()
        restoreState()
        // Touch the lazy session so iOS can reconnect after relaunch.
        _ = backgroundSession
    }

    // MARK: - Public API

    func download(song: Song, isAutoCache: Bool = false) {
        guard taskMap[song.id] == nil else { return }
        guard checkDiskSpace() else {
            var task = DownloadTask(song: song, isAutoCache: isAutoCache)
            task.status = .failed(reason: .insufficientStorage, attempts: 0)
            taskMap[song.id] = task
            schedulePersist()
            return
        }
        let task = DownloadTask(song: song, isAutoCache: isAutoCache)
        taskMap[song.id] = task
        schedulePersist()
        startNextIfNeeded()
    }

    func download(songs: [Song], isAutoCache: Bool = false) {
        for song in songs {
            download(song: song, isAutoCache: isAutoCache)
        }
    }

    /// Called by SyncStore at scrobble time.
    func enqueueIfAutoCache(song: NowPlayingSong) {
        guard AppConfig.autoCacheEnabled else { return }
        guard taskMap[song.songId] == nil else { return }
        guard checkDiskSpace() else { return }
        let task = DownloadTask(nowPlayingSong: song, isAutoCache: true)
        taskMap[song.songId] = task
        schedulePersist()
        evictAutoCacheIfNeeded()
        startNextIfNeeded()
    }

    func cancel(songId: String) {
        guard let task = taskMap[songId] else { return }
        // Cancel the URLSession task if active
        if task.isActive {
            cancelURLSessionTask(for: songId)
        }
        // Remove the file if it exists
        removeFile(for: songId)
        taskMap.removeValue(forKey: songId)
        completedDownloads.remove(songId)
        schedulePersist()
        startNextIfNeeded()
    }

    func pause(songId: String) {
        guard var task = taskMap[songId], task.isActive else { return }
        cancelURLSessionTask(for: songId)
        task.status = .paused
        taskMap[songId] = task
        schedulePersist()
        startNextIfNeeded()
    }

    func resume(songId: String) {
        guard var task = taskMap[songId] else { return }
        if case .paused = task.status {
            task.status = .pending
            taskMap[songId] = task
            schedulePersist()
            startNextIfNeeded()
        }
    }

    func remove(songId: String) {
        removeFile(for: songId)
        taskMap.removeValue(forKey: songId)
        completedDownloads.remove(songId)
        schedulePersist()
    }

    func removeAll() {
        for songId in taskMap.keys {
            cancelURLSessionTask(for: songId)
            removeFile(for: songId)
        }
        taskMap.removeAll()
        completedDownloads.removeAll()
        taskIdentifierToSongId.removeAll()
        lastProgressUpdate.removeAll()
        schedulePersist()
    }

    func retryFailed(songId: String) {
        guard var task = taskMap[songId] else { return }
        if case .failed = task.status {
            task.status = .pending
            task.attempts = 0
            taskMap[songId] = task
            schedulePersist()
            startNextIfNeeded()
        }
    }

    func isDownloaded(songId: String) -> Bool {
        completedDownloads.contains(songId)
    }

    func localURL(for songId: String) -> URL? {
        guard let task = taskMap[songId],
              task.isCompleted,
              let ext = task.fileExtension else { return nil }
        let url = downloadsDirectory.appendingPathComponent(songId).appendingPathExtension(ext)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    /// Total bytes used by completed downloads.
    var totalStorageUsed: Int64 {
        taskMap.values
            .filter(\.isCompleted)
            .compactMap(\.totalBytes)
            .reduce(0, +)
    }

    /// Number of actively downloading tasks.
    var activeCount: Int {
        taskMap.values.filter(\.isActive).count
    }

    // MARK: - Start downloads

    private func startNextIfNeeded() {
        let active = taskMap.values.filter(\.isActive).count
        guard active < maxConcurrent else { return }

        let pending = taskMap.values
            .filter { if case .pending = $0.status { return true }; return false }
            .sorted { $0.createdAt < $1.createdAt }

        let slotsAvailable = maxConcurrent - active
        for task in pending.prefix(slotsAvailable) {
            startDownload(for: task.songId)
        }
    }

    private func startDownload(for songId: String) {
        guard var task = taskMap[songId] else { return }
        guard let url = navidromeClient.streamURL(songId: songId) else {
            task.status = .failed(reason: .permanent(statusCode: nil), attempts: task.attempts + 1)
            taskMap[songId] = task
            schedulePersist()
            return
        }

        task.status = .downloading(progress: 0)
        taskMap[songId] = task
        schedulePersist()

        let downloadTask = backgroundSession.downloadTask(with: url)
        downloadTask.taskDescription = songId
        taskIdentifierToSongId[downloadTask.taskIdentifier] = songId
        downloadTask.resume()
    }

    // MARK: - Error classification & retry

    private func classifyFailure(error: Error?, response: URLResponse?) -> FailureReason {
        if let http = response as? HTTPURLResponse {
            switch http.statusCode {
            case 400...499:
                return .permanent(statusCode: http.statusCode)
            case 500...599:
                return .transient(statusCode: http.statusCode)
            default:
                break
            }
        }

        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet, .networkConnectionLost, .timedOut,
                 .cannotFindHost, .cannotConnectToHost, .dnsLookupFailed:
                return .transient(statusCode: nil)
            default:
                return .permanent(statusCode: nil)
            }
        }

        return .transient(statusCode: nil)
    }

    private func handleFailure(songId: String, error: Error?, response: URLResponse?) {
        guard var task = taskMap[songId] else { return }
        let attempts = task.attempts + 1
        let reason = classifyFailure(error: error, response: response)

        switch reason {
        case .transient where attempts < 3:
            task.attempts = attempts
            task.status = .pending
            taskMap[songId] = task
            schedulePersist()
            let delay = pow(2.0, Double(attempts))
            Task {
                try? await Task.sleep(for: .seconds(delay))
                startNextIfNeeded()
            }
        default:
            task.attempts = attempts
            task.status = .failed(reason: reason, attempts: attempts)
            taskMap[songId] = task
            schedulePersist()
            startNextIfNeeded()
        }
    }

    // MARK: - File management

    private func removeFile(for songId: String) {
        guard let task = taskMap[songId], let ext = task.fileExtension else { return }
        let url = downloadsDirectory.appendingPathComponent(songId).appendingPathExtension(ext)
        try? FileManager.default.removeItem(at: url)
    }

    private func cancelURLSessionTask(for songId: String) {
        if let entry = taskIdentifierToSongId.first(where: { $0.value == songId }) {
            backgroundSession.getAllTasks { tasks in
                tasks.first { $0.taskIdentifier == entry.key }?.cancel()
            }
            taskIdentifierToSongId.removeValue(forKey: entry.key)
        }
    }

    // MARK: - MIME → extension

    nonisolated private static func fileExtension(forMIMEType mime: String) -> String {
        switch mime.lowercased() {
        case "audio/flac", "audio/x-flac": return "flac"
        case "audio/mpeg", "audio/mp3": return "mp3"
        case "audio/aac", "audio/x-aac": return "aac"
        case "audio/mp4", "audio/x-m4a": return "m4a"
        case "audio/ogg", "audio/vorbis": return "ogg"
        case "audio/opus": return "opus"
        case "audio/wav", "audio/x-wav": return "wav"
        case "audio/x-alac": return "m4a"
        default: return "mp3"
        }
    }

    // MARK: - Disk space check

    private func checkDiskSpace() -> Bool {
        guard let attrs = try? FileManager.default.attributesOfFileSystem(
            forPath: downloadsDirectory.path
        ), let freeSpace = attrs[.systemFreeSize] as? Int64 else {
            return true // can't determine, allow
        }
        return freeSpace > minimumDiskSpace
    }

    // MARK: - Auto-cache eviction

    private func evictAutoCacheIfNeeded() {
        let maxSize = AppConfig.maxCacheSize
        guard maxSize > 0 else { return } // 0 = unlimited

        var autoCachedCompleted = taskMap.values
            .filter { $0.isAutoCache && $0.isCompleted }
            .sorted { $0.createdAt < $1.createdAt }

        var used = totalStorageUsed
        while used > maxSize, let oldest = autoCachedCompleted.first {
            remove(songId: oldest.songId)
            autoCachedCompleted.removeFirst()
            used = totalStorageUsed
        }
    }

    // MARK: - Persistence

    private func schedulePersist() {
        persistTimer?.invalidate()
        persistTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.persistState()
            }
        }
    }

    private func persistState() {
        do {
            let data = try JSONEncoder().encode(taskMap)
            try data.write(to: metadataURL, options: .atomic)
        } catch {
            print("[DownloadManager] Failed to persist state: \(error)")
        }
    }

    private func restoreState() {
        guard FileManager.default.fileExists(atPath: metadataURL.path) else { return }
        do {
            let data = try Data(contentsOf: metadataURL)
            taskMap = try JSONDecoder().decode([String: DownloadTask].self, from: data)
            completedDownloads = Set(taskMap.values.filter(\.isCompleted).map(\.songId))

            // Reset any in-progress downloads to pending (they'll restart).
            for (songId, var task) in taskMap {
                if case .downloading = task.status {
                    task.status = .pending
                    taskMap[songId] = task
                }
            }
        } catch {
            print("[DownloadManager] Failed to restore state: \(error)")
        }
    }
}

// MARK: - URLSessionDownloadDelegate

extension DownloadManager: URLSessionDownloadDelegate {

    nonisolated func urlSession(_ session: URLSession,
                                downloadTask: URLSessionDownloadTask,
                                didFinishDownloadingTo location: URL) {
        let songId = downloadTask.taskDescription ?? ""
        let mimeType = downloadTask.response?.mimeType ?? "audio/mpeg"
        let ext = Self.fileExtension(forMIMEType: mimeType)
        let totalBytes = downloadTask.countOfBytesReceived

        let destination = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Downloads/Songs", isDirectory: true)
            .appendingPathComponent(songId)
            .appendingPathExtension(ext)

        do {
            // Remove existing file if any (e.g. retry with different extension).
            if FileManager.default.fileExists(atPath: destination.path) {
                try FileManager.default.removeItem(at: destination)
            }
            try FileManager.default.moveItem(at: location, to: destination)
        } catch {
            print("[DownloadManager] Failed to move file: \(error)")
            Task { @MainActor in
                self.handleFailure(songId: songId, error: error, response: nil)
            }
            return
        }

        Task { @MainActor in
            guard var task = self.taskMap[songId] else { return }
            task.status = .completed
            task.fileExtension = ext
            task.totalBytes = totalBytes
            self.taskMap[songId] = task
            self.completedDownloads.insert(songId)
            self.taskIdentifierToSongId.removeValue(forKey: downloadTask.taskIdentifier)
            self.lastProgressUpdate.removeValue(forKey: songId)
            self.schedulePersist()
            self.startNextIfNeeded()
        }
    }

    nonisolated func urlSession(_ session: URLSession,
                                downloadTask: URLSessionDownloadTask,
                                didWriteData bytesWritten: Int64,
                                totalBytesWritten: Int64,
                                totalBytesExpectedToWrite: Int64) {
        let songId = downloadTask.taskDescription ?? ""
        guard totalBytesExpectedToWrite > 0 else { return }
        let progress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)

        Task { @MainActor in
            // Throttle: only publish if >1% change or >0.5s since last update.
            let now = Date()
            let lastUpdate = self.lastProgressUpdate[songId]
            let currentProgress = self.taskMap[songId]?.progress ?? 0

            let enoughProgressDelta = (progress - currentProgress) >= 0.01
            let enoughTimeDelta = lastUpdate == nil || now.timeIntervalSince(lastUpdate!) >= 0.5

            guard enoughProgressDelta || enoughTimeDelta else { return }

            self.lastProgressUpdate[songId] = now
            if var task = self.taskMap[songId] {
                task.status = .downloading(progress: progress)
                task.totalBytes = totalBytesWritten
                self.taskMap[songId] = task
            }
        }
    }

    nonisolated func urlSession(_ session: URLSession,
                                task: URLSessionTask,
                                didCompleteWithError error: Error?) {
        guard let error else { return }
        // Cancellation is intentional — not a failure.
        if (error as? URLError)?.code == .cancelled { return }
        let songId = task.taskDescription ?? ""
        Task { @MainActor in
            self.taskIdentifierToSongId.removeValue(forKey: task.taskIdentifier)
            self.handleFailure(songId: songId, error: error, response: task.response)
        }
    }

    nonisolated func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        Task { @MainActor in
            self.backgroundCompletionHandler?()
            self.backgroundCompletionHandler = nil
        }
    }
}
