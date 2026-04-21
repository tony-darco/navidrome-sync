import Testing
import Foundation
@testable import navidrome_ios

// MARK: - DownloadStatus

@Suite("DownloadStatus Codable")
struct DownloadStatusTests {

    @Test("All status cases survive encode → decode")
    func allCasesRoundTrip() throws {
        let cases: [DownloadStatus] = [
            .pending,
            .downloading(progress: 0.45),
            .paused,
            .failed(reason: .transient(statusCode: 503), attempts: 3),
            .failed(reason: .permanent(statusCode: 404), attempts: 1),
            .failed(reason: .insufficientStorage, attempts: 2),
            .completed,
        ]
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        for status in cases {
            let data = try encoder.encode(status)
            let decoded = try decoder.decode(DownloadStatus.self, from: data)
            #expect(decoded == status, "Round-trip failed for \(status)")
        }
    }

    @Test("downloading(progress: 0) encodes correctly")
    func downloadingZero() throws {
        let status = DownloadStatus.downloading(progress: 0)
        let data = try JSONEncoder().encode(status)
        let decoded = try JSONDecoder().decode(DownloadStatus.self, from: data)

        if case .downloading(let p) = decoded {
            #expect(p == 0)
        } else {
            Issue.record("Expected .downloading(0), got \(decoded)")
        }
    }

    @Test("downloading(progress: 1.0) encodes correctly")
    func downloadingComplete() throws {
        let status = DownloadStatus.downloading(progress: 1.0)
        let data = try JSONEncoder().encode(status)
        let decoded = try JSONDecoder().decode(DownloadStatus.self, from: data)

        if case .downloading(let p) = decoded {
            #expect(p == 1.0)
        } else {
            Issue.record("Expected .downloading(1.0), got \(decoded)")
        }
    }
}

// MARK: - FailureReason

@Suite("FailureReason Codable")
struct FailureReasonTests {

    @Test("All failure reasons survive round-trip")
    func allCasesRoundTrip() throws {
        let cases: [FailureReason] = [
            .transient(statusCode: 500),
            .transient(statusCode: nil),
            .permanent(statusCode: 404),
            .permanent(statusCode: nil),
            .insufficientStorage,
        ]
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        for reason in cases {
            let data = try encoder.encode(reason)
            let decoded = try decoder.decode(FailureReason.self, from: data)
            #expect(decoded == reason, "Round-trip failed for \(reason)")
        }
    }
}

// MARK: - DownloadTask

@Suite("DownloadTask")
struct DownloadTaskTests {

    private func makeSong() -> Song {
        Song(
            id: "s-1", title: "Test Song", artist: "Artist",
            album: "Album", albumId: "al-1", artistId: "ar-1",
            coverArt: "ca-1", duration: 240, track: 1
        )
    }

    @Test("Init from Song sets correct defaults")
    func initFromSong() {
        let song = makeSong()
        let task = DownloadTask(song: song)

        #expect(task.songId == "s-1")
        #expect(task.title == "Test Song")
        #expect(task.artist == "Artist")
        #expect(task.album == "Album")
        #expect(task.albumId == "al-1")
        #expect(task.coverArt == "ca-1")
        #expect(task.status == .pending)
        #expect(task.attempts == 0)
        #expect(task.isAutoCache == false)
        #expect(task.isCompleted == false)
        #expect(task.isActive == false)
        #expect(task.progress == 0)
    }

    @Test("Init from NowPlayingSong sets correct defaults")
    func initFromNowPlayingSong() {
        let nps = NowPlayingSong(
            songId: "s-2", title: "NPS Song", artist: "A",
            album: "Al", albumId: "al-2", artistId: "ar-2",
            coverArtId: "ca-2", durationSecs: 100, positionSecs: 0
        )
        let task = DownloadTask(nowPlayingSong: nps, isAutoCache: true)

        #expect(task.songId == "s-2")
        #expect(task.albumId == "al-2")
        #expect(task.isAutoCache == true)
        #expect(task.status == .pending)
    }

