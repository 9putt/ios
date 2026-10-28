import Foundation
import AVFoundation
import MediaPlayer

public class NativeAudioEngine: NSObject {
    public static let shared = NativeAudioEngine()

    // MARK: - Core Audio Engine Components
    private let audioEngine = AVAudioEngine()
    private let eqUnit = AVAudioUnitEQ(numberOfBands: 10)
    private let playerNodeA = AVAudioPlayerNode()
    private let playerNodeB = AVAudioPlayerNode()
    private var isUsingNodeA: Bool = true

    // Direct AVPlayer instances for instant streaming crossfade
    private var streamPlayerA: AVPlayer?
    private var streamPlayerB: AVPlayer?
    private var isUsingStreamA: Bool = true
    private var streamCrossfadeTimer: Timer?

    // Audio Files & Cache
    private var currentAudioFileA: AVAudioFile?
    private var currentAudioFileB: AVAudioFile?
    private var isEngineRunning: Bool = false

    // State
    public private(set) var isPlaying: Bool = false
    public var currentTime: TimeInterval = 0
    public var duration: TimeInterval = 0
    public var volume: Float = 0.85 {
        didSet {
            updateMasterVolume()
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

        // Configure 10 Winamp Equalizer Bands
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

        // Connect Nodes
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
            isEngineRunning = true
            print("[NativeAudioEngine] AVAudioEngine started successfully with 10-Band Hardware EQ")
        } catch {
            print("[NativeAudioEngine] Failed to start AVAudioEngine: \(error)")
        }
    }

    // MARK: - Hardware Equalizer Adjustments (100% Audible Impact)
    public func setBandGain(index: Int, gain: Float) {
        guard index >= 0 && index < 10 else { return }
        let clamped = max(-12.0, min(12.0, gain))
        // Apply 1.5x gain multiplier to deliver punchy, distinct audible differences
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
        // Preamp multiplier: gain of -12dB to +12dB
        let preampMultiplier = isEqEnabled ? pow(10.0, preampGain / 20.0) : 1.0
        let effectiveVol = max(0.0, min(1.0, volume * preampMultiplier))

        audioEngine.mainMixerNode.outputVolume = effectiveVol
        streamPlayerA?.volume = effectiveVol
        streamPlayerB?.volume = effectiveVol
    }

    // MARK: - Play Local Audio File with Dual-Node Hardware Crossfade
    public func playAudioFile(url: URL, crossfadeDuration: Double) {
        startEngineIfNeeded()

        do {
            let newFile = try AVAudioFile(forReading: url)
            duration = Double(newFile.length) / newFile.processingFormat.sampleRate

            let activeNode = isUsingNodeA ? playerNodeA : playerNodeB
            let nextNode = isUsingNodeA ? playerNodeB : playerNodeA

            if isPlaying && crossfadeDuration > 0 {
                // Perform real native CoreAudio Crossfade
                nextNode.volume = 0.0
                nextNode.scheduleFile(newFile, at: nil)
                nextNode.play()

                let steps = 20
                let interval = crossfadeDuration / Double(steps)
                var currentStep = 0

                streamCrossfadeTimer?.invalidate()
                streamCrossfadeTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] timer in
                    guard let self = self else { return }
                    currentStep += 1
                    let progress = Float(currentStep) / Float(steps)

                    activeNode.volume = max(0.0, 1.0 - progress)
                    nextNode.volume = min(1.0, progress)

                    if currentStep >= steps {
                        timer.invalidate()
                        activeNode.stop()
                        activeNode.volume = 1.0
                        self.isUsingNodeA.toggle()
                    }
                }
            } else {
                activeNode.stop()
                nextNode.stop()
                activeNode.volume = 1.0
                activeNode.scheduleFile(newFile, at: nil)
                activeNode.play()
            }

            isPlaying = true
        } catch {
            print("[NativeAudioEngine] Error loading audio file: \(error)")
        }
    }

    // MARK: - Play Streaming URL with True Native Swift Crossfade
    public func playStreamURL(url: URL, crossfadeDuration: Double) {
        let activePlayer = isUsingStreamA ? streamPlayerA : streamPlayerB
        let nextPlayer = AVPlayer(url: url)
        let targetVol = max(0.0, min(1.0, volume * (isEqEnabled ? pow(10.0, preampGain / 20.0) : 1.0)))

        if isUsingStreamA {
            streamPlayerB = nextPlayer
        } else {
            streamPlayerA = nextPlayer
        }

        if isPlaying && crossfadeDuration > 0 && activePlayer != nil {
            // Swift Native Volume Crossfade (100% audible, operates outside Safari WebKit!)
            nextPlayer.volume = 0.0
            nextPlayer.play()

            let steps = 25
            let interval = crossfadeDuration / Double(steps)
            var currentStep = 0

            streamCrossfadeTimer?.invalidate()
            streamCrossfadeTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] timer in
                guard let self = self else { return }
                currentStep += 1
                let progress = Float(currentStep) / Float(steps)

                activePlayer?.volume = targetVol * max(0.0, 1.0 - progress)
                nextPlayer.volume = targetVol * min(1.0, progress)

                if currentStep >= steps {
                    timer.invalidate()
                    activePlayer?.pause()
                    activePlayer?.volume = targetVol
                    self.isUsingStreamA.toggle()
                }
            }
        } else {
            activePlayer?.pause()
            nextPlayer.volume = targetVol
            nextPlayer.play()
            if isUsingStreamA {
                isUsingStreamA = false
            } else {
                isUsingStreamA = true
            }
        }

        isPlaying = true
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
        streamCrossfadeTimer?.invalidate()
        currentTime = 0
    }

    public func seek(to seconds: TimeInterval) {
        currentTime = seconds
        let targetCMTime = CMTime(seconds: seconds, preferredTimescale: 600)
        streamPlayerA?.seek(to: targetCMTime)
        streamPlayerB?.seek(to: targetCMTime)
    }
}
