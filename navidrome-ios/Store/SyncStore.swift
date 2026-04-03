import Combine
import Foundation
import UIKit

/// Single source of truth for the entire app.
/// Views never touch SyncClient directly — everything goes through the store.
@MainActor
final class SyncStore: ObservableObject {

    // MARK: - Published state

    @Published var nowPlaying: NowPlayingSong?
    @Published var myRole: String = "observer"
    @Published var myClientId: String
    @Published var activeClientId: String?
    @Published var connectedClients: [ConnectedClient] = []
    @Published var isConnected: Bool = false
    @Published var isPlaying: Bool = false
    @Published var position: Double = 0
    @Published var lastSyncTime: Date = .distantPast

    @Published var queue: [NowPlayingSong] = []
    @Published var queueIndex: Int = 0
    @Published var isShuffled: Bool = false
    @Published var repeatMode: RepeatMode = .off

    /// Stores the original (unshuffled) queue order.
    private var originalQueue: [NowPlayingSong] = []

    // MARK: - Private

    private let syncClient = SyncClient()
    let audioPlayer = AudioPlayer()
    private var positionReportingTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()
    private var interpolationTask: Task<Void, Never>?

    // MARK: - Init

    init() {
        myClientId = AppConfig.clientId
        setupBindings()
    }

    /// Wiring closures in a separate method so `self` is fully initialized
    /// and captured as a let-binding (avoids "captured var self" errors).
    private func setupBindings() {
        // Wire audio player state back into the store
        audioPlayer.$isPlaying
            .receive(on: RunLoop.main)
            .assign(to: &$isPlaying)

        audioPlayer.$currentTime
            .receive(on: RunLoop.main)
            .sink { [weak self] time in
                guard let self, self.myRole == "active" else { return }
                self.position = time
            }
            .store(in: &cancellables)

        audioPlayer.onTrackEnd = { [weak self] in
            Task { @MainActor in self?.handleTrackEnd() }
        }

        // Wire remote command center to store actions
        audioPlayer.onRemotePlay = { [weak self] in Task { @MainActor in self?.play() } }
        audioPlayer.onRemotePause = { [weak self] in Task { @MainActor in self?.pause() } }
        audioPlayer.onRemoteNext = { [weak self] in Task { @MainActor in self?.next() } }
        audioPlayer.onRemotePrev = { [weak self] in Task { @MainActor in self?.prev() } }
        audioPlayer.onRemoteSeek = { [weak self] pos in Task { @MainActor in self?.seek(to: pos) } }

        // WebSocket message handler
        syncClient.onMessage = { [weak self] envelope in
            Task { @MainActor in
                self?.handleMessage(envelope)
            }
        }
        syncClient.onConnected = { [weak self] in
            Task { @MainActor in self?.isConnected = true }
        }
        syncClient.onDisconnected = { [weak self] in
            Task { @MainActor in self?.isConnected = false }
        }


    }

    // MARK: - Connection

    /// Connect to the Go sync service. Only works if a sync service URL is configured
    /// (separate from the Navidrome server URL).
    func connect() {
        guard let base = AppConfig.syncServiceURL, !base.isEmpty else { return }
        syncClient.connect(baseURL: base, clientId: myClientId)
        startPositionReporting()
    }

    func disconnect() {
        syncClient.disconnect()
        stopPositionReporting()
        isConnected = false
    }

    // MARK: - Playback

    func playSong(_ song: NowPlayingSong, isCommand: Bool = false) {
        if myRole != "active" && !isCommand {
            if isConnected {
                let payload = PlaySongPayload(song: song)
                sendMessage(type: .playSong, payload: payload)
            } else {
                becomeActiveLocally()
                queue = [song]
                queueIndex = 0
                loadAndPlay(song)
            }
            return
        }
        queue = [song]
        queueIndex = 0
        loadAndPlay(song)
        if isConnected {
            sendNowPlaying(song)
            sendQueueToHub()
        }
    }

    func playQueue(_ songs: [NowPlayingSong], startIndex: Int, isCommand: Bool = false) {
        guard startIndex < songs.count else { return }
        if myRole != "active" && !isCommand {
            if isConnected {
                let payload = LoadQueuePayload(queue: songs, startIndex: startIndex)
                sendMessage(type: .loadQueue, payload: payload)
            } else {
                becomeActiveLocally()
                queue = songs
                queueIndex = startIndex
                loadAndPlay(songs[startIndex])
            }
            return
        }
        queue = songs
        queueIndex = startIndex
        let song = songs[startIndex]
        loadAndPlay(song)
        if isConnected {
            sendNowPlaying(song)
            sendQueueToHub()
        }
    }

    func play() {
        if myRole != "active" {
            if isConnected { sendMessage(type: .play) }
            return
        }
        audioPlayer.resume()
        if isConnected { sendMessage(type: .play) }
    }

    func pause() {
        if myRole != "active" {
            if isConnected { sendMessage(type: .pause) }
            return
        }
        audioPlayer.pause()
        if isConnected { sendMessage(type: .pause) }
    }

