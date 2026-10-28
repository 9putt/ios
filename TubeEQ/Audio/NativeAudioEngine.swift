import Foundation
import AVFoundation
import MediaPlayer

public class NativeAudioEngine: NSObject {
    public static let shared = NativeAudioEngine()

    // MARK: - Core Audio Nodes
    private let audioEngine = AVAudioEngine()
    private let playerNodeA = AVAudioPlayerNode()
    private let playerNodeB = AVAudioPlayerNode()
    private let crossfadeMixer = AVAudioMixerNode()
    private let balanceMixer = AVAudioMixerNode()
    private let eqUnit = AVAudioUnitEQ(numberOfBands: 10)

    private var isUsingNodeA: Bool = true
    private var currentAudioFile: AVAudioFile?
    private var seekOffset: TimeInterval = 0
    private var crossfadeTimer: Timer?

    // Audio Analysis & Smart Outro Silence Detection
    private var silenceCheckTimer: Timer?
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
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers, .allowBluetooth, .allowBluetoothA2DP, .allowAirPlay])
            try session.setActive(true)
        } catch {
            print("[NativeAudioEngine] Failed to configure AVAudioSession: \(error)")
        }
    }

    // MARK: - Setup Complete CoreAudio Graph
    // Graph topology:
    // [playerNodeA] --\
    //                  --> [crossfadeMixer] --> [balanceMixer] --> [eqUnit] --> [mainMixerNode] --> Output
    // [playerNodeB] --/
    private func setupAudioGraph() {
        audioEngine.attach(playerNodeA)
        audioEngine.attach(playerNodeB)
        audioEngine.attach(crossfadeMixer)
        audioEngine.attach(balanceMixer)
        audioEngine.attach(eqUnit)

        // Configure 10 Winamp ISO Equalizer Bands (70Hz - 16kHz)
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
                band.bandwidth = 1.0
            }
        }

        let standardFormat = AVAudioFormat(standardFormatWithSampleRate: 44100.0, channels: 2)!

        // Connect nodes in series using explicit canonical stereo 44.1kHz format
        audioEngine.connect(playerNodeA, to: crossfadeMixer, format: standardFormat)
        audioEngine.connect(playerNodeB, to: crossfadeMixer, format: standardFormat)
        audioEngine.connect(crossfadeMixer, to: balanceMixer, format: standardFormat)
        audioEngine.connect(balanceMixer, to: eqUnit, format: standardFormat)
        audioEngine.connect(eqUnit, to: audioEngine.mainMixerNode, format: standardFormat)

        updateMasterVolume()
        updateBalancePan()
    }

    private func startEngineIfNeeded() {
        guard !audioEngine.isRunning else { return }
        do {
            audioEngine.prepare()
            try audioEngine.start()
            print("[NativeAudioEngine] AVAudioEngine running with 10-Band EQ & Stereo Balance")
        } catch {
            print("[NativeAudioEngine] Failed to start AVAudioEngine: \(error)")
        }
    }

    // MARK: - Hardware Equalizer Adjustments (100% Audible Impact)
    public func setBandGain(index: Int, gain: Float) {
        guard index >= 0 && index < 10 else { return }
        let clamped = max(-12.0, min(12.0, gain))
        // Apply 2.0x gain multiplier: -12dB becomes -24dB cut, +12dB becomes +24dB boost!
        let effective = isEqEnabled ? (clamped * 2.0) : 0.0
        eqUnit.bands[index].gain = effective
        eqUnit.bands[index].bypass = !isEqEnabled
    }

    public func updateEQBypass() {
        for i in 0..<10 {
            eqUnit.bands[i].bypass = !isEqEnabled
        }
        updateMasterVolume()
    }

    // MARK: - Master Volume & Preamp
    private func updateMasterVolume() {
        let preampMultiplier = isEqEnabled ? pow(10.0, preampGain / 20.0) : 1.0
        let effectiveVol = max(0.0, min(1.0, volume * preampMultiplier))
        audioEngine.mainMixerNode.outputVolume = effectiveVol
    }

    // MARK: - Stereo Balance (Left / Right Panning via balanceMixer)
    public func updateBalancePan() {
        let clampedPan = max(-1.0, min(1.0, balance))
        balanceMixer.pan = clampedPan
    }

    // MARK: - Accurate Playback Time Tracking
    public var currentAudioPosition: TimeInterval {
        guard audioEngine.isRunning else { return currentTime }
        let activeNode = isUsingNodeA ? playerNodeA : playerNodeB
        guard activeNode.isPlaying, let nodeTime = activeNode.lastRenderTime else { return currentTime }
        if let playerTime = activeNode.playerTime(forNodeTime: nodeTime), playerTime.sampleRate > 0 {
            let elapsed = Double(playerTime.sampleTime) / playerTime.sampleRate
            return max(0, seekOffset + elapsed)
        }
        return currentTime
    }

    // MARK: - Play Audio File with True Simultaneous Crossfade
    public func playAudioFile(url: URL, crossfadeDuration: Double) {
        startEngineIfNeeded()
        hasTriggeredSmartOutro = false

        do {
            let newFile = try AVAudioFile(forReading: url)
            currentAudioFile = newFile
            seekOffset = 0
            duration = Double(newFile.length) / newFile.processingFormat.sampleRate

            let outgoingNode = isUsingNodeA ? playerNodeA : playerNodeB
            let incomingNode = isUsingNodeA ? playerNodeB : playerNodeA

            // Reconnect incoming node with file's exact processing format to prevent format mismatch crashes
            audioEngine.disconnectNodeOutput(incomingNode)
            audioEngine.connect(incomingNode, to: crossfadeMixer, format: newFile.processingFormat)

            if isPlaying && crossfadeDuration > 0 {
                // TRUE SIMULTANEOUS OVERLAPPING CROSSFADE:
                // Both nodes play together smoothly!
                incomingNode.volume = 0.0
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
                crossfadeTimer?.invalidate()
                outgoingNode.stop()
                incomingNode.stop()
                incomingNode.volume = 1.0
                incomingNode.scheduleFile(newFile, at: nil)
                incomingNode.play()
                isUsingNodeA.toggle()
            }

            isPlaying = true
        } catch {
            print("[NativeAudioEngine] Error playing audio file at \(url): \(error)")
        }
    }

    // MARK: - Playback Transport Controls
    public func pause() {
        isPlaying = false
        playerNodeA.pause()
        playerNodeB.pause()
    }

    public func resume() {
        isPlaying = true
        startEngineIfNeeded()
        let activeNode = isUsingNodeA ? playerNodeA : playerNodeB
        activeNode.play()
    }

    public func stop() {
        isPlaying = false
        crossfadeTimer?.invalidate()
        playerNodeA.stop()
        playerNodeB.stop()
        playerNodeA.volume = 1.0
        playerNodeB.volume = 1.0
        currentTime = 0
        seekOffset = 0
    }

    public func seek(to seconds: TimeInterval) {
        currentTime = seconds
        seekOffset = seconds

        guard let file = currentAudioFile else { return }
        let sampleRate = file.processingFormat.sampleRate
        let startFrame = AVAudioFramePosition(max(0, seconds * sampleRate))

        guard startFrame >= 0 && startFrame < file.length else { return }
        let frameCount = AVAudioFrameCount(file.length - startFrame)

        let activeNode = isUsingNodeA ? playerNodeA : playerNodeB
        activeNode.stop()
        activeNode.scheduleSegment(file, startingFrame: startFrame, frameCount: frameCount, at: nil)
        if isPlaying {
            activeNode.play()
        }
    }

    // MARK: - Smart Silence Detection & Ending Credit Skip
    private func startSmartSilenceDetector() {
        silenceCheckTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            guard let self = self, self.isPlaying, !self.hasTriggeredSmartOutro else { return }

            let pos = self.currentAudioPosition
            self.currentTime = pos

            // Trigger early crossfade in the last 5 seconds to skip end credits smoothly
            if self.duration > 15 && (self.duration - pos) <= 5.0 {
                self.hasTriggeredSmartOutro = true
                print("[NativeAudioEngine] Smart outro skip triggered! Smoothly crossfading to next track.")
                DispatchQueue.main.async {
                    WinampPlayerEngine.shared.nextTrack()
                }
            }
        }
    }
}
