import Foundation
import AVFoundation
import Accelerate

/// Native audio engine using AVPlayer + AVAudioEngine for real-time DSP
/// Provides hardware-level 10-Band EQ, Volume, Balance, and Crossfade
/// Architecture modeled after Tube EQ's SeaAudioUnit + BMMultiLevelBiquad
public class NativeAudioEngine: NSObject {
    public static let shared = NativeAudioEngine()

    // MARK: - Dual AVPlayer for Crossfade
    private var playerA = AVPlayer()
    private var playerB = AVPlayer()
    private var isUsingA: Bool = true

    // MARK: - AVAudioEngine DSP Chain
    private let audioEngine = AVAudioEngine()
    private let eqNode = AVAudioUnitEQ(numberOfBands: 10)
    private let playerNodeA = AVAudioPlayerNode()
    private let playerNodeB = AVAudioPlayerNode()
    private let mixerNode = AVAudioMixerNode()

    // MARK: - State
    public private(set) var isPlaying: Bool = false
    public var currentTime: TimeInterval = 0
    public var duration: TimeInterval = 0
    public private(set) var isCrossfading: Bool = false

    private var timeObserverA: Any?
    private var timeObserverB: Any?
    private var endObserverA: NSObjectProtocol?
    private var endObserverB: NSObjectProtocol?
    private var crossfadeTimer: Timer?
    private var currentAudioFile: AVAudioFile?
    private var seekOffset: TimeInterval = 0
    private var hasTriggeredSmartOutro: Bool = false
    private var silenceCheckTimer: Timer?

    // MARK: - Audio Controls (publicly settable)
    public var volume: Float = 0.85 {
        didSet { updateVolume() }
    }

    public var balance: Float = 0.0 {
        didSet { updateBalance() }
    }

    public var preampGain: Float = 0.0 {
        didSet { updateVolume() }
    }

    public var isEqEnabled: Bool = true {
        didSet { updateEQBypass() }
    }

    public let bandFrequencies: [Float] = [70, 180, 320, 600, 1000, 3000, 6000, 12000, 14000, 16000]

    // MARK: - Playback Mode
    public enum PlaybackMode {
        case avPlayer       // Streaming via AVPlayer (volume only, no EQ)
        case audioEngine    // Local file via AVAudioEngine (full DSP)
    }
    public private(set) var currentMode: PlaybackMode = .avPlayer

    private override init() {
        super.init()
        setupAudioSession()
        setupAudioEngineGraph()
    }

