import Foundation

// MARK: - DownloadStatus

nonisolated enum DownloadStatus: Codable, Sendable, Equatable {
    case pending
    case downloading(progress: Double)
    case paused
    case failed(reason: FailureReason, attempts: Int)
    case completed
}

// MARK: - FailureReason

nonisolated enum FailureReason: Codable, Sendable, Equatable {
    case transient(statusCode: Int?)
    case permanent(statusCode: Int?)
    case insufficientStorage
}

// MARK: - DownloadTask

nonisolated struct DownloadTask: Identifiable, Codable, Sendable, Equatable {
    let songId: String
    let title: String
    let artist: String
    let album: String
    let albumId: String
    let coverArt: String
    var status: DownloadStatus
    var fileExtension: String?
    var totalBytes: Int64?
    var attempts: Int
    var isAutoCache: Bool
    var createdAt: Date

    var id: String { songId }

    var isCompleted: Bool {
        if case .completed = status { return true }
        return false
    }

    var isActive: Bool {
        if case .downloading = status { return true }
        return false
    }

    var progress: Double {
        if case .downloading(let p) = status { return p }
        if case .completed = status { return 1.0 }
        return 0
    }
}

extension DownloadTask {
    init(song: Song, isAutoCache: Bool = false) {
        self.songId = song.id
        self.title = song.title
        self.artist = song.artist
        self.album = song.album
        self.albumId = song.albumId
        self.coverArt = song.coverArt
        self.status = .pending
        self.fileExtension = nil
        self.totalBytes = nil
        self.attempts = 0
        self.isAutoCache = isAutoCache
        self.createdAt = Date()
    }

    init(nowPlayingSong song: NowPlayingSong, isAutoCache: Bool = false) {
        self.songId = song.songId
        self.title = song.title
        self.artist = song.artist
        self.album = song.album
        self.albumId = song.albumId ?? "Unknown Album ID"
        self.coverArt = song.coverArtId
        self.status = .pending
        self.fileExtension = nil
        self.totalBytes = nil
        self.attempts = 0
        self.isAutoCache = isAutoCache
        self.createdAt = Date()
    }
}
