import Foundation
import AVFoundation
import Combine

/// Central Audio Engine Manager providing real-time 10-Band EQ, Reverb, and Background Audio routing.
public class AudioEngineManager: ObservableObject {
    public static let shared = AudioEngineManager()

    // MARK: - Core Audio Components
    private let audioEngine = AVAudioEngine()
    private let playerNode = AVAudioPlayerNode()
    private let eqUnit = AVAudioUnitEQ(numberOfBands: 10)
    private let reverbUnit = AVAudioUnitReverb()
    
    // Frequency bands (Hz)
    public let bandFrequencies: [Float] = [32, 64, 125, 250, 500, 1000, 2000, 4000, 8000, 16000]

    // MARK: - Published UI States
    @Published public var bandGains: [Float] = Array(repeating: 0.0, count: 10)
    @Published public var isEqBypassed: Bool = false {
        didSet { eqUnit.bypass = isEqBypassed }
    }
    @Published public var reverbWetDryMix: Float = 0.0 {
        didSet { reverbUnit.wetDryMix = reverbWetDryMix }
    }
    @Published public var isPlaying: Bool = false
    @Published public var currentPreset: EqualizerPreset = .flat

    private init() {
        configureAudioSession()
        setupAudioGraph()
    }

    // MARK: - Audio Session Configuration
    private func configureAudioSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, mode: .moviePlayback, options: [.allowBluetooth, .allowBluetoothA2DP, .allowAirPlay])
            try session.setActive(true)
        } catch {
            print("[AudioEngine] Failed to activate AVAudioSession: \(error.localizedDescription)")
        }
    }

    // MARK: - Audio Graph Setup
    private func setupAudioGraph() {
        audioEngine.attach(playerNode)
        audioEngine.attach(eqUnit)
        audioEngine.attach(reverbUnit)

        // Configure 10-Band Parametric EQ
        for (i, freq) in bandFrequencies.enumerated() {
            let band = eqUnit.bands[i]
            band.frequency = freq
            band.bandwidth = 0.6
            band.filterType = .parametric
            band.gain = 0.0
            band.bypass = false
        }

        // Configure Reverb
        reverbUnit.loadFactoryPreset(.mediumHall)
        reverbUnit.wetDryMix = 0.0

        // Connect Nodes: Player -> EQ -> Reverb -> MainMixer
        let format = audioEngine.mainMixerNode.outputFormat(forBus: 0)
        audioEngine.connect(playerNode, to: eqUnit, format: format)
        audioEngine.connect(eqUnit, to: reverbUnit, format: format)
        audioEngine.connect(reverbUnit, to: audioEngine.mainMixerNode, format: format)

        do {
            try audioEngine.start()
        } catch {
            print("[AudioEngine] Could not start audioEngine: \(error.localizedDescription)")
        }
    }

    // MARK: - Public Control APIs
    public func setGain(forBand index: Int, gain: Float) {
        guard index >= 0 && index < bandFrequencies.count else { return }
        let clampedGain = max(-15.0, min(15.0, gain))
        bandGains[index] = clampedGain
        eqUnit.bands[index].gain = clampedGain
    }

    public func applyPreset(_ preset: EqualizerPreset) {
        currentPreset = preset
        let gains = preset.gains
        for (i, gain) in gains.enumerated() {
            setGain(forBand: i, gain: gain)
        }
    }

    public func resetEQ() {
        applyPreset(.flat)
    }
}