    func seek(to positionSecs: Double) {
        if myRole != "active" {
            if isConnected { sendMessage(type: .seek, payload: SeekPayload(positionSecs: positionSecs)) }
            return
        }
        audioPlayer.seek(to: positionSecs)
        position = positionSecs
        if isConnected { sendMessage(type: .seek, payload: SeekPayload(positionSecs: positionSecs)) }
    }

    func next(isCommand: Bool = false) {
        if myRole != "active" && !isCommand {
            if isConnected { sendMessage(type: .next) }
            return
        }
        
        let nextIndex = queueIndex + 1
        guard nextIndex < queue.count else {
            // If repeat all, wrap around to first track
            if repeatMode == .all && !queue.isEmpty {
                queueIndex = 0
                let song = queue[0]
                loadAndPlay(song)
                if isConnected {
                    sendNowPlaying(song)
                    sendQueueToHub()
                }
            }
            return
        }
        queueIndex = nextIndex
        let song = queue[nextIndex]
        loadAndPlay(song)
        if isConnected {
            sendNowPlaying(song)
            sendQueueToHub()
        }
    }

    func prev(isCommand: Bool = false) {
        if myRole != "active" && !isCommand {
            if isConnected { sendMessage(type: .prev) }
            return
        }
        
        // If more than 3s in, restart current track
        if audioPlayer.currentTime > 3 {
            audioPlayer.seek(to: 0)
            return
        }
        let prevIndex = queueIndex - 1
        guard prevIndex >= 0 else {
            audioPlayer.seek(to: 0)
            return
        }
        queueIndex = prevIndex
        let song = queue[prevIndex]
        loadAndPlay(song)
        if isConnected {
            sendNowPlaying(song)
            sendQueueToHub()
        }
    }

    func claim() {
        if isConnected {
            sendMessage(type: .claim)
        } else {
            becomeActiveLocally()
        }
    }

    func toggleShuffle() {
        isShuffled.toggle()
        if isShuffled {
            originalQueue = queue
            // Shuffle everything after the current index
            let currentSong = queue[queueIndex]
            var remaining = queue
            remaining.remove(at: queueIndex)
            remaining.shuffle()
            queue = [currentSong] + remaining
            queueIndex = 0
        } else {
            // Restore original order, keeping the current song's position
            let currentSong = queue[queueIndex]
            queue = originalQueue
            queueIndex = queue.firstIndex(where: { $0.songId == currentSong.songId }) ?? 0
            originalQueue = []
        }
        if isConnected {
            sendQueueToHub()
            sendPlaybackOptions()
        }
    }

    func toggleRepeat() {
        switch repeatMode {
        case .off: repeatMode = .all
        case .all: repeatMode = .one
        case .one: repeatMode = .off
        }
        if isConnected { sendPlaybackOptions() }
    }

    func clearQueue() {
        // Keep only the currently playing song
        if queueIndex < queue.count {
            let currentSong = queue[queueIndex]
            queue = [currentSong]
            queueIndex = 0
        }
        if isConnected { sendQueueToHub() }
    }

    /// Called when a track finishes playing.
    private func handleTrackEnd() {
        switch repeatMode {
        case .one:
            // Replay the same track
            if let song = nowPlaying {
                loadAndPlay(NowPlayingSong(
                    songId: song.songId, title: song.title, artist: song.artist,
                    album: song.album, coverArtId: song.coverArtId,
                    durationSecs: song.durationSecs, positionSecs: 0
                ))
            }
        case .all, .off:
            next()
        }
    }

    /// Become the active client locally without waiting for sync service confirmation.
    private func becomeActiveLocally() {
        myRole = "active"
        stopInterpolation()
        startPositionReporting()
    }

    // MARK: - Private helpers

    private func loadAndPlay(_ song: NowPlayingSong) {
        nowPlaying = song
        guard let url = NavidromeClient.shared.streamURL(songId: song.songId) else { return }
        audioPlayer.play(url: url, position: song.positionSecs)
        updateLockScreen(song: song)
    }

    private func updateLockScreen(song: NowPlayingSong) {
        audioPlayer.updateNowPlayingInfo(
            title: song.title,
            artist: song.artist,
            album: song.album,
            duration: Double(song.durationSecs),
            position: song.positionSecs
        )
    }

    // MARK: - WebSocket messaging

    private func sendMessage(type: MessageType, payload: (any Encodable)? = nil) {
        syncClient.send(type: type, payload: payload)
    }

    private func sendNowPlaying(_ song: NowPlayingSong) {
        let payload = NowPlayingPayload(
            songId: song.songId,
            title: song.title,
            artist: song.artist,
            album: song.album,
            coverArtId: song.coverArtId,
            durationSecs: song.durationSecs,
            positionSecs: song.positionSecs
        )
        sendMessage(type: .nowPlaying, payload: payload)
    }

