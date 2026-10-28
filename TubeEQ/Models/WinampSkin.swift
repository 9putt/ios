import SwiftUI

public enum WinampSkinPreset: String, CaseIterable, Identifiable {
    case classicModern = "Classic Modern"
    case classic1998 = "Classic 1998"
    case obsidianBento = "Bento Dark"
    case cyberMatrix = "Cyber Matrix"
    case champagneGold = "Champagne Gold"
    case solarFlare = "Solar Flare"

    public var id: String { rawValue }

    // Window Body Background
    public var windowBackground: LinearGradient {
        switch self {
        case .classicModern:
            return LinearGradient(
                colors: [Color(red: 0.16, green: 0.18, blue: 0.25), Color(red: 0.10, green: 0.11, blue: 0.16)],
                startPoint: .top, endPoint: .bottom
            )
        case .classic1998:
            return LinearGradient(
                colors: [Color(red: 0.22, green: 0.22, blue: 0.24), Color(red: 0.14, green: 0.14, blue: 0.15)],
                startPoint: .top, endPoint: .bottom
            )
        case .obsidianBento:
            return LinearGradient(
                colors: [Color(red: 0.08, green: 0.09, blue: 0.12), Color(red: 0.03, green: 0.03, blue: 0.05)],
                startPoint: .top, endPoint: .bottom
            )
        case .cyberMatrix:
            return LinearGradient(
                colors: [Color(red: 0.03, green: 0.08, blue: 0.04), Color(red: 0.01, green: 0.03, blue: 0.01)],
                startPoint: .top, endPoint: .bottom
            )
        case .champagneGold:
            return LinearGradient(
                colors: [Color(red: 0.26, green: 0.22, blue: 0.16), Color(red: 0.16, green: 0.13, blue: 0.09)],
                startPoint: .top, endPoint: .bottom
            )
        case .solarFlare:
            return LinearGradient(
                colors: [Color(red: 0.25, green: 0.08, blue: 0.08), Color(red: 0.14, green: 0.03, blue: 0.03)],
                startPoint: .top, endPoint: .bottom
            )
        }
    }

    // Title Bar Gradient
    public var titleBarGradient: LinearGradient {
        switch self {
        case .classicModern:
            return LinearGradient(
                colors: [Color(red: 0.24, green: 0.30, blue: 0.44), Color(red: 0.12, green: 0.16, blue: 0.26)],
                startPoint: .top, endPoint: .bottom
            )
        case .classic1998:
            return LinearGradient(
                colors: [Color(red: 0.32, green: 0.32, blue: 0.36), Color(red: 0.18, green: 0.18, blue: 0.20)],
                startPoint: .top, endPoint: .bottom
            )
        case .obsidianBento:
            return LinearGradient(
                colors: [Color(red: 0.15, green: 0.20, blue: 0.30), Color(red: 0.06, green: 0.08, blue: 0.14)],
                startPoint: .top, endPoint: .bottom
            )
        case .cyberMatrix:
            return LinearGradient(
                colors: [Color(red: 0.06, green: 0.22, blue: 0.08), Color(red: 0.02, green: 0.09, blue: 0.03)],
                startPoint: .top, endPoint: .bottom
            )
        case .champagneGold:
            return LinearGradient(
                colors: [Color(red: 0.42, green: 0.34, blue: 0.22), Color(red: 0.22, green: 0.18, blue: 0.11)],
                startPoint: .top, endPoint: .bottom
            )
        case .solarFlare:
            return LinearGradient(
                colors: [Color(red: 0.44, green: 0.14, blue: 0.10), Color(red: 0.22, green: 0.05, blue: 0.04)],
                startPoint: .top, endPoint: .bottom
            )
        }
    }

    // Title Bar Text Color
    public var titleBarTextColor: Color {
        switch self {
        case .classicModern: return Color(red: 0.85, green: 0.92, blue: 1.0)
        case .classic1998: return Color(red: 0.95, green: 0.95, blue: 0.95)
        case .obsidianBento: return Color(red: 0.4, green: 0.8, blue: 1.0)
        case .cyberMatrix: return Color(red: 0.3, green: 1.0, blue: 0.4)
        case .champagneGold: return Color(red: 1.0, green: 0.90, blue: 0.70)
        case .solarFlare: return Color(red: 1.0, green: 0.75, blue: 0.60)
        }
    }

    // LCD Screen Background
    public var lcdBackground: Color {
        switch self {
        case .classicModern, .classic1998: return Color(red: 0.02, green: 0.03, blue: 0.05)
        case .obsidianBento: return Color(red: 0.01, green: 0.02, blue: 0.04)
        case .cyberMatrix: return Color(red: 0.01, green: 0.04, blue: 0.02)
        case .champagneGold: return Color(red: 0.06, green: 0.04, blue: 0.02)
        case .solarFlare: return Color(red: 0.06, green: 0.02, blue: 0.02)
        }
    }

