import Foundation

public enum EqualizerPreset: String, CaseIterable, Identifiable {
    case flat = "Flat"
    case rock = "Rock"
    case pop = "Pop"
    case club = "Club"
    case dance = "Dance"
    case techno = "Techno"
    case fullBass = "Full Bass"
    case fullBassTreble = "Full Bass & Treble"
    case fullTreble = "Full Treble"
    case live = "Live"
    case party = "Party"
    case soft = "Soft"
    case vocal = "Vocal Boost"
    case acoustic = "Acoustic"

    public var id: String { rawValue }

    /// 10 Gains corresponding to Classic Winamp Bands:
    /// [70Hz, 180Hz, 320Hz, 600Hz, 1kHz, 3kHz, 6kHz, 12kHz, 14kHz, 16kHz]
    public var gains: [Float] {
        switch self {
        case .flat:
            return [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
        case .rock:
            return [4.5, 3.0, -1.0, -2.5, -0.5, 2.0, 4.5, 6.0, 6.0, 6.0]
        case .pop:
            return [-1.0, 1.0, 3.5, 4.0, 3.0, 0.0, -1.0, -1.0, -1.0, -1.0]
        case .club:
            return [0.0, 0.0, 2.0, 3.0, 3.0, 3.0, 2.0, 0.0, 0.0, 0.0]
        case .dance:
            return [6.0, 5.0, 1.5, 0.0, 0.0, -3.0, -3.5, 0.0, 4.5, 5.5]
        case .techno:
            return [5.5, 4.0, 0.0, -3.0, -2.5, 0.0, 5.0, 6.0, 6.0, 5.5]
        case .fullBass:
            return [7.5, 6.5, 6.0, 4.0, 1.5, -2.0, -5.0, -7.0, -7.5, -8.0]
        case .fullBassTreble:
            return [5.0, 4.0, 0.0, -4.5, -3.0, 1.0, 5.0, 6.5, 7.0, 7.5]
        case .fullTreble:
            return [-6.0, -6.0, -6.0, -2.5, 1.5, 6.0, 9.0, 9.5, 10.0, 10.5]
        case .live:
            return [-3.0, 0.0, 2.5, 3.5, 3.5, 3.5, 2.5, 1.5, 1.5, 1.0]
        case .party:
            return [4.5, 4.5, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 4.5, 4.5]
        case .soft:
            return [3.0, 1.0, 0.0, -1.5, -0.5, 2.5, 5.0, 6.0, 7.0, 7.5]
        case .vocal:
            return [-1.5, -3.0, -3.0, 1.0, 4.5, 4.0, 2.5, 0.5, -1.0, -2.5]
        case .acoustic:
            return [3.5, 3.0, 2.0, 1.0, 1.5, 1.5, 2.5, 3.0, 3.5, 2.5]
        }
    }
}