    private func sendQueueToHub() {
        let items = queue.map {
            QueueItemPayload(
                songId: $0.songId,
                title: $0.title,
                artist: $0.artist,
                album: $0.album,
                coverArtId: $0.coverArtId,
                durationSecs: $0.durationSecs
            )
        }
        sendMessage(type: .setQueue, payload: SetQueuePayload(queue: items, queueIndex: queueIndex))
    }

    private func sendPlaybackOptions() {
        let modeString: String
        switch repeatMode {
        case .off: modeString = "off"
        case .all: modeString = "all"
        case .one: modeString = "one"
        }
        sendMessage(type: .setPlaybackOptions, payload: PlaybackOptionsPayload(shuffle: isShuffled, repeatMode: modeString))
    }

    // MARK: - Position reporting (active only, ~1s)

    private func startPositionReporting() {
        stopPositionReporting()
        positionReportingTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard myRole == "active", isPlaying else { continue }
                sendMessage(
                    type: .positionUpdate,
                    payload: PositionUpdatePayload(positionSecs: audioPlayer.currentTime)
                )
            }
        }
    }

    private func stopPositionReporting() {
        positionReportingTask?.cancel()
        positionReportingTask = nil
    }

    // MARK: - Observer interpolation

    private func startInterpolation() {
        stopInterpolation()
        interpolationTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard myRole == "observer", nowPlaying != nil else { continue }
                position += 1
            }
        }
    }

    private func stopInterpolation() {
        interpolationTask?.cancel()
        interpolationTask = nil
    }

    // MARK: - Incoming message routing

    private func handleMessage(_ envelope: SyncEnvelope) {
        switch envelope.type {
        case .stateSync:
            guard let payload = envelope.payload?.decode(StateSyncPayload.self) else { return }
            handleStateSync(payload)
        case .command:
            guard let payload = envelope.payload?.decode(CommandPayload.self) else { return }
            handleCommand(payload)
        case .error:
            if let payload = envelope.payload?.decode(ErrorPayload.self) {
                print("[sync] error \(payload.code): \(payload.message)")
            }
        default:
            break
        }
    }

    private func handleStateSync(_ payload: StateSyncPayload) {
        let previousRole = myRole
        activeClientId = payload.activeClientId
        connectedClients = payload.clients
        lastSyncTime = Date()

        // Determine our role from the clients list
        if let me = payload.clients.first(where: { $0.clientId == myClientId }) {
            myRole = me.role
        }

        // Active clients own the state. We don't overwrite local state with echoes
        // of our own messages, as it causes race conditions (e.g. going back and forth).
        let justBecameActive = (previousRole != "active" && myRole == "active")
        
        if myRole == "observer" || justBecameActive {
            // Accept queue from server
            if let serverQueue = payload.queue {
                queue = serverQueue.map { $0.toNowPlayingSong() }
                queueIndex = payload.queueIndex ?? 0
            }

            // Accept shuffle & repeat from server
            if let shuffle = payload.shuffle {
                isShuffled = shuffle
            }
            if let rm = payload.repeatMode {
                switch rm {
                case "all": repeatMode = .all
                case "one": repeatMode = .one
                default: repeatMode = .off
                }
            }
        }

        // Update now playing from server state
        if let song = payload.song {
            if myRole == "observer" || justBecameActive {
                nowPlaying = song
                if myRole == "observer" {
                    position = song.positionSecs
                    startInterpolation()
                }
            }
            
            // Auto-play when we just became active and there's a song
            if justBecameActive {
                loadAndPlay(song)
            }
        } else {
            if myRole == "observer" || justBecameActive {
                nowPlaying = nil
                stopInterpolation()
            }
        }
    }

    private func handleRoleChange(_ payload: RoleChangePayload) {
        guard payload.clientId == myClientId else { return }
        myRole = payload.role
        if payload.role == "observer" {
            stopPositionReporting()
            startInterpolation()
        } else {
            stopInterpolation()
            startPositionReporting()
        }
    }

    private func handleCommand(_ payload: CommandPayload) {
        switch payload.action {
        case "STOP":
            audioPlayer.stop()
        case "PLAY":
            audioPlayer.resume()
        case "PAUSE":
            audioPlayer.pause()
        case "SEEK":
            if let pos = payload.positionSecs {
                audioPlayer.seek(to: pos)
            }
        case "NEXT":
            next(isCommand: true)
        case "PREV":
            prev(isCommand: true)
        case "PLAY_SONG":
            if let songPayload = payload.song {
                let song = NowPlayingSong(
                    songId: songPayload.songId,
                    title: songPayload.title,
                    artist: songPayload.artist,
                    album: songPayload.album,
                    coverArtId: songPayload.coverArtId,
                    durationSecs: songPayload.durationSecs,
                    positionSecs: songPayload.positionSecs ?? 0.0
                )
                playSong(song, isCommand: true)
            }
        case "LOAD_QUEUE":
            if let q = payload.queue, let startIndex = payload.startIndex {
                let songs = q.map { $0.toNowPlayingSong() }
                playQueue(songs, startIndex: startIndex, isCommand: true)
            }
        default:
            break
        }
    }
}

// MARK: - Repeat mode

enum RepeatMode {
    case off, all, one
}
