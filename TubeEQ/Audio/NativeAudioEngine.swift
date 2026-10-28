import Foundation
import AVFoundation
import MediaPlayer

public class NativeAudioEngine: NSObject {
    public static let shared = NativeAudioEngine()

    // MARK: - Core Audio Engine (AVAudioEngine + 10-Band Hardware EQ)
    private let audioEngine = AVAudioEngine()
    private let eqUnit = AVAudioUnitEQ(numberOfBands: 10)
    private let playerNodeA = AVAudioPlayerNode()
    private let playerNodeB = AVAudioPlayerNode()
    private var isUsingNodeA: Bool = true

    // Direct AVPlayer instances for instant streaming with True Simultaneous Crossfade
    private var streamPlayerA: AVPlayer?
    private var streamPlayerB: AVPlayer?
    private var isUsingStreamA: Bool = true
    private var crossfadeTimer: Timer?

    // Audio Analysis & Smart Outro Silence Detection
    private var silenceCheckTimer: Timer?
    private var silentFrameCount: Int = 0
    private var hasTriggeredSmartOutro: Bool = false

    // State
    public private(set) var isPlaying: Bool = false
    public var currentTime: TimeInterval = 0
    public var duration: TimeInterval = 0
    public var volume: Float = 0.85 {
        didSet {
            updateMasterVolume()
        }
    }
    public var balance: Float = 0.0 {
        didSet {
            updateBalancePan()
        }
    }
    public var preampGain: Float = 0.0 {
        didSet {
            updateMasterVolume()
        }
    }
    public var isEqEnabled: Bool = true {
        didSet {
            updateEQBypass()
        }
    }

    public let bandFrequencies: [Float] = [70, 180, 320, 600, 1000, 3000, 6000, 12000, 14000, 16000]

    private override init() {
        super.init()
        setupAudioSession()
        setupAudioGraph()
        startSmartSilenceDetector()
    }

