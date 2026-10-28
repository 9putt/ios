import Foundation
import AVFoundation
import MediaPlayer
import Combine
import WebKit

public class WinampPlayerEngine: ObservableObject {
    public static let shared = WinampPlayerEngine()

    // MARK: - Playback States
    @Published public var playlist: [TrackItem] = []
    @Published public var currentIndex: Int = 0
    @Published public var isPlaying: Bool = false
    @Published public var currentTime: TimeInterval = 0
    @Published public var duration: TimeInterval = 0
    @Published public var isTimeRemaining: Bool = false
    @Published public var volume: Double = 0.85
    @Published public var balance: Double = 0.0
    @Published public var isShuffle: Bool = false
    @Published public var isRepeat: Bool = false
    @Published public var isCrossfadeEnabled: Bool = true
    @Published public var crossfadeDuration: Double = 3.0 // 0s - 10s

    // Equalizer & Preamp
    @Published public var isEqEnabled: Bool = true
    @Published public var isEqAuto: Bool = false
    @Published public var preampGain: Float = 0.0
    @Published public var bandGains: [Float] = Array(repeating: 0.0, count: 10)
    @Published public var currentPreset: EqualizerPreset = .flat
    @Published public var isVocalRemoverActive: Bool = false

    // Real-Time Spectrum Analyzer Bars (16 bands)
    @Published public var spectrumBars: [Float] = Array(repeating: 0.0, count: 16)

    // Skin & Appearance
    @Published public var currentSkin: WinampSkinPreset = .classicModern
    @Published public var showEqualizerWindow: Bool = true
    @Published public var showPlaylistWindow: Bool = true
    @Published public var showYouTubeLoginSheet: Bool = false
    @Published public var showSkinPickerSheet: Bool = false
    @Published public var showCrossfadeSheet: Bool = false
    @Published public var showSearchSheet: Bool = false
    @Published public var showAddFilePicker: Bool = false
    @Published public var showAddFolderPicker: Bool = false

    // Web Player Reference
    public weak var webView: WKWebView?

    // Local Dual Audio Players for Seamless Crossfade
    private var localPlayerA: AVAudioPlayer?
    private var localPlayerB: AVAudioPlayer?
    private var isUsingPlayerA: Bool = true
    private var silencePlayer: AVAudioPlayer?
    private var timer: Timer?
    private var crossfadeTimer: Timer?
    private var cancellables = Set<AnyCancellable>()

    // Frequency labels matching Classic Winamp Equalizer
    public let bandFrequencies: [String] = ["70Hz", "180Hz", "320Hz", "600Hz", "1kHz", "3kHz", "6kHz", "12kHz", "14kHz", "16kHz"]

    public var currentTrack: TrackItem? {
        guard !playlist.isEmpty && currentIndex >= 0 && currentIndex < playlist.count else { return nil }
        return playlist[currentIndex]
    }

    private init() {
        setupAudioSession()
        setupRemoteCommandCenter()
        startBackgroundAudioKeeper()
        loadDefaultPlaylist()
        startPlaybackProgressTimer()
    }