    // LED Digits & Main Text Color
    public var ledColor: Color {
        switch self {
        case .classicModern: return Color(red: 0.0, green: 1.0, blue: 0.35)
        case .classic1998: return Color(red: 0.0, green: 1.0, blue: 0.30)
        case .obsidianBento: return Color(red: 0.2, green: 0.85, blue: 1.0)
        case .cyberMatrix: return Color(red: 0.2, green: 1.0, blue: 0.3)
        case .champagneGold: return Color(red: 1.0, green: 0.78, blue: 0.28)
        case .solarFlare: return Color(red: 1.0, green: 0.35, blue: 0.20)
        }
    }

    // Marquee Color
    public var marqueeColor: Color {
        switch self {
        case .classicModern: return Color(red: 0.0, green: 1.0, blue: 0.35)
        case .classic1998: return Color(red: 0.0, green: 1.0, blue: 0.30)
        case .obsidianBento: return Color(red: 0.3, green: 0.9, blue: 1.0)
        case .cyberMatrix: return Color(red: 0.3, green: 1.0, blue: 0.4)
        case .champagneGold: return Color(red: 1.0, green: 0.85, blue: 0.4)
        case .solarFlare: return Color(red: 1.0, green: 0.45, blue: 0.25)
        }
    }

    // Slider Accent / Fill Color
    public var sliderAccentColor: Color {
        switch self {
        case .classicModern: return Color(red: 0.2, green: 0.6, blue: 1.0)
        case .classic1998: return Color(red: 0.3, green: 0.7, blue: 0.9)
        case .obsidianBento: return Color(red: 0.0, green: 0.8, blue: 1.0)
        case .cyberMatrix: return Color(red: 0.1, green: 0.9, blue: 0.3)
        case .champagneGold: return Color(red: 0.9, green: 0.7, blue: 0.3)
        case .solarFlare: return Color(red: 1.0, green: 0.4, blue: 0.2)
        }
    }

    // Button Background
    public var buttonBackground: LinearGradient {
        switch self {
        case .classicModern:
            return LinearGradient(
                colors: [Color(red: 0.30, green: 0.34, blue: 0.44), Color(red: 0.18, green: 0.20, blue: 0.28)],
                startPoint: .top, endPoint: .bottom
            )
        case .classic1998:
            return LinearGradient(
                colors: [Color(red: 0.38, green: 0.38, blue: 0.40), Color(red: 0.24, green: 0.24, blue: 0.26)],
                startPoint: .top, endPoint: .bottom
            )
        case .obsidianBento:
            return LinearGradient(
                colors: [Color(red: 0.18, green: 0.22, blue: 0.28), Color(red: 0.10, green: 0.12, blue: 0.16)],
                startPoint: .top, endPoint: .bottom
            )
        case .cyberMatrix:
            return LinearGradient(
                colors: [Color(red: 0.08, green: 0.24, blue: 0.10), Color(red: 0.03, green: 0.12, blue: 0.04)],
                startPoint: .top, endPoint: .bottom
            )
        case .champagneGold:
            return LinearGradient(
                colors: [Color(red: 0.45, green: 0.38, blue: 0.26), Color(red: 0.26, green: 0.21, blue: 0.14)],
                startPoint: .top, endPoint: .bottom
            )
        case .solarFlare:
            return LinearGradient(
                colors: [Color(red: 0.45, green: 0.18, blue: 0.14), Color(red: 0.25, green: 0.08, blue: 0.06)],
                startPoint: .top, endPoint: .bottom
            )
        }
    }

    // Border Bevel Colors
    public var borderLight: Color {
        switch self {
        case .classicModern: return Color(white: 0.45)
        case .classic1998: return Color(white: 0.50)
        case .obsidianBento: return Color(white: 0.30)
        case .cyberMatrix: return Color(red: 0.1, green: 0.4, blue: 0.2)
        case .champagneGold: return Color(red: 0.6, green: 0.5, blue: 0.35)
        case .solarFlare: return Color(red: 0.6, green: 0.25, blue: 0.2)
        }
    }

    public var borderDark: Color {
        return Color(white: 0.05)
    }

    // Spectrum Gradient Colors (Bottom to Top)
    public var spectrumColors: [Color] {
        switch self {
        case .classicModern, .classic1998:
            return [.green, .yellow, .red]
        case .obsidianBento:
            return [Color.blue, Color.cyan, Color.white]
        case .cyberMatrix:
            return [Color(red: 0.0, green: 0.6, blue: 0.2), Color(red: 0.2, green: 1.0, blue: 0.3), Color(red: 0.8, green: 1.0, blue: 0.8)]
        case .champagneGold:
            return [Color(red: 0.8, green: 0.5, blue: 0.1), Color(red: 1.0, green: 0.8, blue: 0.2), Color.white]
        case .solarFlare:
            return [Color(red: 0.8, green: 0.2, blue: 0.0), Color(red: 1.0, green: 0.6, blue: 0.0), Color.yellow]
        }
    }
}