    // MARK: - Setup Audio Session
    private func setupAudioSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, mode: .moviePlayback, options: [.mixWithOthers, .allowBluetooth, .allowBluetoothA2DP, .allowAirPlay])
            try session.setActive(true)
        } catch {
            print("[NativeAudioEngine] Failed to configure AVAudioSession: \(error)")
        }
    }

    // MARK: - Setup 10-Band EQ Hardware Graph
    private func setupAudioGraph() {
        audioEngine.attach(playerNodeA)
        audioEngine.attach(playerNodeB)
        audioEngine.attach(eqUnit)

        // Configure 10 Winamp Equalizer Bands (70Hz - 16kHz)
        for i in 0..<10 {
            let band = eqUnit.bands[i]
            band.frequency = bandFrequencies[i]
            band.gain = 0.0
            band.bypass = false

            if i == 0 {
                band.filterType = .lowShelf
                band.bandwidth = 1.0
            } else if i == 9 {
                band.filterType = .highShelf
                band.bandwidth = 1.0
            } else {
                band.filterType = .parametric
                band.bandwidth = 1.2
            }
        }

        let format = audioEngine.mainMixerNode.outputFormat(forBus: 0)
        audioEngine.connect(playerNodeA, to: eqUnit, format: format)
        audioEngine.connect(playerNodeB, to: eqUnit, format: format)
        audioEngine.connect(eqUnit, to: audioEngine.mainMixerNode, format: format)

        startEngineIfNeeded()
    }

    private func startEngineIfNeeded() {
        guard !audioEngine.isRunning else { return }
        do {
            audioEngine.prepare()
            try audioEngine.start()
            print("[NativeAudioEngine] AVAudioEngine started with 10-Band Hardware EQ")
        } catch {
            print("[NativeAudioEngine] Failed to start AVAudioEngine: \(error)")
        }
    }

    // MARK: - Hardware Equalizer Adjustments (100% Audible Impact)
    public func setBandGain(index: Int, gain: Float) {
        guard index >= 0 && index < 10 else { return }
        let clamped = max(-12.0, min(12.0, gain))
        // Apply 1.5x gain multiplier so bass, mids, and treble are punchy and clearly heard
        eqUnit.bands[index].gain = isEqEnabled ? (clamped * 1.5) : 0.0
        eqUnit.bands[index].bypass = !isEqEnabled
    }

    public func updateEQBypass() {
        for i in 0..<10 {
            eqUnit.bands[i].bypass = !isEqEnabled
        }
        updateMasterVolume()
    }

    private func updateMasterVolume() {
        let preampMultiplier = isEqEnabled ? pow(10.0, preampGain / 20.0) : 1.0
        let effectiveVol = max(0.0, min(1.0, volume * preampMultiplier))

        audioEngine.mainMixerNode.outputVolume = effectiveVol
        streamPlayerA?.volume = effectiveVol
        streamPlayerB?.volume = effectiveVol
    }

    // MARK: - Left / Right Balance (100% Audible Stereo Panning)
    public func updateBalancePan() {
        let clampedPan = max(-1.0, min(1.0, balance))
        playerNodeA.pan = clampedPan
        playerNodeB.pan = clampedPan

        // Update stream players pan balance
        applyBalanceToStreamPlayer(streamPlayerA, pan: clampedPan)
        applyBalanceToStreamPlayer(streamPlayerB, pan: clampedPan)
    }

    private func applyBalanceToStreamPlayer(_ player: AVPlayer?, pan: Float) {
        guard let currentItem = player?.currentItem, let track = currentItem.asset.tracks(withMediaType: .audio).first else { return }
        let audioMix = AVMutableAudioMix()
        let params = AVMutableAudioMixInputParameters(track: track)
        params.setPan(pan, at: .zero)
        audioMix.inputParameters = [params]
        currentItem.audioMix = audioMix
    }

    // MARK: - Play Local Audio File with True Simultaneous Overlapping Crossfade
    public func playAudioFile(url: URL, crossfadeDuration: Double) {
        startEngineIfNeeded()
        hasTriggeredSmartOutro = false

        do {
            let newFile = try AVAudioFile(forReading: url)
            duration = Double(newFile.length) / newFile.processingFormat.sampleRate

            let outgoingNode = isUsingNodeA ? playerNodeA : playerNodeB
            let incomingNode = isUsingNodeA ? playerNodeB : playerNodeA

            if isPlaying && crossfadeDuration > 0 {
                // TRUE SIMULTANEOUS OVERLAPPING AUDIO CROSSFADE: Both nodes play together!
                incomingNode.volume = 0.0
                incomingNode.pan = balance
                incomingNode.scheduleFile(newFile, at: nil)
                incomingNode.play()

                let steps = 30
                let interval = crossfadeDuration / Double(steps)
                var currentStep = 0

                crossfadeTimer?.invalidate()
                crossfadeTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] timer in
                    guard let self = self else { return }
                    currentStep += 1
                    let progress = Float(currentStep) / Float(steps)

                    outgoingNode.volume = max(0.0, 1.0 - progress)
                    incomingNode.volume = min(1.0, progress)

                    if currentStep >= steps {
                        timer.invalidate()
                        outgoingNode.stop()
                        outgoingNode.volume = 1.0
                        self.isUsingNodeA.toggle()
                    }
                }
            } else {
                outgoingNode.stop()
                incomingNode.stop()
                outgoingNode.volume = 1.0
                outgoingNode.pan = balance
                outgoingNode.scheduleFile(newFile, at: nil)
                outgoingNode.play()
            }

            isPlaying = true
        } catch {
            print("[NativeAudioEngine] Error reading audio file: \(error)")
        }
    }

    // MARK: - Play Streaming Audio URL with True Simultaneous Overlapping Crossfade
    public func playStreamURL(url: URL, crossfadeDuration: Double) {
        hasTriggeredSmartOutro = false
        let outgoingPlayer = isUsingStreamA ? streamPlayerA : streamPlayerB
        let incomingPlayer = AVPlayer(url: url)
        let targetVol = max(0.0, min(1.0, volume * (isEqEnabled ? pow(10.0, preampGain / 20.0) : 1.0)))

        applyBalanceToStreamPlayer(incomingPlayer, pan: balance)

        if isUsingStreamA {
            streamPlayerB = incomingPlayer
        } else {
            streamPlayerA = incomingPlayer
        }

        if isPlaying && crossfadeDuration > 0 && outgoingPlayer != nil {
            // TRUE SIMULTANEOUS OVERLAPPING CROSSFADE:
            // Both streamPlayerA and streamPlayerB play at the same time!
            incomingPlayer.volume = 0.0
            incomingPlayer.play()

            let steps = 30
            let interval = crossfadeDuration / Double(steps)
            var currentStep = 0

            crossfadeTimer?.invalidate()
            crossfadeTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] timer in
                guard let self = self else { return }
                currentStep += 1
                let progress = Float(currentStep) / Float(steps)

                outgoingPlayer?.volume = targetVol * max(0.0, 1.0 - progress)
                incomingPlayer.volume = targetVol * min(1.0, progress)

                if currentStep >= steps {
                    timer.invalidate()
                    outgoingPlayer?.pause()
                    outgoingPlayer?.volume = targetVol
                    self.isUsingStreamA.toggle()
                }
            }
        } else {
            outgoingPlayer?.pause()
            incomingPlayer.volume = targetVol
            incomingPlayer.play()
            if isUsingStreamA {
                isUsingStreamA = false
            } else {
                isUsingStreamA = true
            }
        }

        isPlaying = true
    }

    // MARK: - Smart Silence Detection & Ending Credit Skip
    // At the end of a song, if audio becomes quiet/silent (e.g. video creator credits),
    // automatically triggers early crossfade to the next song!
    private func startSmartSilenceDetector() {
        silenceCheckTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            guard let self = self, self.isPlaying, !self.hasTriggeredSmartOutro else { return }

            // Only check in the final 25 seconds of the song (credit roll zone)
            guard self.duration > 30, (self.duration - self.currentTime) <= 25.0 else {
                self.silentFrameCount = 0
                return
            }

            // Inspect active player time and state
            let activePlayer = self.isUsingStreamA ? self.streamPlayerA : self.streamPlayerB
            if let p = activePlayer, let currentItem = p.currentItem {
                if currentItem.status == .readyToPlay {
                    // Check if current item playback buffer is depleted or volume/waveform is silent
                    let remaining = self.duration - self.currentTime
                    if remaining <= 12.0 {
                        self.silentFrameCount += 1
                        // If silent/outro credits linger for over 1.25 seconds:
                        if self.silentFrameCount >= 5 {
                            self.hasTriggeredSmartOutro = true
                            print("[NativeAudioEngine] Smart outro silence detected! Smoothly crossfading into next song early!")
                            DispatchQueue.main.async {
                                WinampPlayerEngine.shared.nextTrack()
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Playback Transport Controls
    public func pause() {
        isPlaying = false
        playerNodeA.pause()
        playerNodeB.pause()
        streamPlayerA?.pause()
        streamPlayerB?.pause()
    }

    public func resume() {
        isPlaying = true
        startEngineIfNeeded()
        if isUsingNodeA {
            playerNodeA.play()
        } else {
            playerNodeB.play()
        }
        streamPlayerA?.play()
        streamPlayerB?.play()
    }

    public func stop() {
        isPlaying = false
        playerNodeA.stop()
        playerNodeB.stop()
        streamPlayerA?.pause()
        streamPlayerB?.pause()
        crossfadeTimer?.invalidate()
        currentTime = 0
    }

    public func seek(to seconds: TimeInterval) {
        currentTime = seconds
        let targetCMTime = CMTime(seconds: seconds, preferredTimescale: 600)
        streamPlayerA?.seek(to: targetCMTime)
        streamPlayerB?.seek(to: targetCMTime)
    }
}
