import AVFoundation
import Combine
import MediaPlayer

/// Wraps AVPlayer for streaming audio playback with background audio
/// and lock-screen / Control Center integration.
nonisolated final class AudioPlayer: ObservableObject {
    private var player = AVPlayer()
    private var timeObserver: Any?
    private var endObserver: NSObjectProtocol?
    private var statusObservation: NSKeyValueObservation?
    private var itemStatusObservation: NSKeyValueObservation?

    @Published var currentTime: Double = 0
    @Published var isPlaying: Bool = false

    var onTrackEnd: (() -> Void)?

    // Callbacks wired by SyncStore for remote commands
    var onRemotePlay: (() -> Void)?
    var onRemotePause: (() -> Void)?
    var onRemoteNext: (() -> Void)?
    var onRemotePrev: (() -> Void)?
    var onRemoteSeek: ((Double) -> Void)?

    init() {
        setupAudioSession()
        setupTimeObserver()
        setupEndObserver()
        setupStatusObservation()
        setupRemoteCommands()
    }

    deinit {
        if let timeObserver { player.removeTimeObserver(timeObserver) }
        if let endObserver { NotificationCenter.default.removeObserver(endObserver) }
        statusObservation?.invalidate()
        itemStatusObservation?.invalidate()
    }

    // MARK: - Audio session

    private func setupAudioSession() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .default)
        try? session.setActive(true)
    }

    // MARK: - Observers

    private func setupTimeObserver() {
        let interval = CMTime(seconds: 1, preferredTimescale: 1)
        timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            self?.currentTime = time.seconds.isNaN ? 0 : time.seconds
        }
    }

    private func setupEndObserver() {
        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let item = notification.object as? AVPlayerItem,
                  item == self?.player.currentItem else { return }
            self?.onTrackEnd?()
        }
    }

    private func setupStatusObservation() {
        statusObservation = player.observe(\.timeControlStatus, options: [.new]) { [weak self] player, _ in
            DispatchQueue.main.async {
                self?.isPlaying = player.timeControlStatus == .playing
            }
        }
    }

    // MARK: - Remote command center (lock screen / Control Center)

    private func setupRemoteCommands() {
        let center = MPRemoteCommandCenter.shared()

        center.playCommand.isEnabled = true
        center.playCommand.addTarget { [weak self] _ in
            self?.onRemotePlay?()
            return .success
        }

        center.pauseCommand.isEnabled = true
        center.pauseCommand.addTarget { [weak self] _ in
            self?.onRemotePause?()
            return .success
        }

        center.nextTrackCommand.isEnabled = true
        center.nextTrackCommand.addTarget { [weak self] _ in
            self?.onRemoteNext?()
            return .success
        }

        center.previousTrackCommand.isEnabled = true
        center.previousTrackCommand.addTarget { [weak self] _ in
            self?.onRemotePrev?()
            return .success
        }

        center.changePlaybackPositionCommand.isEnabled = true
        center.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let posEvent = event as? MPChangePlaybackPositionCommandEvent else { return .commandFailed }
            self?.onRemoteSeek?(posEvent.positionTime)
            return .success
        }
    }

    // MARK: - Playback controls

    func play(url: URL, position: Double = 0) {
        itemStatusObservation?.invalidate()
        let item = AVPlayerItem(url: url)
        player.replaceCurrentItem(with: item)
        
        itemStatusObservation = item.observe(\.status, options: [.new]) { [weak self] observedItem, _ in
            if observedItem.status == .readyToPlay {
                if position > 0 {
                    self?.seek(to: position)
                }
                self?.player.play()
            }
        }
    }

    func resume() {
        player.play()
    }

    func pause() {
        player.pause()
    }

    func stop() {
        player.pause()
        player.replaceCurrentItem(with: nil)
        currentTime = 0
    }

    func seek(to seconds: Double) {
        let time = CMTime(seconds: seconds, preferredTimescale: 1)
        player.seek(to: time)
    }

    // MARK: - Now Playing info (lock screen metadata)

    func updateNowPlayingInfo(title: String, artist: String, album: String, duration: Double, position: Double, artwork: UIImage? = nil) {
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: title,
            MPMediaItemPropertyArtist: artist,
            MPMediaItemPropertyAlbumTitle: album,
            MPMediaItemPropertyPlaybackDuration: duration,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: position,
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? 1.0 : 0.0,
        ]
        if let artwork {
            info[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(boundsSize: artwork.size) { _ in artwork }
        }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }
}
