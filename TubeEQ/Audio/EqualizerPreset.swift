import Foundation

public enum EqualizerPreset: String, CaseIterable, Identifiable {
    case flat = "Flat"
    case bassBoost = "Bass Boost"
    case trebleBoost = "Treble Boost"
    case rock = "Rock"
    case pop = "Pop"
    case jazz = "Jazz"
    case electronic = "Electronic"
    case vocalBoost = "Vocal Boost"
    case acoustic = "Acoustic"

    public var id: String { rawValue }

    /// 10 Gains corresponding to: [32, 64, 125, 250, 500, 1k, 2k, 4k, 8k, 16k] Hz
    public var gains: [Float] {
        switch self {
        case .flat:
            return [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
        case .bassBoost:
            return [6.0, 5.5, 4.0, 2.5, 1.0, 0.0, 0.0, 0.0, 0.0, 0.0]
        case .trebleBoost:
            return [0.0, 0.0, 0.0, 0.0, 1.0, 2.0, 3.5, 5.0, 6.0, 6.5]
        case .rock:
            return [4.5, 3.5, 2.0, 0.0, -1.0, 0.0, 2.0, 3.5, 4.0, 4.5]
        case .pop:
            return [-1.0, 1.0, 2.5, 3.0, 2.0, 0.0, -1.0, 1.0, 2.0, 2.5]
        case .jazz:
            return [3.0, 2.5, 1.5, 2.0, -1.0, -1.0, 0.0, 1.5, 2.5, 3.0]
        case .electronic:
            return [5.0, 4.5, 2.0, 0.0, -1.5, 1.5, 0.5, 2.0, 4.0, 4.5]
        case .vocalBoost:
            return [-2.0, -1.5, 0.0, 2.5, 4.0, 4.5, 3.5, 1.0, 0.0, -1.0]
        case .acoustic:
            return [3.5, 3.0, 2.0, 1.0, 1.5, 1.5, 2.5, 3.0, 3.5, 2.5]
        }
    }
}