    @Test("Init from NowPlayingSong with nil albumId uses fallback")
    func initNilAlbumId() {
        let nps = NowPlayingSong(
            songId: "s-3", title: "T", artist: "A",
            album: "Al", albumId: nil, artistId: nil,
            coverArtId: "ca", durationSecs: 60, positionSecs: 0
        )
        let task = DownloadTask(nowPlayingSong: nps)
        #expect(task.albumId == "Unknown Album ID")
    }

    @Test("Identifiable id is songId")
    func identifiable() {
        let task = DownloadTask(song: makeSong())
        #expect(task.id == "s-1")
    }

    @Test("Computed properties reflect status")
    func computedProperties() {
        var task = DownloadTask(song: makeSong())

        // pending
        #expect(task.isCompleted == false)
        #expect(task.isActive == false)
        #expect(task.progress == 0)

        // downloading
        task.status = .downloading(progress: 0.5)
        #expect(task.isCompleted == false)
        #expect(task.isActive == true)
        #expect(task.progress == 0.5)

        // completed
        task.status = .completed
        #expect(task.isCompleted == true)
        #expect(task.isActive == false)
        #expect(task.progress == 1.0)

        // failed
        task.status = .failed(reason: .transient(statusCode: 500), attempts: 1)
        #expect(task.isCompleted == false)
        #expect(task.isActive == false)
        #expect(task.progress == 0)

        // paused
        task.status = .paused
        #expect(task.isCompleted == false)
        #expect(task.isActive == false)
        #expect(task.progress == 0)
    }

    @Test("Encode → decode round-trip preserves all fields")
    func roundTrip() throws {
        var task = DownloadTask(song: makeSong())
        task.status = .downloading(progress: 0.75)
        task.fileExtension = "mp3"
        task.totalBytes = 5_000_000
        task.attempts = 2

        let data = try JSONEncoder().encode(task)
        let decoded = try JSONDecoder().decode(DownloadTask.self, from: data)

        #expect(decoded == task)
        #expect(decoded.songId == "s-1")
        #expect(decoded.fileExtension == "mp3")
        #expect(decoded.totalBytes == 5_000_000)
        #expect(decoded.attempts == 2)
    }

    @Test("Array of tasks round-trip (simulates metadata.json)")
    func arrayRoundTrip() throws {
        let song = makeSong()
        var task1 = DownloadTask(song: song)
        task1.status = .completed

        var task2 = DownloadTask(song: Song(
            id: "s-2", title: "Song 2", artist: "Artist 2",
            album: "Album 2", albumId: "al-2", coverArt: "ca-2",
            duration: 180, track: 2
        ))
        task2.status = .failed(reason: .transient(statusCode: 503), attempts: 3)

        let tasks = [task1, task2]
        let data = try JSONEncoder().encode(tasks)
        let decoded = try JSONDecoder().decode([DownloadTask].self, from: data)

        #expect(decoded.count == 2)
        #expect(decoded[0].isCompleted == true)
        #expect(decoded[1].status == .failed(reason: .transient(statusCode: 503), attempts: 3))
    }

    @Test("Edge: empty strings and zero duration")
    func edgeCaseEmptyFields() throws {
        let task = DownloadTask(song: Song(
            id: "s-empty", title: "", artist: "", album: "",
            albumId: "", coverArt: "", duration: 0, track: 0
        ))
        let data = try JSONEncoder().encode(task)
        let decoded = try JSONDecoder().decode(DownloadTask.self, from: data)

        #expect(decoded.title == "")
        #expect(decoded.artist == "")
    }

    @Test("Equatable: same tasks are equal")
    func equatable() {
        let a = DownloadTask(song: makeSong())
        let b = a
        #expect(a == b)
    }

    @Test("Equatable: different status makes tasks unequal")
    func equatableDifferentStatus() {
        var a = DownloadTask(song: makeSong())
        var b = a
        a.status = .pending
        b.status = .completed
        #expect(a != b)
    }
}
