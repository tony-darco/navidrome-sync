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
            Task { @MainActor in self?.next() }
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

    func playSong(_ song: NowPlayingSong) {
        if myRole != "active" {
            if isConnected {
                sendMessage(type: .claim)
            } else {
                becomeActiveLocally()
            }
        }
        queue = [song]
        queueIndex = 0
        loadAndPlay(song)
        if isConnected { sendNowPlaying(song) }
    }

    func playQueue(_ songs: [NowPlayingSong], startIndex: Int) {
        guard startIndex < songs.count else { return }
        if myRole != "active" {
            if isConnected {
                sendMessage(type: .claim)
            } else {
                becomeActiveLocally()
            }
        }
        queue = songs
        queueIndex = startIndex
        let song = songs[startIndex]
        loadAndPlay(song)
        if isConnected { sendNowPlaying(song) }
    }

    func play() {
        audioPlayer.resume()
        if isConnected { sendMessage(type: .play) }
    }

    func pause() {
        audioPlayer.pause()
        if isConnected { sendMessage(type: .pause) }
    }

    func seek(to positionSecs: Double) {
        audioPlayer.seek(to: positionSecs)
        position = positionSecs
        if isConnected { sendMessage(type: .seek, payload: SeekPayload(positionSecs: positionSecs)) }
    }

    func next() {
        let nextIndex = queueIndex + 1
        guard nextIndex < queue.count else { return }
        queueIndex = nextIndex
        let song = queue[nextIndex]
        if myRole != "active" {
            if isConnected {
                sendMessage(type: .claim)
            } else {
                becomeActiveLocally()
            }
        }
        loadAndPlay(song)
        if isConnected { sendNowPlaying(song) }
    }

    func prev() {
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
        if myRole != "active" {
            if isConnected {
                sendMessage(type: .claim)
            } else {
                becomeActiveLocally()
            }
        }
        loadAndPlay(song)
        if isConnected { sendNowPlaying(song) }
    }

    func claim() {
        if isConnected {
            sendMessage(type: .claim)
        } else {
            becomeActiveLocally()
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
        audioPlayer.play(url: url)
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
        case .roleChange:
            guard let payload = envelope.payload?.decode(RoleChangePayload.self) else { return }
            handleRoleChange(payload)
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
        activeClientId = payload.activeClientId
        connectedClients = payload.clients
        lastSyncTime = Date()

        // Determine our role from the clients list
        if let me = payload.clients.first(where: { $0.clientId == myClientId }) {
            myRole = me.role
        }

        // Update now playing from server state
        if let song = payload.song {
            nowPlaying = song
            if myRole == "observer" {
                position = song.positionSecs
                startInterpolation()
            }
        } else {
            nowPlaying = nil
            stopInterpolation()
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
        // Commands are echoed back to the active client — we handle them
        // so that external control (e.g., another client sending SEEK) works.
        switch payload.action {
        case "PLAY":
            audioPlayer.resume()
        case "PAUSE":
            audioPlayer.pause()
        case "SEEK":
            if let pos = payload.positionSecs {
                audioPlayer.seek(to: pos)
            }
        default:
            break
        }
    }
}
