import AVFoundation
import MediaPlayer

enum Repeat { case off, all, one }

final class Player: ObservableObject {
    @Published var tracks: [Track] = []
    @Published var current: Track?
    @Published var queue: [Track] = []
    @Published var isPlaying = false
    @Published var position = 0.0
    @Published var volume = 0.6
    @Published var shuffle = false
    @Published var repeatMode: Repeat = .off
    @Published var account = false

    private let ap = AVPlayer()

    init() {
        try? AVAudioSession.sharedInstance().setCategory(.playback)
        try? AVAudioSession.sharedInstance().setActive(true)
        ap.volume = Float(volume)
        ap.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.5, preferredTimescale: 600), queue: .main) { [weak self] t in
            guard let self = self, self.isPlaying else { return }
            self.position = t.seconds
            if Int(t.seconds) % 5 == 0 { self.updateNowPlaying() }
        }
        NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: nil, queue: .main) { [weak self] _ in
            self?.ended()
        }
        let rc = MPRemoteCommandCenter.shared()
        rc.playCommand.addTarget { [weak self] _ in self?.setPlaying(true); return .success }
        rc.pauseCommand.addTarget { [weak self] _ in self?.setPlaying(false); return .success }
        rc.nextTrackCommand.addTarget { [weak self] _ in self?.next(); return .success }
        rc.previousTrackCommand.addTarget { [weak self] _ in self?.prev(); return .success }
        rc.changePlaybackPositionCommand.addTarget { [weak self] e in
            if let e = e as? MPChangePlaybackPositionCommandEvent { self?.seek(to: e.positionTime) }
            return .success
        }
        let ud = UserDefaults.standard
        if let b = ud.string(forKey: "ovkBase"), let t = ud.string(forKey: "ovkToken") {
            Task { _ = await connect(base: b, user: "", pass: "", token: t) }
        }
    }

    // nil = успех, иначе текст ошибки
    func connect(base: String, user: String, pass: String, token: String) async -> String? {
        let b = base.trimmingCharacters(in: .whitespaces)
        guard let url = URL(string: b.isEmpty ? "https://ovk.to" : b) else { return "Неверный адрес сервера" }
        do {
            var tok = token.trimmingCharacters(in: .whitespaces)
            if tok.isEmpty { tok = try await OpenVKAPI.login(base: url, user: user, pass: pass) }
            let list = try await OpenVKAPI(base: url, token: tok).audios()
            if list.isEmpty { return "В аккаунте нет аудио со ссылками" }
            UserDefaults.standard.set(url.absoluteString, forKey: "ovkBase")
            UserDefaults.standard.set(tok, forKey: "ovkToken")
            await MainActor.run {
                self.tracks = list
                self.account = true
                if self.current == nil {
                    self.current = list[0]
                    self.queue = list
                    self.ap.replaceCurrentItem(with: AVPlayerItem(url: list[0].url))
                }
            }
            return nil
        } catch {
            return error.localizedDescription
        }
    }

    func play(_ t: Track, queue q: [Track]) { queue = q; start(t) }

    private func start(_ t: Track) {
        current = t
        position = 0
        ap.replaceCurrentItem(with: AVPlayerItem(url: t.url))
        ap.volume = Float(volume)
        ap.play()
        isPlaying = true
        updateNowPlaying()
    }

    func setPlaying(_ on: Bool) {
        guard current != nil else { return }
        if on { ap.play() } else { ap.pause() }
        isPlaying = on
        updateNowPlaying()
    }
    func toggle() { setPlaying(!isPlaying) }

    func next(auto: Bool = false) {
        guard let c = current, let i = queue.firstIndex(of: c) else { return }
        if shuffle && queue.count > 1 {
            var t = queue.randomElement()!
            while t == c { t = queue.randomElement()! }
            start(t)
        } else if i + 1 < queue.count {
            start(queue[i + 1])
        } else if repeatMode == .all {
            start(queue[0])
        } else {
            setPlaying(false)
            seek(to: 0)
        }
    }

    func prev() {
        guard let c = current, let i = queue.firstIndex(of: c) else { return }
        if position > 3 || i == 0 { seek(to: 0) } else { start(queue[i - 1]) }
    }

    func seek(to s: Double) {
        let t = max(0, s)
        ap.seek(to: CMTime(seconds: t, preferredTimescale: 600))
        position = t
    }
    func seekBy(_ d: Double) {
        let dur = Double(current?.duration ?? 0)
        seek(to: min(max(0, position + d), max(0, dur - 1)))
    }
    func setVolume(_ v: Double) {
        volume = min(1, max(0, v))
        ap.volume = Float(volume)
    }

    private func ended() {
        if repeatMode == .one { seek(to: 0); ap.play() } else { next(auto: true) }
    }

    private func updateNowPlaying() {
        guard let t = current else { return }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = [
            MPMediaItemPropertyTitle: t.title,
            MPMediaItemPropertyArtist: t.artist,
            MPMediaItemPropertyAlbumTitle: t.album,
            MPMediaItemPropertyPlaybackDuration: Double(t.duration),
            MPNowPlayingInfoPropertyElapsedPlaybackTime: position,
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? 1.0 : 0.0
        ]
    }
}
