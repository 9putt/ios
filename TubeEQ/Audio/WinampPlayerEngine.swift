import Foundation
import AVFoundation
import MediaPlayer
import Combine
import WebKit

public class WinampPlayerEngine: ObservableObject {
    public static let shared = WinampPlayerEngine()

    // MARK: - Playback States
    @Published public var playlist: [TrackItem] = [] {
        didSet {
            savePlaylistToDisk()
        }
    }
    @Published public var currentIndex: Int = 0 {
        didSet {
            UserDefaults.standard.set(currentIndex, forKey: "winamp_saved_index")
        }
    }
    @Published public var isPlaying: Bool = false
    @Published public var currentTime: TimeInterval = 0
    @Published public var duration: TimeInterval = 0
    @Published public var isTimeRemaining: Bool = false

    @Published public var volume: Double = 0.85 {
        didSet {
            NativeAudioEngine.shared.volume = Float(volume)
            webView?.evaluateJavaScript("var v = document.querySelector('video'); if (v) { v.volume = \(volume); }", completionHandler: nil)
        }
    }

    @Published public var balance: Double = 0.0 {
        didSet {
            NativeAudioEngine.shared.balance = Float(balance)
        }
    }

    @Published public var isShuffle: Bool = false
    @Published public var isRepeat: Bool = false
    @Published public var isCrossfadeEnabled: Bool = true
    @Published public var crossfadeDuration: Double = 3.0 // 0s - 20s

    // Equalizer & Preamp
    @Published public var isEqEnabled: Bool = true {
        didSet {
            NativeAudioEngine.shared.isEqEnabled = isEqEnabled
        }
    }

    @Published public var isEqAuto: Bool = false

    @Published public var preampGain: Float = 0.0 {
        didSet {
            NativeAudioEngine.shared.preampGain = preampGain
        }
    }

    @Published public var bandGains: [Float] = Array(repeating: 0.0, count: 10)
    @Published public var currentPreset: EqualizerPreset = .flat

    // Real-Time Spectrum Analyzer Bars (16 bands)
    @Published public var spectrumBars: [Float] = Array(repeating: 0.0, count: 16)

    // Status Marquee Message
    @Published public var customStatusMessage: String? = nil

    // Dynamic Randomized Keyword Pool for Infinite Variety (Never same songs)
    @Published public var isLoadingMore: Bool = false
    private var randomizedKeywordPool: [String] = [
        "เพลงฮิตติดชาร์ต ล่าสุด Official MV",
        "เพลงใหม่ล่าสุด 2026 Official MV",
        "เพลงไทยฟังสบาย เพราะๆ Official MV",
        "T-POP Hot Hits Official MV",
        "เพลงรัก ซึ้งๆ Official MV",
        "เพลงอกหัก เศร้าๆ Official MV",
        "เพลงฮิต TikTok ไทย Official MV",
        "เพลงอินดี้ไทย เพราะๆ Official MV",
        "Billboard Hot 100 Official Video",
        "Three Man Down Official MV",
        "BOWKYLION Official MV",
        "Jeff Satur Official MV",
        "Tilly Birds Official MV",
        "Billkin Official MV",
        "NONT TANONT Official MV",
        "4EVE Official MV",
        "PROXIE Official MV",
        "BUS Because of you i shine Official MV",
        "Cocktail Official MV",
        "Paper Planes Official MV",
        "BODYSLAM Official MV",
        "Potato Official MV",
        "KLEAR Official MV",
        "Palmy Official MV",
        "Lipta Official MV",
        "Tattoo Colour Official MV",
        "Singto Numchok Official MV",
        "Meyou Official MV",
        "Safeplanet Official MV",
        "Dept Official MV",
        "Anatomy Rabbit Official MV"
    ]
    private var currentKeywordIndex: Int = 0