    // MARK: - Audio Session Setup
    private func setupAudioSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, mode: .moviePlayback, options: [.mixWithOthers, .allowBluetooth, .allowBluetoothA2DP, .allowAirPlay])
            try session.setActive(true)
        } catch {
            print("[Winamp] Failed to activate AVAudioSession: \(error)")
        }
    }

    // MARK: - Background Audio Silence Keeper
    public func startBackgroundAudioKeeper() {
        guard let soundURL = Bundle.main.url(forResource: "silence", withExtension: "wav") else { return }
        do {
            silencePlayer = try AVAudioPlayer(contentsOf: soundURL)
            silencePlayer?.numberOfLoops = -1
            silencePlayer?.volume = 0.01
            silencePlayer?.prepareToPlay()
            silencePlayer?.play()
        } catch {
            print("[Winamp] Silence keeper error: \(error)")
        }
    }

    // MARK: - Initial Default Playlist
    private func loadDefaultPlaylist() {
        let introTrack = TrackItem(
            title: "Llama Whippin' Intro",
            artist: "DJ Mike Llama",
            duration: 5.0,
            urlString: "https://www.youtube.com/watch?v=dQw4w9WgXcQ",
            isLocal: false,
            videoId: "dQw4w9WgXcQ"
        )
        let sampleTrack1 = TrackItem(
            title: "Chill Lofi Music Mix",
            artist: "YouTube Music",
            duration: 215.0,
            urlString: "https://www.youtube.com/watch?v=jfKfPfyJRdk",
            isLocal: false,
            videoId: "jfKfPfyJRdk"
        )
        let sampleTrack2 = TrackItem(
            title: "Synthwave Radio",
            artist: "Retro Wave",
            duration: 240.0,
            urlString: "https://www.youtube.com/watch?v=4xDzrJKXOOY",
            isLocal: false,
            videoId: "4xDzrJKXOOY"
        )

        playlist = [introTrack, sampleTrack1, sampleTrack2]
        currentIndex = 0
    }

    // MARK: - Playback Controls
    public func playTrack(at index: Int) {
        guard index >= 0 && index < playlist.count else { return }
        currentIndex = index
        let track = playlist[index]
        currentTime = 0
        duration = track.duration > 0 ? track.duration : 180

        if track.isLocal {
            playLocalFile(urlString: track.urlString)
        } else {
            playYouTubeTrack(track: track)
        }

        isPlaying = true
        updateNowPlayingInfo()
    }

    public func togglePlayPause() {
        if isPlaying {
            pause()
        } else {
            resume()
        }
    }

    public func pause() {
        isPlaying = false
        if let track = currentTrack, track.isLocal {
            let activePlayer = isUsingPlayerA ? localPlayerA : localPlayerB
            activePlayer?.pause()
        } else {
            webView?.evaluateJavaScript("window.__winamp?.pause();", completionHandler: nil)
        }
        updateNowPlayingInfo()
    }

    public func resume() {
        isPlaying = true
        if let track = currentTrack, track.isLocal {
            let activePlayer = isUsingPlayerA ? localPlayerA : localPlayerB
            activePlayer?.play()
        } else {
            webView?.evaluateJavaScript("window.__winamp?.play();", completionHandler: nil)
        }
        updateNowPlayingInfo()
    }

    public func stop() {
        isPlaying = false
        currentTime = 0
        localPlayerA?.stop()
        localPlayerB?.stop()
        webView?.evaluateJavaScript("window.__winamp?.stop();", completionHandler: nil)
        updateNowPlayingInfo()
    }

    public func nextTrack() {
        guard !playlist.isEmpty else { return }
        var nextIdx = currentIndex + 1
        if isShuffle {
            nextIdx = Int.random(in: 0..<playlist.count)
        } else if nextIdx >= playlist.count {
            nextIdx = 0
        }
        playTrack(at: nextIdx)
    }

    public func previousTrack() {
        guard !playlist.isEmpty else { return }
        if currentTime > 3.0 {
            seek(to: 0)
            return
        }
        var prevIdx = currentIndex - 1
        if prevIdx < 0 {
            prevIdx = playlist.count - 1
        }
        playTrack(at: prevIdx)
    }

    public func seek(to time: TimeInterval) {
        currentTime = time
        if let track = currentTrack, track.isLocal {
            let activePlayer = isUsingPlayerA ? localPlayerA : localPlayerB
            activePlayer?.currentTime = time
        } else {
            webView?.evaluateJavaScript("window.__winamp?.seek(\(time));", completionHandler: nil)
        }
        updateNowPlayingInfo()
    }

    public func setVolume(_ newVolume: Double) {
        volume = max(0.0, min(1.0, newVolume))
        localPlayerA?.volume = Float(volume)
        localPlayerB?.volume = Float(volume)
        webView?.evaluateJavaScript("window.__winamp?.setVolume(\(volume));", completionHandler: nil)
    }

    public func setBalance(_ newBalance: Double) {
        balance = max(-1.0, min(1.0, newBalance))
        localPlayerA?.pan = Float(balance)
        localPlayerB?.pan = Float(balance)
        webView?.evaluateJavaScript("window.__winamp?.setPan(\(balance));", completionHandler: nil)
    }

    // MARK: - YouTube Playback & Crossfade
    private func playYouTubeTrack(track: TrackItem) {
        localPlayerA?.stop()
        localPlayerB?.stop()

        let vid = track.videoId ?? extractVideoID(from: track.urlString) ?? "dQw4w9WgXcQ"
        let fadeTime = isCrossfadeEnabled ? crossfadeDuration : 0.0

        let script = "window.__winamp?.loadVideo('\(vid)', \(fadeTime));"
        webView?.evaluateJavaScript(script, completionHandler: nil)
    }

    private func extractVideoID(from url: String) -> String? {
        if url.contains("v=") {
            let parts = url.components(separatedBy: "v=")
            if let idPart = parts.last?.components(separatedBy: "&").first {
                return idPart
            }
        } else if url.contains("youtu.be/") {
            let parts = url.components(separatedBy: "youtu.be/")
            if let idPart = parts.last?.components(separatedBy: "?").first {
                return idPart
            }
        }
        return nil
    }

    // MARK: - Local File Playback with Dual-Player Crossfade
    private func playLocalFile(urlString: String) {
        guard let url = URL(string: urlString) else { return }

        // Start accessing security-scoped resource if needed
        let hasAccess = url.startAccessingSecurityScopedResource()
        defer {
            if hasAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }

        do {
            let newPlayer = try AVAudioPlayer(contentsOf: url)
            newPlayer.prepareToPlay()
            newPlayer.pan = Float(balance)

            if isCrossfadeEnabled && isPlaying && crossfadeDuration > 0 {
                // Outgoing player fades out, incoming player fades in
                let outgoingPlayer = isUsingPlayerA ? localPlayerA : localPlayerB
                let incomingPlayer = newPlayer
                incomingPlayer.volume = 0.0
                incomingPlayer.play()

                let steps = 20
                let interval = crossfadeDuration / Double(steps)
                let targetVolume = Float(volume)
                var currentStep = 0

                crossfadeTimer?.invalidate()
                crossfadeTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] timer in
                    currentStep += 1
                    let progress = Float(currentStep) / Float(steps)
                    outgoingPlayer?.volume = targetVolume * (1.0 - progress)
                    incomingPlayer.volume = targetVolume * progress

                    if currentStep >= steps {
                        timer.invalidate()
                        outgoingPlayer?.stop()
                        outgoingPlayer?.volume = targetVolume
                    }
                }

                if isUsingPlayerA {
                    localPlayerB = newPlayer
                    isUsingPlayerA = false
                } else {
                    localPlayerA = newPlayer
                    isUsingPlayerA = true
                }
            } else {
                localPlayerA?.stop()
                localPlayerB?.stop()
                newPlayer.volume = Float(volume)
                newPlayer.play()
                localPlayerA = newPlayer
                isUsingPlayerA = true
            }

            duration = newPlayer.duration
        } catch {
            print("[Winamp] Failed to play local audio: \(error)")
        }
    }

    // MARK: - Equalizer Controls
    public func setGain(forBand index: Int, gain: Float) {
        guard index >= 0 && index < bandGains.count else { return }
        bandGains[index] = max(-12.0, min(12.0, gain))
        webView?.evaluateJavaScript("window.__winamp?.setGain(\(index), \(bandGains[index]));", completionHandler: nil)
    }

    public func setPreamp(_ gain: Float) {
        preampGain = max(-12.0, min(12.0, gain))
        webView?.evaluateJavaScript("window.__winamp?.setPreamp(\(preampGain));", completionHandler: nil)
    }

    public func applyPreset(_ preset: EqualizerPreset) {
        currentPreset = preset
        let gains = preset.gains
        for i in 0..<min(gains.count, bandGains.count) {
            bandGains[i] = gains[i]
            webView?.evaluateJavaScript("window.__winamp?.setGain(\(i), \(gains[i]));", completionHandler: nil)
        }
    }

    public func resetEQ() {
        preampGain = 0.0
        bandGains = Array(repeating: 0.0, count: 10)
        applyPreset(.flat)
    }

    public func toggleVocalRemover() {
        isVocalRemoverActive.toggle()
        webView?.evaluateJavaScript("window.__winamp?.setVocalRemover(\(isVocalRemoverActive));", completionHandler: nil)
    }

    // MARK: - Add Local Audio Files & Folders
    public func addLocalFiles(urls: [URL]) {
        for url in urls {
            let hasAccess = url.startAccessingSecurityScopedResource()
            let asset = AVURLAsset(url: url)
            let durationSeconds = CMTimeGetSeconds(asset.duration)

            let filename = url.deletingPathExtension().lastPathComponent
            let track = TrackItem(
                title: filename,
                artist: "Local Audio",
                duration: durationSeconds.isFinite && durationSeconds > 0 ? durationSeconds : 0,
                urlString: url.absoluteString,
                isLocal: true
            )
            playlist.append(track)

            if hasAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }
    }

    public func addFolder(url: URL) {
        let hasAccess = url.startAccessingSecurityScopedResource()
        defer {
            if hasAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }

        let supportedExtensions = ["mp3", "m4a", "wav", "flac", "aac", "alac", "ogg"]
        guard let enumerator = FileManager.default.enumerator(at: url, includingPropertiesForKeys: [.isRegularFileKey]) else { return }

        var discoveredURLs: [URL] = []
        for case let fileURL as URL in enumerator {
            if supportedExtensions.contains(fileURL.pathExtension.lowercased()) {
                discoveredURLs.append(fileURL)
            }
        }
        addLocalFiles(urls: discoveredURLs)
    }

    public func loadYouTubeMusicFeed(tracks: [TrackItem]) {
        // Appends or sets recommended music tracks from YouTube
        guard !tracks.isEmpty else { return }
        for t in tracks {
            if !playlist.contains(where: { $0.videoId == t.videoId && t.videoId != nil }) {
                playlist.append(t)
            }
        }
    }

    public func removeTrack(at index: Int) {
        guard index >= 0 && index < playlist.count else { return }
        playlist.remove(at: index)
        if currentIndex >= playlist.count {
            currentIndex = max(0, playlist.count - 1)
        }
    }

    public func clearPlaylist() {
        stop()
        playlist.removeAll()
        currentIndex = 0
    }

    // MARK: - Playback Timer & Spectrum Simulation
    private func startPlaybackProgressTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            guard self.isPlaying else {
                // Decay spectrum bars to zero
                for i in 0..<self.spectrumBars.count {
                    self.spectrumBars[i] = max(0.0, self.spectrumBars[i] * 0.8)
                }
                return
            }

            if let track = self.currentTrack, track.isLocal {
                let activePlayer = self.isUsingPlayerA ? self.localPlayerA : self.localPlayerB
                if let p = activePlayer {
                    self.currentTime = p.currentTime
                    self.duration = p.duration
                    if !p.isPlaying && self.currentTime >= self.duration - 0.5 {
                        self.nextTrack()
                    }
                }
            }

            // Real-time responsive spectrum simulation for audio visualization
            for i in 0..<self.spectrumBars.count {
                let baseVal = Float.random(in: 0.25...0.95)
                let decay = self.spectrumBars[i] * 0.7
                self.spectrumBars[i] = max(decay, baseVal)
            }
        }
    }

    // MARK: - Now Playing Info Center (Lock Screen)
    private func updateNowPlayingInfo() {
        var info = [String: Any]()
        if let track = currentTrack {
            info[MPMediaItemPropertyTitle] = track.title
            info[MPMediaItemPropertyArtist] = track.artist
            info[MPMediaItemPropertyPlaybackDuration] = duration
            info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = currentTime
            info[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0
        }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    // MARK: - Remote Command Center (Control Center & Lock Screen Buttons)
    private func setupRemoteCommandCenter() {
        let commandCenter = MPRemoteCommandCenter.shared()

        commandCenter.playCommand.addTarget { [weak self] _ in
            self?.resume()
            return .success
        }
        commandCenter.pauseCommand.addTarget { [weak self] _ in
            self?.pause()
            return .success
        }
        commandCenter.togglePlayPauseCommand.addTarget { [weak self] _ in
            self?.togglePlayPause()
            return .success
        }
        commandCenter.nextTrackCommand.addTarget { [weak self] _ in
            self?.nextTrack()
            return .success
        }
        commandCenter.previousTrackCommand.addTarget { [weak self] _ in
            self?.previousTrack()
            return .success
        }
        commandCenter.changePlaybackPositionCommand.addTarget { [weak self] event in
            if let posEvent = event as? MPChangePlaybackPositionCommandEvent {
                self?.seek(to: posEvent.positionTime)
                return .success
            }
            return .commandFailed
        }
    }
}