    // MARK: - Audio Session
    private func setupAudioSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, mode: .default, options: [.allowBluetooth, .allowBluetoothA2DP, .allowAirPlay])
            try session.setActive(true)
        } catch {
            print("[NativeEngine] AudioSession error: \(error)")
        }
    }

    // MARK: - AVAudioEngine Graph (for local files with full DSP)
    // [playerNodeA] -\
    //                  -> [mixerNode] -> [eqNode] -> [mainMixer] -> Output
    // [playerNodeB] -/
    private func setupAudioEngineGraph() {
        audioEngine.attach(playerNodeA)
        audioEngine.attach(playerNodeB)
        audioEngine.attach(mixerNode)
        audioEngine.attach(eqNode)

        // Configure 10-Band EQ
        for i in 0..<10 {
            let band = eqNode.bands[i]
            band.frequency = bandFrequencies[i]
            band.gain = 0.0
            band.bypass = false
            band.bandwidth = 1.0
            if i == 0 { band.filterType = .lowShelf }
            else if i == 9 { band.filterType = .highShelf }
            else { band.filterType = .parametric }
        }

        let fmt = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 2)!
        audioEngine.connect(playerNodeA, to: mixerNode, format: fmt)
        audioEngine.connect(playerNodeB, to: mixerNode, format: fmt)
        audioEngine.connect(mixerNode, to: eqNode, format: fmt)
        audioEngine.connect(eqNode, to: audioEngine.mainMixerNode, format: fmt)

        updateVolume()
        updateBalance()
    }

    private func startEngineIfNeeded() {
        guard !audioEngine.isRunning else { return }
        do {
            audioEngine.prepare()
            try audioEngine.start()
            print("[NativeEngine] AVAudioEngine started with 10-Band EQ")
        } catch {
            print("[NativeEngine] Engine start error: \(error)")
        }
    }

    // MARK: - EQ Controls
    public func setBandGain(index: Int, gain: Float) {
        guard index >= 0 && index < 10 else { return }
        let clamped = max(-12.0, min(12.0, gain))
        let effective = isEqEnabled ? (clamped * 1.5) : 0.0
        eqNode.bands[index].gain = effective
        eqNode.bands[index].bypass = !isEqEnabled

        if currentMode == .avPlayer {
            updateAVPlayerVolume()
        }
    }

    public func updateEQBypass() {
        eqNode.bypass = !isEqEnabled
        for i in 0..<10 {
            eqNode.bands[i].bypass = !isEqEnabled
        }
        updateVolume()
    }

    // MARK: - Volume & Balance
    private func updateVolume() {
        let preampMult = isEqEnabled ? pow(10.0, preampGain / 20.0) : 1.0
        let effective = max(0.0, min(1.5, volume * preampMult))

        switch currentMode {
        case .audioEngine:
            audioEngine.mainMixerNode.outputVolume = effective
        case .avPlayer:
            updateAVPlayerVolume()
        }
    }

    private func updateAVPlayerVolume() {
        let preampMult = isEqEnabled ? pow(10.0, preampGain / 20.0) : 1.0
        let effective = max(0.0, min(1.0, volume * preampMult))
        activePlayer.volume = effective
    }

    public func updateBalance() {
        let p = max(-1.0, min(1.0, balance))
        mixerNode.pan = p
        playerNodeA.pan = p
        playerNodeB.pan = p
    }

    private var activePlayer: AVPlayer {
        return isUsingA ? playerA : playerB
    }
    private var inactivePlayer: AVPlayer {
        return isUsingA ? playerB : playerA
    }

    // MARK: - Accurate Time
    public var currentAudioPosition: TimeInterval {
        switch currentMode {
        case .avPlayer:
            let p = activePlayer
            let t = CMTimeGetSeconds(p.currentTime())
            return t.isFinite ? t : currentTime
        case .audioEngine:
            guard audioEngine.isRunning else { return currentTime }
            let node = isUsingA ? playerNodeA : playerNodeB
            guard node.isPlaying, let nodeTime = node.lastRenderTime,
                  let playerTime = node.playerTime(forNodeTime: nodeTime),
                  playerTime.sampleRate > 0 else { return currentTime }
            return max(0, seekOffset + Double(playerTime.sampleTime) / playerTime.sampleRate)
        }
    }

    // MARK: - Play Audio URL via AVPlayer (streaming, instant start)
    public func playStreamURL(_ url: URL, crossfadeDuration: Double = 0.0) {
        currentMode = .avPlayer
        hasTriggeredSmartOutro = false
        isCrossfading = false
        crossfadeTimer?.invalidate()

        // Stop audio engine if running
        playerNodeA.stop()
        playerNodeB.stop()

        let incomingPlayer = isUsingA ? playerB : playerA
        let outgoingPlayer = isUsingA ? playerA : playerB
        let item = AVPlayerItem(url: url)

        if isPlaying && crossfadeDuration > 0 {
            isCrossfading = true
            incomingPlayer.replaceCurrentItem(with: item)
            incomingPlayer.volume = 0.0
            incomingPlayer.play()
            isUsingA.toggle()

            let steps = max(20, Int(crossfadeDuration * 4))
            let interval = crossfadeDuration / Double(steps)
            var step = 0
            crossfadeTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] timer in
                guard let self = self else { return }
                step += 1
                let progress = Float(step) / Float(steps)
                let preampMult = self.isEqEnabled ? pow(10.0, self.preampGain / 20.0) : 1.0
                let effectiveMax = max(0.0, min(1.0, self.volume * preampMult))

                outgoingPlayer.volume = max(0, (1.0 - progress) * effectiveMax)
                incomingPlayer.volume = min(effectiveMax, progress * effectiveMax)

                if step >= steps {
                    timer.invalidate()
                    outgoingPlayer.pause()
                    outgoingPlayer.replaceCurrentItem(with: nil)
                    incomingPlayer.volume = effectiveMax
                    self.isCrossfading = false
                }
            }
        } else {
            outgoingPlayer.pause()
            outgoingPlayer.replaceCurrentItem(with: nil)
            incomingPlayer.replaceCurrentItem(with: item)
            incomingPlayer.play()
            isUsingA.toggle()
            updateAVPlayerVolume()
        }

        let currentPlayer = activePlayer
        isPlaying = true

        // Observe time
        setupTimeObserver(for: currentPlayer)
        setupEndObserver(for: item, player: currentPlayer)

        startSmartSilenceDetector()
        print("[NativeEngine] Playing stream via AVPlayer: \(url.absoluteString.prefix(80))")
    }

    // MARK: - Play Local File via AVAudioEngine (full DSP: EQ + Balance + Crossfade)
    public func playAudioFile(url: URL, crossfadeDuration: Double) {
        currentMode = .audioEngine
        hasTriggeredSmartOutro = false
        crossfadeTimer?.invalidate()
        startEngineIfNeeded()

        // Safely stop AVPlayer completely so its observers do NOT trigger
        playerA.pause()
        playerB.pause()
        playerA.replaceCurrentItem(with: nil)
        playerB.replaceCurrentItem(with: nil)

        do {
            let file = try AVAudioFile(forReading: url)
            currentAudioFile = file
            seekOffset = 0
            let exactDuration = Double(file.length) / file.processingFormat.sampleRate
            if exactDuration > 0 {
                duration = exactDuration
                DispatchQueue.main.async {
                    WinampPlayerEngine.shared.updateCurrentTrackRealDuration(exactDuration)
                }
            }

            let outgoing = isUsingA ? playerNodeA : playerNodeB
            let incoming = isUsingA ? playerNodeB : playerNodeA

            // Reconnect with file format
            audioEngine.disconnectNodeOutput(incoming)
            audioEngine.connect(incoming, to: mixerNode, format: file.processingFormat)
            let p = max(-1.0, min(1.0, balance))
            incoming.pan = p

            if isPlaying && crossfadeDuration > 0 {
                isCrossfading = true
                incoming.volume = 0.0
                incoming.scheduleFile(file, at: nil) { [weak self] in
                    DispatchQueue.main.async {
                        guard let self = self, self.isPlaying, !self.hasTriggeredSmartOutro, !self.isCrossfading else { return }
                        guard self.duration > 15, self.currentAudioPosition >= (self.duration - 2.5), (self.currentAudioPosition / self.duration) >= 0.9 else { return }
                        self.hasTriggeredSmartOutro = true
                        print("[NativeEngine] File playback completed -> auto advance")
                        WinampPlayerEngine.shared.autoAdvanceNextTrack()
                    }
                }
                incoming.play()

                // Immediately toggle active node so currentAudioPosition reads incoming position (0.0s)
                self.isUsingA.toggle()

                let steps = max(20, Int(crossfadeDuration * 4))
                let interval = crossfadeDuration / Double(steps)
                var step = 0
                crossfadeTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] timer in
                    guard let self = self else { return }
                    step += 1
                    let progress = Float(step) / Float(steps)
                    outgoing.volume = max(0, 1.0 - progress)
                    incoming.volume = min(1.0, progress)
                    if step >= steps {
                        timer.invalidate()
                        outgoing.stop()
                        outgoing.volume = 1.0
                        self.isCrossfading = false
                    }
                }
            } else {
                isCrossfading = false
                outgoing.stop()
                incoming.stop()
                incoming.volume = 1.0
                incoming.scheduleFile(file, at: nil) { [weak self] in
                    DispatchQueue.main.async {
                        guard let self = self, self.isPlaying, !self.hasTriggeredSmartOutro, !self.isCrossfading else { return }
                        guard self.duration > 15, self.currentAudioPosition >= (self.duration - 2.5), (self.currentAudioPosition / self.duration) >= 0.9 else { return }
                        self.hasTriggeredSmartOutro = true
                        print("[NativeEngine] File playback completed -> auto advance")
                        WinampPlayerEngine.shared.autoAdvanceNextTrack()
                    }
                }
                incoming.play()
                isUsingA.toggle()
            }

            isPlaying = true
            updateVolume()
            updateBalance()
            startSmartSilenceDetector()
            print("[NativeEngine] Playing local file via AudioEngine with full DSP (exact duration: \(duration)s)")

        } catch {
            print("[NativeEngine] File play error: \(error)")
        }
    }

    // MARK: - Transition from AVPlayer to AudioEngine (seamless switch)
    public func transitionToLocalFile(_ url: URL, atTime: TimeInterval) {
        guard currentMode == .avPlayer && isPlaying else { return }
        playerA.pause()
        playerB.pause()
        playerA.replaceCurrentItem(with: nil)
        playerB.replaceCurrentItem(with: nil)

        playAudioFile(url: url, crossfadeDuration: 0.0)
        if atTime > 0 {
            seek(to: atTime)
        }
        print("[NativeEngine] Transitioned from AVPlayer to AudioEngine at \(Int(atTime))s")
    }

    // MARK: - Transport Controls
    public func pause() {
        isPlaying = false
        switch currentMode {
        case .avPlayer:
            activePlayer.pause()
        case .audioEngine:
            playerNodeA.pause()
            playerNodeB.pause()
        }
    }

    public func resume() {
        isPlaying = true
        switch currentMode {
        case .avPlayer:
            activePlayer.play()
        case .audioEngine:
            startEngineIfNeeded()
            let node = isUsingA ? playerNodeA : playerNodeB
            node.play()
        }
    }

    public func stop() {
        isPlaying = false
        hasTriggeredSmartOutro = true
        silenceCheckTimer?.invalidate()
        crossfadeTimer?.invalidate()
        playerA.pause()
        playerB.pause()
        playerA.replaceCurrentItem(with: nil)
        playerB.replaceCurrentItem(with: nil)
        playerNodeA.stop()
        playerNodeB.stop()
        playerNodeA.volume = 1.0
        playerNodeB.volume = 1.0
        currentTime = 0
        duration = 0
        seekOffset = 0
    }

    public func seek(to seconds: TimeInterval) {
        currentTime = seconds
        if duration - seconds > 3.0 {
            hasTriggeredSmartOutro = false
        }
        switch currentMode {
        case .avPlayer:
            let time = CMTime(seconds: seconds, preferredTimescale: 1000)
            activePlayer.seek(to: time, toleranceBefore: .zero, toleranceAfter: .zero)
        case .audioEngine:
            seekOffset = seconds
            guard let file = currentAudioFile else { return }
            let sr = file.processingFormat.sampleRate
            let startFrame = AVAudioFramePosition(max(0, seconds * sr))
            guard startFrame >= 0 && startFrame < file.length else { return }
            let frames = AVAudioFrameCount(file.length - startFrame)
            let node = isUsingA ? playerNodeA : playerNodeB
            node.stop()
            node.scheduleSegment(file, startingFrame: startFrame, frameCount: frames, at: nil) { [weak self] in
                DispatchQueue.main.async {
                    guard let self = self, self.isPlaying, !self.hasTriggeredSmartOutro else { return }
                    guard self.duration > 15, self.currentAudioPosition >= (self.duration - 2.0) else { return }
                    self.hasTriggeredSmartOutro = true
                    print("[NativeEngine] Seek segment completed -> auto advance")
                    WinampPlayerEngine.shared.autoAdvanceNextTrack()
                }
            }
            if isPlaying { node.play() }
        }
    }

    // MARK: - Time Observer for AVPlayer
    private func setupTimeObserver(for player: AVPlayer) {
        // Remove old
        if let obs = timeObserverA { playerA.removeTimeObserver(obs); timeObserverA = nil }
        if let obs = timeObserverB { playerB.removeTimeObserver(obs); timeObserverB = nil }

        let interval = CMTime(seconds: 0.1, preferredTimescale: 600)
        let obs = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard let self = self, self.currentMode == .avPlayer else { return }
            let t = CMTimeGetSeconds(time)
            if t.isFinite { self.currentTime = t }
            if let d = player.currentItem?.duration {
                let dur = CMTimeGetSeconds(d)
                if dur.isFinite && dur > 0 {
                    self.duration = dur
                    WinampPlayerEngine.shared.updateCurrentTrackRealDuration(dur)
                }
            }
        }
        if player === playerA { timeObserverA = obs }
        else { timeObserverB = obs }
    }

    private func setupEndObserver(for item: AVPlayerItem, player: AVPlayer) {
        // Remove old
        if let obs = endObserverA { NotificationCenter.default.removeObserver(obs); endObserverA = nil }
        if let obs = endObserverB { NotificationCenter.default.removeObserver(obs); endObserverB = nil }

        let obs = NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: item, queue: .main) { [weak self] _ in
            guard let self = self, self.currentMode == .avPlayer, !self.isCrossfading, !self.hasTriggeredSmartOutro else { return }
            self.hasTriggeredSmartOutro = true
            print("[NativeEngine] AVPlayer item played to end -> auto advance")
            DispatchQueue.main.async {
                WinampPlayerEngine.shared.autoAdvanceNextTrack()
            }
        }
        if player === playerA { endObserverA = obs }
        else { endObserverB = obs }
    }

    // MARK: - Smart Silence Detection & Outro Transition
    private func startSmartSilenceDetector() {
        silenceCheckTimer?.invalidate()
        silenceCheckTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            guard let self = self, self.isPlaying, !self.hasTriggeredSmartOutro, !self.isCrossfading else { return }
            let pos = self.currentAudioPosition
            self.currentTime = pos

            // Prevent premature triggers: require duration > 20s and position > 10s
            guard self.duration > 20.0, pos > 10.0 else { return }

            let isCrossfade = WinampPlayerEngine.shared.isCrossfadeEnabled
            let reqFade = WinampPlayerEngine.shared.crossfadeDuration
            // Cap lead time safely so we never trigger more than 15% before track finishes
            let maxLead = min(15.0, self.duration * 0.15)
            let leadTime = isCrossfade ? min(max(1.0, reqFade), max(1.0, maxLead)) : 0.8

            // Must be within leadTime AND at least 85% into the song
            if (self.duration - pos) <= leadTime && (pos / self.duration) >= 0.85 {
                self.hasTriggeredSmartOutro = true
                print("[NativeEngine] Track ending reached (leadTime: \(leadTime)s, pos: \(pos)s / \(self.duration)s) -> auto advance")
                DispatchQueue.main.async { WinampPlayerEngine.shared.autoAdvanceNextTrack() }
            }
        }
    }

    deinit {
        silenceCheckTimer?.invalidate()
        crossfadeTimer?.invalidate()
        if let obs = timeObserverA { playerA.removeTimeObserver(obs) }
        if let obs = timeObserverB { playerB.removeTimeObserver(obs) }
        if let obs = endObserverA { NotificationCenter.default.removeObserver(obs) }
        if let obs = endObserverB { NotificationCenter.default.removeObserver(obs) }
    }
}