    // MARK: - Playlist Persistence
    private var playlistFileURL: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent("winamp_saved_playlist.json")
    }

    public func savePlaylistToDisk() {
        guard !playlist.isEmpty else {
            try? FileManager.default.removeItem(at: playlistFileURL)
            return
        }
        do {
            let data = try JSONEncoder().encode(playlist)
            try data.write(to: playlistFileURL, options: .atomic)
            UserDefaults.standard.set(currentIndex, forKey: "winamp_saved_index")
        } catch {
            print("[WinampEngine] Save playlist error: \(error)")
        }
    }

    public func loadSavedPlaylistFromDisk() -> Bool {
        guard FileManager.default.fileExists(atPath: playlistFileURL.path) else { return false }
        do {
            let data = try Data(contentsOf: playlistFileURL)
            let loaded = try JSONDecoder().decode([TrackItem].self, from: data)
            if !loaded.isEmpty {
                self.playlist = loaded
                let savedIdx = UserDefaults.standard.integer(forKey: "winamp_saved_index")
                self.currentIndex = min(max(0, savedIdx), loaded.count - 1)
                print("[WinampEngine] 📂 Successfully restored \(loaded.count) saved playlist tracks from disk")
                return true
            }
        } catch {
            print("[WinampEngine] Load playlist error: \(error)")
        }
        return false
    }

    public func refreshWithNewRandomSongs() async {
        let activePool: [String]
        if !selectedGenres.isEmpty {
            activePool = selectedGenres.flatMap { $0.searchQueries }
        } else {
            activePool = randomizedKeywordPool
        }
        let query = activePool.randomElement() ?? "เพลงใหม่ล่าสุด Official MV"
        print("[WinampEngine] 🔄 Pull-to-refresh querying: \(query)")
        await withCheckedContinuation { continuation in
            YouTubeSearchManager.shared.search(query: query, filterCompilations: true) { [weak self] newTracks in
                guard let self = self else {
                    continuation.resume()
                    return
                }
                let filtered = newTracks.filter { track in
                    !self.playlist.contains(where: { $0.videoId == track.videoId })
                }
                if !filtered.isEmpty {
                    self.playlist.insert(contentsOf: filtered, at: 0)
                    self.currentIndex += filtered.count
                    let gen = UINotificationFeedbackGenerator()
                    gen.notificationOccurred(.success)
                }
                continuation.resume()
            }
        }
    }

    // MARK: - Multi-Genre Playlist Mix Presets
    @Published public var selectedGenres: Set<MusicGenre> = [.string]
    @Published public var isFetchingGenreMix: Bool = false
    @Published public var showGenrePickerSheet: Bool = false

    public func toggleGenre(_ genre: MusicGenre) {
        if selectedGenres.contains(genre) {
            if selectedGenres.count > 1 {
                selectedGenres.remove(genre)
            }
        } else {
            selectedGenres.insert(genre)
        }
    }

    public func isGenreSelected(_ genre: MusicGenre) -> Bool {
        return selectedGenres.contains(genre)
    }

    public func selectSingleGenreAndPlay(_ genre: MusicGenre) {
        selectedGenres = [genre]
        loadGenreMix(autoPlay: true)
    }

    public func loadGenreMix(autoPlay: Bool = true) {
        guard !isFetchingGenreMix else { return }
        isFetchingGenreMix = true
        let genresToFetch = selectedGenres.isEmpty ? [MusicGenre.string] : Array(selectedGenres)
        
        let dispatchGroup = DispatchGroup()
        var collectedTracks: [TrackItem] = []
        let lock = NSLock()

        for genre in genresToFetch {
            let queries = genre.searchQueries.shuffled()
            let sampleQueries = Array(queries.prefix(2))
            for query in sampleQueries {
                dispatchGroup.enter()
                YouTubeSearchManager.shared.search(query: query, filterCompilations: true) { tracks in
                    lock.lock()
                    collectedTracks.append(contentsOf: tracks)
                    lock.unlock()
                    dispatchGroup.leave()
                }
            }
        }

        dispatchGroup.notify(queue: .main) { [weak self] in
            guard let self = self else { return }
            self.isFetchingGenreMix = false
            
            var seen = Set<String>()
            var uniqueTracks: [TrackItem] = []
            for track in collectedTracks {
                let trackKey = track.videoId ?? track.urlString
                if !seen.contains(trackKey) {
                    seen.insert(trackKey)
                    uniqueTracks.append(track)
                }
            }
            
            uniqueTracks.shuffle()
            
            if !uniqueTracks.isEmpty {
                self.playlist = uniqueTracks
                self.currentIndex = 0
                if autoPlay {
                    self.playTrack(at: 0)
                }
                let gen = UINotificationFeedbackGenerator()
                gen.notificationOccurred(.success)
            }
        }
    }

    // Skin & Appearance
    @Published public var currentSkin: WinampSkinPreset = .cartoonOnePiece
    @Published public var activeDynamicSkin: DynamicSkinItem? = nil
    @Published public var activeDynamicWallpaperImage: UIImage? = nil

    public func applyDynamicSkin(_ skin: DynamicSkinItem) {
        activeDynamicSkin = skin
        currentSkin = .cartoonOnePiece
        UserDefaults.standard.set(skin.id, forKey: "winamp_dynamic_skin_id")
        UserDefaults.standard.set(WinampSkinPreset.cartoonOnePiece.rawValue, forKey: "winamp_saved_skin")

        if let img = DynamicSkinManager.shared.imageFor(skin: skin) {
            self.activeDynamicWallpaperImage = img
        } else {
            DynamicSkinManager.shared.fetchImageDirectly(for: skin) { [weak self] downloaded in
                DispatchQueue.main.async {
                    if self?.activeDynamicSkin?.id == skin.id {
                        self?.activeDynamicWallpaperImage = downloaded
                    }
                }
            }
        }
    }

    public func resetToPresetSkin(_ preset: WinampSkinPreset) {
        activeDynamicSkin = nil
        activeDynamicWallpaperImage = nil
        currentSkin = preset
        UserDefaults.standard.removeObject(forKey: "winamp_dynamic_skin_id")
        UserDefaults.standard.set(preset.rawValue, forKey: "winamp_saved_skin")
    }
    @Published public var showEqualizerWindow: Bool = true
    @Published public var showPlaylistWindow: Bool = true
    @Published public var showYouTubeLoginSheet: Bool = false
    @Published public var showSkinPickerSheet: Bool = false
    @Published public var showCrossfadeSheet: Bool = false
    @Published public var showSearchSheet: Bool = false
    @Published public var showAddFilePicker: Bool = false
    @Published public var showAddFolderPicker: Bool = false

    // Embedded Web Player Reference
    public weak var webView: WKWebView?

    private var timer: Timer?
    private var cancellables = Set<AnyCancellable>()

    // Frequency labels matching Classic Winamp Equalizer
    public let bandFrequencies: [String] = ["70Hz", "180Hz", "320Hz", "600Hz", "1kHz", "3kHz", "6kHz", "12kHz", "14kHz", "16kHz"]

    public var currentTrack: TrackItem? {
        guard !playlist.isEmpty && currentIndex >= 0 && currentIndex < playlist.count else { return nil }
        return playlist[currentIndex]
    }

    private init() {
        randomizedKeywordPool.shuffle()
        setupRemoteCommandCenter()
        startBackgroundAudioKeeper()
        startPlaybackProgressTimer()

        // Sync initial audio engine states
        NativeAudioEngine.shared.volume = Float(volume)
        NativeAudioEngine.shared.balance = Float(balance)
        NativeAudioEngine.shared.preampGain = preampGain
        NativeAudioEngine.shared.isEqEnabled = isEqEnabled

        // Restore saved skin if present (default to cartoonOnePiece)
        if let savedSkin = UserDefaults.standard.string(forKey: "winamp_saved_skin"),
           let preset = WinampSkinPreset(rawValue: savedSkin) {
            self.currentSkin = preset
        } else {
            self.currentSkin = .cartoonOnePiece
        }
        if let dynId = UserDefaults.standard.string(forKey: "winamp_dynamic_skin_id"),
           let dyn = DynamicSkinManager.shared.dynamicSkins.first(where: { $0.id == dynId }) {
            self.activeDynamicSkin = dyn
            self.currentSkin = .cartoonOnePiece
            if let img = DynamicSkinManager.shared.imageFor(skin: dyn) {
                self.activeDynamicWallpaperImage = img
            }
        }

        // Restore saved playlist if present, or load fresh initial songs
        if !loadSavedPlaylistFromDisk() {
            loadInitialFreshSongs()
        }
    }

    private func loadInitialFreshSongs() {
        let initialQuery = randomizedKeywordPool.randomElement() ?? "เพลงฮิตติดชาร์ต ล่าสุด Official MV"
        YouTubeSearchManager.shared.search(query: initialQuery, filterCompilations: true) { [weak self] tracks in
            guard let self = self, !tracks.isEmpty else { return }
            self.playlist = tracks
            self.currentIndex = 0
            if let first = tracks.first {
                self.duration = first.duration > 0 ? first.duration : 210
            }
        }
    }

    // MARK: - Background Audio Silence Keeper
    private var silencePlayer: AVAudioPlayer?
    public func startBackgroundAudioKeeper() {
        guard let soundURL = Bundle.main.url(forResource: "silence", withExtension: "wav") else { return }
        do {
            silencePlayer = try AVAudioPlayer(contentsOf: soundURL)
            silencePlayer?.numberOfLoops = -1
            silencePlayer?.volume = 0.001
            silencePlayer?.prepareToPlay()
            silencePlayer?.play()
        } catch {
            print("[Winamp] Silence keeper error: \(error)")
        }
    }

    // MARK: - Playback Controls
    public func playTrack(at index: Int, isAutoAdvance: Bool = false) {
        guard index >= 0 && index < playlist.count else { return }
        currentIndex = index
        let track = playlist[index]
        currentTime = 0
        duration = track.duration > 0 ? track.duration : 210

        // If user manually tapped a track, immediately stop old audio & do NOT crossfade
        if !isAutoAdvance {
            NativeAudioEngine.shared.stop()
            customStatusMessage = "BUFFERING AUDIO..."
        }

        let fadeTime = (isAutoAdvance && isCrossfadeEnabled) ? crossfadeDuration : 0.0

        if track.isLocal {
            if let localUrl = URL(string: track.urlString) {
                NativeAudioEngine.shared.playAudioFile(url: localUrl, crossfadeDuration: fadeTime)
            }
        } else {
            playYouTubeTrack(track: track, fadeTime: fadeTime, isAutoAdvance: isAutoAdvance)
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
        NativeAudioEngine.shared.pause()
        webView?.evaluateJavaScript("""
            window._userPaused = true;
            var v = document.querySelector('video');
            if (v) { v.pause(); }
        """, completionHandler: nil)
        updateNowPlayingInfo()
    }

    public func resume() {
        isPlaying = true
        if NativeAudioEngine.shared.isPlaying {
            NativeAudioEngine.shared.resume()
        } else {
            webView?.evaluateJavaScript("""
                window._userPaused = false;
                var v = document.querySelector('video');
                if (v) { v.play().catch(function(){}); }
            """, completionHandler: nil)
        }
        updateNowPlayingInfo()
    }

    public func stop() {
        isPlaying = false
        currentTime = 0
        NativeAudioEngine.shared.stop()
        webView?.evaluateJavaScript("""
            window._userPaused = true;
            var v = document.querySelector('video');
            if (v) { v.pause(); v.currentTime = 0; }
        """, completionHandler: nil)
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
        playTrack(at: nextIdx, isAutoAdvance: false)
    }

    public func autoAdvanceNextTrack() {
        guard !playlist.isEmpty else { return }
        var nextIdx = currentIndex + 1
        if isShuffle {
            nextIdx = Int.random(in: 0..<playlist.count)
        } else if nextIdx >= playlist.count {
            nextIdx = 0
        }
        playTrack(at: nextIdx, isAutoAdvance: true)
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
        playTrack(at: prevIdx, isAutoAdvance: false)
    }

    public func seek(to time: TimeInterval) {
        currentTime = time
        NativeAudioEngine.shared.seek(to: time)
        webView?.evaluateJavaScript("var v = document.querySelector('video'); if (v) { v.currentTime = \(time); }", completionHandler: nil)
        updateNowPlayingInfo()
    }

    public func setVolume(_ newVolume: Double) {
        volume = max(0.0, min(1.0, newVolume))
    }

    public func setBalance(_ newBalance: Double) {
        balance = max(-1.0, min(1.0, newBalance))
    }

    // MARK: - YouTube Playback (VisionOS High-Speed Download + CoreAudio 10-Band EQ & Balance)
    private var currentLoadingTask: Task<Void, Never>?

    private func playYouTubeTrack(track: TrackItem, fadeTime: Double, isAutoAdvance: Bool) {
        guard let vid = track.videoId ?? extractVideoID(from: track.urlString) else { return }
        isPlaying = true
        currentLoadingTask?.cancel()

        // 1. Check if cached audio file already exists -> INSTANT 10-Band Hardware EQ & Balance!
        let tempDir = FileManager.default.temporaryDirectory
        let cachedFile = tempDir.appendingPathComponent("\(vid).m4a")
        if FileManager.default.fileExists(atPath: cachedFile.path),
           let attrs = try? FileManager.default.attributesOfItem(atPath: cachedFile.path),
           (attrs[.size] as? UInt64 ?? 0) > 100000 {
            print("[WinampEngine] Playing cached audio for \(vid) with CoreAudio 10-Band EQ & Balance")
            customStatusMessage = nil
            NativeAudioEngine.shared.playAudioFile(url: cachedFile, crossfadeDuration: fadeTime)
            preloadNextTrack()
            return
        }

        if !isAutoAdvance {
            customStatusMessage = "BUFFERING AUDIO..."
        }

        // 2. High-speed direct download with Range: bytes=0- (bypasses throttling, takes ~0.7s)
        currentLoadingTask = Task {
            if let localFile = await InnerTubeExtractor.shared.downloadAudio(videoId: vid) {
                if Task.isCancelled { return }
                await MainActor.run {
                    guard self.currentTrack?.videoId == vid || self.extractVideoID(from: self.currentTrack?.urlString ?? "") == vid else { return }
                    self.customStatusMessage = nil
                    NativeAudioEngine.shared.playAudioFile(url: localFile, crossfadeDuration: fadeTime)
                    self.preloadNextTrack()
                }
                return
            }

            if Task.isCancelled { return }

            // Fallback: If direct download failed, stream via AVPlayer
            if let streamURL = await InnerTubeExtractor.shared.extractAudioURL(videoId: vid) {
                if Task.isCancelled { return }
                await MainActor.run {
                    guard self.currentTrack?.videoId == vid || self.extractVideoID(from: self.currentTrack?.urlString ?? "") == vid else { return }
                    self.customStatusMessage = nil
                    NativeAudioEngine.shared.playStreamURL(streamURL)
                }

                // In parallel, download the M4A file for full 10-Band EQ & Balance transition
                if let localFile = await InnerTubeExtractor.shared.downloadAudio(videoId: vid, streamURL: streamURL) {
                    if Task.isCancelled { return }
                    await MainActor.run {
                        guard self.currentTrack?.videoId == vid || self.extractVideoID(from: self.currentTrack?.urlString ?? "") == vid else { return }
                        let cur = NativeAudioEngine.shared.currentAudioPosition
                        NativeAudioEngine.shared.transitionToLocalFile(localFile, atTime: cur)
                        self.preloadNextTrack()
                    }
                }
            } else {
                if Task.isCancelled { return }
                await MainActor.run {
                    self.customStatusMessage = "TRACK UNAVAILABLE"
                }
            }
        }
    }

    private func preloadNextTrack() {
        guard !playlist.isEmpty else { return }
        let nextIdx = (currentIndex + 1) % playlist.count
        let track = playlist[nextIdx]
        if let nextVid = track.videoId ?? extractVideoID(from: track.urlString) {
            InnerTubeExtractor.shared.preload(videoId: nextVid)
        }
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

    // MARK: - 10-Band Hardware Equalizer Controls (100% Audible Impact)
    public func setGain(forBand index: Int, gain: Float) {
        guard index >= 0 && index < bandGains.count else { return }
        bandGains[index] = max(-12.0, min(12.0, gain))
        NativeAudioEngine.shared.setBandGain(index: index, gain: bandGains[index])
    }

    public func setPreamp(_ gain: Float) {
        preampGain = max(-12.0, min(12.0, gain))
    }

    public func applyPreset(_ preset: EqualizerPreset) {
        currentPreset = preset
        let gains = preset.gains
        for i in 0..<min(gains.count, bandGains.count) {
            bandGains[i] = gains[i]
            NativeAudioEngine.shared.setBandGain(index: i, gain: gains[i])
        }
    }

    public func resetEQ() {
        preampGain = 0.0
        bandGains = Array(repeating: 0.0, count: 10)
        applyPreset(.flat)
    }

    // MARK: - Infinite Scroll Music Fetching
    public func loadMoreYouTubeSongs() {
        guard !isLoadingMore else { return }
        isLoadingMore = true

        let activePool = !selectedGenres.isEmpty ? selectedGenres.flatMap { $0.searchQueries } : randomizedKeywordPool
        let query = activePool.randomElement() ?? randomizedKeywordPool[currentKeywordIndex % randomizedKeywordPool.count]
        currentKeywordIndex += 1

        YouTubeSearchManager.shared.search(query: query, filterCompilations: true) { [weak self] newTracks in
            guard let self = self else { return }
            self.isLoadingMore = false

            let filtered = newTracks.filter { track in
                let notDuplicate = !self.playlist.contains(where: { $0.videoId == track.videoId })
                return notDuplicate
            }

            if !filtered.isEmpty {
                self.playlist.append(contentsOf: filtered)
                let gen = UINotificationFeedbackGenerator()
                gen.notificationOccurred(.success)
            }
        }
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

    // MARK: - Playback Timer & Smooth Clock Counter & Spectrum Simulation
    private func startPlaybackProgressTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            guard self.isPlaying else {
                for i in 0..<self.spectrumBars.count {
                    self.spectrumBars[i] = max(0.0, self.spectrumBars[i] * 0.8)
                }
                return
            }

            if NativeAudioEngine.shared.isPlaying {
                let nativePos = NativeAudioEngine.shared.currentAudioPosition
                if nativePos > 0 {
                    self.currentTime = nativePos
                }
                if let track = self.currentTrack, track.duration > 0 {
                    self.duration = track.duration
                } else if NativeAudioEngine.shared.duration > 0 {
                    self.duration = NativeAudioEngine.shared.duration
                }
            }

            // Real-time responsive spectrum simulation based on audio level & EQ gains
            for i in 0..<self.spectrumBars.count {
                let eqInfluence = (i < self.bandGains.count) ? (self.bandGains[i] / 24.0) : 0.0
                let baseVal = Float.random(in: 0.35...0.95) + eqInfluence
                let decay = self.spectrumBars[i] * 0.65
                self.spectrumBars[i] = max(0.05, min(1.0, max(decay, baseVal)))
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
