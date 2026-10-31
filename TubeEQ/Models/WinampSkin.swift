import SwiftUI

public enum WinampSkinPreset: String, CaseIterable, Identifiable {
    // 3 Brand New Custom App-Fitted Master Chassis Skins
    case audiophileGold = "Audiophile Master Chassis"
    case cyberpunkMatrix = "Cyber Terminal Matrix"
    case stealthCarbon = "Stealth Carbon Fiber"

    // 3 Brand New Dynamic Animated RGB Running Lights Skins
    case rgbChromaFlow = "RGB Chroma Flow (ไฟวิ่ง)"
    case rgbCyberWave = "Cyber Neon Pulse (ไฟวิ่ง)"
    case rgbLavaBlaze = "Lava Blaze Chase (ไฟวิ่ง)"

    // Classic & Modern Presets
    case classicModern = "Classic Modern"
    case classic1998 = "Classic 1998"
    case obsidianBento = "Bento Dark"
    case cyberMatrix = "Cyber Matrix"
    case champagneGold = "Champagne Gold"
    case solarFlare = "Solar Flare"
    case rgbNeon = "RGB Neon Cyber"
    case animeKawaii = "Anime Manga Pastel"
    case auroraGradient = "Aurora Cosmic"
    case sunsetVaporwave = "Sunset Vaporwave"
    case graphicBauhaus = "Graphic Bold Art"
    case retroSynthwave = "Retrowave 80s"

    // 5 High-Res Wallpaper Skins with Liquid Glass
    case cyberdeckHUD = "CyberDeck HUD 2077"
    case cosmosNebula = "Deep Cosmos Nebula"
    case neonSynthwave = "Neon Synthwave 80s"
    case obsidianGlass = "Obsidian Crystal Glass"
    case mechaTactical = "Mecha Tactical Console"

    public var id: String { rawValue }

    // Dynamic RGB Running Lights Mode
    public var isRGBRunningLight: Bool {
        switch self {
        case .rgbChromaFlow, .rgbCyberWave, .rgbLavaBlaze:
            return true
        default:
            return false
        }
    }

    public var rgbLightColors: [Color] {
        switch self {
        case .rgbChromaFlow:
            return [.red, .orange, .yellow, .green, .cyan, .blue, .purple, .red]
        case .rgbCyberWave:
            return [Color.cyan, Color(red: 0.1, green: 0.4, blue: 1.0), Color(red: 1.0, green: 0.0, blue: 0.75), Color.purple, Color.cyan]
        case .rgbLavaBlaze:
            return [Color.red, Color(red: 1.0, green: 0.4, blue: 0.0), Color.yellow, Color(red: 1.0, green: 0.1, blue: 0.0), Color.red]
        default:
            return []
        }
    }

    // Bundled Wallpaper Image Name (Tailored for app layout)
    public var backgroundImageName: String? {
        switch self {
        case .audiophileGold: return "bg_chassis_audiophile"
        case .cyberpunkMatrix: return "bg_chassis_cyberpunk"
        case .stealthCarbon: return "bg_chassis_stealth"
        case .cyberdeckHUD: return "bg_cyberdeck_hud"
        case .cosmosNebula: return "bg_cosmos_nebula"
        case .neonSynthwave: return "bg_neon_synthwave"
        case .obsidianGlass: return "bg_obsidian_glass"
        case .mechaTactical: return "bg_mecha_tactical"
        default: return nil
        }
    }

    public var hasBackgroundImage: Bool {
        return backgroundImageName != nil
    }

    public var isLiquidGlass: Bool {
        return hasBackgroundImage || isRGBRunningLight
    }

    // Window Body Background
    public var windowBackground: LinearGradient {
        switch self {
        case .audiophileGold:
            return LinearGradient(
                colors: [Color(red: 0.12, green: 0.14, blue: 0.18).opacity(0.35), Color(red: 0.06, green: 0.08, blue: 0.10).opacity(0.45)],
                startPoint: .top, endPoint: .bottom
            )
        case .cyberpunkMatrix:
            return LinearGradient(
                colors: [Color(red: 0.02, green: 0.10, blue: 0.16).opacity(0.35), Color(red: 0.01, green: 0.04, blue: 0.08).opacity(0.45)],
                startPoint: .top, endPoint: .bottom
            )
        case .stealthCarbon:
            return LinearGradient(
                colors: [Color(red: 0.10, green: 0.10, blue: 0.12).opacity(0.35), Color(red: 0.04, green: 0.04, blue: 0.06).opacity(0.45)],
                startPoint: .top, endPoint: .bottom
            )
        case .rgbChromaFlow:
            return LinearGradient(
                colors: [Color(red: 0.08, green: 0.08, blue: 0.12).opacity(0.85), Color(red: 0.02, green: 0.02, blue: 0.05).opacity(0.92)],
                startPoint: .top, endPoint: .bottom
            )
        case .rgbCyberWave:
            return LinearGradient(
                colors: [Color(red: 0.02, green: 0.06, blue: 0.12).opacity(0.85), Color(red: 0.01, green: 0.02, blue: 0.05).opacity(0.92)],
                startPoint: .top, endPoint: .bottom
            )
        case .rgbLavaBlaze:
            return LinearGradient(
                colors: [Color(red: 0.12, green: 0.03, blue: 0.02).opacity(0.85), Color(red: 0.04, green: 0.01, blue: 0.01).opacity(0.92)],
                startPoint: .top, endPoint: .bottom
            )
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
        case .rgbNeon:
            return LinearGradient(
                colors: [Color(red: 0.08, green: 0.05, blue: 0.16), Color(red: 0.03, green: 0.02, blue: 0.08)],
                startPoint: .top, endPoint: .bottom
            )
        case .animeKawaii:
            return LinearGradient(
                colors: [Color(red: 0.22, green: 0.16, blue: 0.28), Color(red: 0.14, green: 0.10, blue: 0.18)],
                startPoint: .top, endPoint: .bottom
            )
        case .auroraGradient:
            return LinearGradient(
                colors: [Color(red: 0.04, green: 0.12, blue: 0.18), Color(red: 0.02, green: 0.06, blue: 0.10)],
                startPoint: .top, endPoint: .bottom
            )
        case .sunsetVaporwave:
            return LinearGradient(
                colors: [Color(red: 0.18, green: 0.06, blue: 0.26), Color(red: 0.09, green: 0.02, blue: 0.14)],
                startPoint: .top, endPoint: .bottom
            )
        case .graphicBauhaus:
            return LinearGradient(
                colors: [Color(red: 0.15, green: 0.16, blue: 0.20), Color(red: 0.08, green: 0.09, blue: 0.11)],
                startPoint: .top, endPoint: .bottom
            )
        case .retroSynthwave:
            return LinearGradient(
                colors: [Color(red: 0.12, green: 0.04, blue: 0.22), Color(red: 0.04, green: 0.01, blue: 0.09)],
                startPoint: .top, endPoint: .bottom
            )
        case .cyberdeckHUD:
            return LinearGradient(
                colors: [Color(red: 0.0, green: 0.8, blue: 1.0).opacity(0.35), Color(red: 0.05, green: 0.15, blue: 0.35).opacity(0.45)],
                startPoint: .top, endPoint: .bottom
            )
        case .cosmosNebula:
            return LinearGradient(
                colors: [Color(red: 0.5, green: 0.1, blue: 0.8).opacity(0.35), Color(red: 0.10, green: 0.05, blue: 0.30).opacity(0.45)],
                startPoint: .top, endPoint: .bottom
            )
        case .neonSynthwave:
            return LinearGradient(
                colors: [Color(red: 1.0, green: 0.0, blue: 0.5).opacity(0.35), Color(red: 0.25, green: 0.05, blue: 0.35).opacity(0.45)],
                startPoint: .top, endPoint: .bottom
            )
        case .obsidianGlass:
            return LinearGradient(
                colors: [Color(red: 0.2, green: 0.25, blue: 0.3).opacity(0.35), Color(red: 0.08, green: 0.10, blue: 0.12).opacity(0.45)],
                startPoint: .top, endPoint: .bottom
            )
        case .mechaTactical:
            return LinearGradient(
                colors: [Color(red: 1.0, green: 0.5, blue: 0.0).opacity(0.35), Color(red: 0.15, green: 0.15, blue: 0.18).opacity(0.45)],
                startPoint: .top, endPoint: .bottom
            )
        }
    }

    // Title Bar Gradient
    public var titleBarGradient: LinearGradient {
        switch self {
        case .audiophileGold:
            return LinearGradient(
                colors: [Color(red: 0.83, green: 0.68, blue: 0.21).opacity(0.75), Color(red: 0.15, green: 0.18, blue: 0.22).opacity(0.80)],
                startPoint: .leading, endPoint: .trailing
            )
        case .cyberpunkMatrix:
            return LinearGradient(
                colors: [Color(red: 0.0, green: 0.9, blue: 1.0).opacity(0.75), Color(red: 0.9, green: 0.0, blue: 0.5).opacity(0.80)],
                startPoint: .leading, endPoint: .trailing
            )
        case .stealthCarbon:
            return LinearGradient(
                colors: [Color(red: 0.9, green: 0.15, blue: 0.2).opacity(0.75), Color(red: 0.15, green: 0.15, blue: 0.18).opacity(0.80)],
                startPoint: .leading, endPoint: .trailing
            )
        case .rgbChromaFlow:
            return LinearGradient(
                colors: [Color(red: 0.15, green: 0.15, blue: 0.22), Color(red: 0.08, green: 0.08, blue: 0.12)],
                startPoint: .leading, endPoint: .trailing
            )
        case .rgbCyberWave:
            return LinearGradient(
                colors: [Color(red: 0.0, green: 0.35, blue: 0.50), Color(red: 0.05, green: 0.10, blue: 0.25)],
                startPoint: .leading, endPoint: .trailing
            )
        case .rgbLavaBlaze:
            return LinearGradient(
                colors: [Color(red: 0.50, green: 0.15, blue: 0.05), Color(red: 0.20, green: 0.05, blue: 0.02)],
                startPoint: .leading, endPoint: .trailing
            )
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
        case .rgbNeon:
            return LinearGradient(
                colors: [Color(red: 0.0, green: 0.85, blue: 1.0), Color(red: 0.95, green: 0.05, blue: 0.6)],
                startPoint: .leading, endPoint: .trailing
            )
        case .animeKawaii:
            return LinearGradient(
                colors: [Color(red: 1.0, green: 0.65, blue: 0.75), Color(red: 0.75, green: 0.65, blue: 0.95)],
                startPoint: .leading, endPoint: .trailing
            )
        case .auroraGradient:
            return LinearGradient(
                colors: [Color(red: 0.0, green: 0.85, blue: 0.65), Color(red: 0.1, green: 0.45, blue: 0.9)],
                startPoint: .leading, endPoint: .trailing
            )
        case .sunsetVaporwave:
            return LinearGradient(
                colors: [Color(red: 1.0, green: 0.4, blue: 0.2), Color(red: 0.75, green: 0.1, blue: 0.6)],
                startPoint: .leading, endPoint: .trailing
            )
        case .graphicBauhaus:
            return LinearGradient(
                colors: [Color(red: 0.12, green: 0.32, blue: 0.72), Color(red: 0.06, green: 0.18, blue: 0.42)],
                startPoint: .top, endPoint: .bottom
            )
        case .retroSynthwave:
            return LinearGradient(
                colors: [Color(red: 0.6, green: 0.05, blue: 0.85), Color(red: 1.0, green: 0.15, blue: 0.5)],
                startPoint: .leading, endPoint: .trailing
            )
        case .cyberdeckHUD:
            return LinearGradient(
                colors: [Color(red: 0.0, green: 0.9, blue: 1.0).opacity(0.75), Color(red: 0.05, green: 0.25, blue: 0.65).opacity(0.80)],
                startPoint: .leading, endPoint: .trailing
            )
        case .cosmosNebula:
            return LinearGradient(
                colors: [Color(red: 0.65, green: 0.15, blue: 0.90).opacity(0.75), Color(red: 0.10, green: 0.15, blue: 0.50).opacity(0.80)],
                startPoint: .leading, endPoint: .trailing
            )
        case .neonSynthwave:
            return LinearGradient(
                colors: [Color(red: 1.0, green: 0.0, blue: 0.55).opacity(0.75), Color(red: 1.0, green: 0.55, blue: 0.0).opacity(0.80)],
                startPoint: .leading, endPoint: .trailing
            )
        case .obsidianGlass:
            return LinearGradient(
                colors: [Color(red: 0.30, green: 0.35, blue: 0.40).opacity(0.75), Color(red: 0.12, green: 0.14, blue: 0.16).opacity(0.80)],
                startPoint: .leading, endPoint: .trailing
            )
        case .mechaTactical:
            return LinearGradient(
                colors: [Color(red: 1.0, green: 0.45, blue: 0.0).opacity(0.75), Color(red: 0.15, green: 0.18, blue: 0.22).opacity(0.80)],
                startPoint: .leading, endPoint: .trailing
            )
        }
    }

    // Title Bar Text Color
    public var titleBarTextColor: Color {
        switch self {
        case .audiophileGold: return Color(red: 1.0, green: 0.90, blue: 0.60)
        case .cyberpunkMatrix: return Color(red: 0.85, green: 1.0, blue: 1.0)
        case .stealthCarbon: return Color(red: 1.0, green: 0.85, blue: 0.85)
        case .rgbChromaFlow, .rgbCyberWave, .rgbLavaBlaze: return Color.white
        case .classicModern: return Color(red: 0.85, green: 0.92, blue: 1.0)
        case .classic1998: return Color(red: 0.95, green: 0.95, blue: 0.95)
        case .obsidianBento: return Color(red: 0.4, green: 0.8, blue: 1.0)
        case .cyberMatrix: return Color(red: 0.3, green: 1.0, blue: 0.4)
        case .champagneGold: return Color(red: 1.0, green: 0.90, blue: 0.70)
        case .solarFlare: return Color(red: 1.0, green: 0.75, blue: 0.60)
        case .rgbNeon: return Color.white
        case .animeKawaii: return Color(red: 0.20, green: 0.08, blue: 0.25)
        case .auroraGradient: return Color(red: 0.90, green: 1.0, blue: 0.95)
        case .sunsetVaporwave: return Color(red: 1.0, green: 0.95, blue: 0.85)
        case .graphicBauhaus: return Color(red: 1.0, green: 0.86, blue: 0.1)
        case .retroSynthwave: return Color(red: 0.0, green: 1.0, blue: 0.95)
        case .cyberdeckHUD: return Color(red: 0.90, green: 1.0, blue: 1.0)
        case .cosmosNebula: return Color(red: 0.95, green: 0.90, blue: 1.0)
        case .neonSynthwave: return Color.white
        case .obsidianGlass: return Color(red: 0.90, green: 0.95, blue: 0.95)
        case .mechaTactical: return Color(red: 1.0, green: 0.95, blue: 0.85)
        }
    }

    // LCD Screen Background
    public var lcdBackground: Color {
        switch self {
        case .audiophileGold, .cyberpunkMatrix, .stealthCarbon:
            return Color.black.opacity(0.35)
        case .rgbChromaFlow, .rgbCyberWave, .rgbLavaBlaze:
            return Color.black.opacity(0.55)
        case .classicModern, .classic1998: return Color(red: 0.02, green: 0.03, blue: 0.05)
        case .obsidianBento: return Color(red: 0.01, green: 0.02, blue: 0.04)
        case .cyberMatrix: return Color(red: 0.01, green: 0.04, blue: 0.02)
        case .champagneGold: return Color(red: 0.06, green: 0.04, blue: 0.02)
        case .solarFlare: return Color(red: 0.06, green: 0.02, blue: 0.02)
        case .rgbNeon: return Color(red: 0.02, green: 0.01, blue: 0.05)
        case .animeKawaii: return Color(red: 0.10, green: 0.07, blue: 0.13)
        case .auroraGradient: return Color(red: 0.01, green: 0.05, blue: 0.07)
        case .sunsetVaporwave: return Color(red: 0.08, green: 0.02, blue: 0.12)
        case .graphicBauhaus: return Color(red: 0.05, green: 0.05, blue: 0.07)
        case .retroSynthwave: return Color(red: 0.06, green: 0.01, blue: 0.12)
        case .cyberdeckHUD, .cosmosNebula, .neonSynthwave, .obsidianGlass, .mechaTactical:
            return Color.black.opacity(0.30)
        }
    }

    // LED Digits & Main Text Color
    public var ledColor: Color {
        switch self {
        case .audiophileGold: return Color(red: 1.0, green: 0.80, blue: 0.25) // Hi-Fi Gold
        case .cyberpunkMatrix: return Color(red: 0.0, green: 0.95, blue: 1.0) // Electric Cyan
        case .stealthCarbon: return Color(red: 1.0, green: 0.20, blue: 0.25) // Crimson Sport
        case .rgbChromaFlow: return Color(red: 0.0, green: 1.0, blue: 0.65) // Neon Mint
        case .rgbCyberWave: return Color(red: 0.0, green: 0.90, blue: 1.0) // Laser Cyan
        case .rgbLavaBlaze: return Color(red: 1.0, green: 0.55, blue: 0.0) // Lava Amber
        case .classicModern: return Color(red: 0.0, green: 1.0, blue: 0.35)
        case .classic1998: return Color(red: 0.0, green: 1.0, blue: 0.30)
        case .obsidianBento: return Color(red: 0.2, green: 0.85, blue: 1.0)
        case .cyberMatrix: return Color(red: 0.2, green: 1.0, blue: 0.3)
        case .champagneGold: return Color(red: 1.0, green: 0.78, blue: 0.28)
        case .solarFlare: return Color(red: 1.0, green: 0.35, blue: 0.20)
        case .rgbNeon: return Color(red: 0.0, green: 1.0, blue: 0.85)
        case .animeKawaii: return Color(red: 1.0, green: 0.75, blue: 0.85)
        case .auroraGradient: return Color(red: 0.2, green: 1.0, blue: 0.7)
        case .sunsetVaporwave: return Color(red: 1.0, green: 0.85, blue: 0.3)
        case .graphicBauhaus: return Color(red: 1.0, green: 0.85, blue: 0.0)
        case .retroSynthwave: return Color(red: 0.0, green: 0.95, blue: 1.0)
        case .cyberdeckHUD: return Color(red: 0.0, green: 0.95, blue: 1.0)
        case .cosmosNebula: return Color(red: 0.10, green: 1.0, blue: 1.0)
        case .neonSynthwave: return Color(red: 1.0, green: 0.85, blue: 0.0)
        case .obsidianGlass: return Color(red: 0.0, green: 0.90, blue: 0.45)
        case .mechaTactical: return Color(red: 1.0, green: 0.60, blue: 0.0)
        }
    }

    // Marquee Color
    public var marqueeColor: Color {
        switch self {
        case .audiophileGold: return Color(red: 1.0, green: 0.88, blue: 0.50)
        case .cyberpunkMatrix: return Color(red: 0.5, green: 0.85, blue: 1.0)
        case .stealthCarbon: return Color(red: 1.0, green: 0.45, blue: 0.45)
        case .rgbChromaFlow: return Color(red: 0.6, green: 1.0, blue: 0.8)
        case .rgbCyberWave: return Color(red: 0.5, green: 0.8, blue: 1.0)
        case .rgbLavaBlaze: return Color(red: 1.0, green: 0.8, blue: 0.3)
        case .classicModern: return Color(red: 0.0, green: 1.0, blue: 0.35)
        case .classic1998: return Color(red: 0.0, green: 1.0, blue: 0.30)
        case .obsidianBento: return Color(red: 0.3, green: 0.9, blue: 1.0)
        case .cyberMatrix: return Color(red: 0.3, green: 1.0, blue: 0.4)
        case .champagneGold: return Color(red: 1.0, green: 0.85, blue: 0.4)
        case .solarFlare: return Color(red: 1.0, green: 0.45, blue: 0.25)
        case .rgbNeon: return Color(red: 1.0, green: 0.1, blue: 0.7)
        case .animeKawaii: return Color(red: 0.75, green: 0.95, blue: 0.8)
        case .auroraGradient: return Color(red: 0.3, green: 0.95, blue: 1.0)
        case .sunsetVaporwave: return Color(red: 1.0, green: 0.35, blue: 0.55)
        case .graphicBauhaus: return Color(red: 0.95, green: 0.95, blue: 0.95)
        case .retroSynthwave: return Color(red: 1.0, green: 0.0, blue: 0.65)
        case .cyberdeckHUD: return Color(red: 0.5, green: 0.85, blue: 1.0)
        case .cosmosNebula: return Color(red: 0.9, green: 0.5, blue: 1.0)
        case .neonSynthwave: return Color(red: 1.0, green: 0.25, blue: 0.55)
        case .obsidianGlass: return Color(red: 0.4, green: 0.95, blue: 0.65)
        case .mechaTactical: return Color(red: 1.0, green: 0.88, blue: 0.5)
        }
    }

    // Slider Accent / Fill Color
    public var sliderAccentColor: Color {
        switch self {
        case .audiophileGold: return Color(red: 0.95, green: 0.75, blue: 0.25)
        case .cyberpunkMatrix: return Color(red: 0.0, green: 0.85, blue: 1.0)
        case .stealthCarbon: return Color(red: 0.95, green: 0.15, blue: 0.2)
        case .rgbChromaFlow: return Color(red: 0.0, green: 0.95, blue: 0.65)
        case .rgbCyberWave: return Color(red: 0.0, green: 0.85, blue: 1.0)
        case .rgbLavaBlaze: return Color(red: 1.0, green: 0.45, blue: 0.0)
        case .classicModern: return Color(red: 0.2, green: 0.6, blue: 1.0)
        case .classic1998: return Color(red: 0.3, green: 0.7, blue: 0.9)
        case .obsidianBento: return Color(red: 0.0, green: 0.8, blue: 1.0)
        case .cyberMatrix: return Color(red: 0.1, green: 0.9, blue: 0.3)
        case .champagneGold: return Color(red: 0.9, green: 0.7, blue: 0.3)
        case .solarFlare: return Color(red: 1.0, green: 0.4, blue: 0.2)
        case .rgbNeon: return Color(red: 0.0, green: 0.9, blue: 1.0)
        case .animeKawaii: return Color(red: 1.0, green: 0.6, blue: 0.75)
        case .auroraGradient: return Color(red: 0.0, green: 0.9, blue: 0.8)
        case .sunsetVaporwave: return Color(red: 1.0, green: 0.45, blue: 0.25)
        case .graphicBauhaus: return Color(red: 0.92, green: 0.22, blue: 0.25)
        case .retroSynthwave: return Color(red: 1.0, green: 0.1, blue: 0.6)
        case .cyberdeckHUD: return Color(red: 0.0, green: 0.9, blue: 1.0)
        case .cosmosNebula: return Color(red: 0.85, green: 0.0, blue: 1.0)
        case .neonSynthwave: return Color(red: 1.0, green: 0.0, blue: 0.5)
        case .obsidianGlass: return Color(red: 0.0, green: 0.9, blue: 0.45)
        case .mechaTactical: return Color(red: 1.0, green: 0.65, blue: 0.0)
        }
    }

    // Button Background
    public var buttonBackground: LinearGradient {
        switch self {
        case .audiophileGold, .cyberpunkMatrix, .stealthCarbon,
             .rgbChromaFlow, .rgbCyberWave, .rgbLavaBlaze,
             .cyberdeckHUD, .cosmosNebula, .neonSynthwave, .obsidianGlass, .mechaTactical:
            return LinearGradient(
                colors: [Color.white.opacity(0.25), Color.white.opacity(0.08)],
                startPoint: .top, endPoint: .bottom
            )
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
        case .rgbNeon:
            return LinearGradient(
                colors: [Color(red: 0.22, green: 0.12, blue: 0.35), Color(red: 0.12, green: 0.06, blue: 0.20)],
                startPoint: .top, endPoint: .bottom
            )
        case .animeKawaii:
            return LinearGradient(
                colors: [Color(red: 0.38, green: 0.28, blue: 0.46), Color(red: 0.24, green: 0.18, blue: 0.30)],
                startPoint: .top, endPoint: .bottom
            )
        case .auroraGradient:
            return LinearGradient(
                colors: [Color(red: 0.08, green: 0.25, blue: 0.32), Color(red: 0.04, green: 0.14, blue: 0.18)],
                startPoint: .top, endPoint: .bottom
            )
        case .sunsetVaporwave:
            return LinearGradient(
                colors: [Color(red: 0.35, green: 0.12, blue: 0.40), Color(red: 0.18, green: 0.05, blue: 0.22)],
                startPoint: .top, endPoint: .bottom
            )
        case .graphicBauhaus:
            return LinearGradient(
                colors: [Color(red: 0.28, green: 0.30, blue: 0.36), Color(red: 0.16, green: 0.17, blue: 0.21)],
                startPoint: .top, endPoint: .bottom
            )
        case .retroSynthwave:
            return LinearGradient(
                colors: [Color(red: 0.28, green: 0.10, blue: 0.42), Color(red: 0.14, green: 0.04, blue: 0.22)],
                startPoint: .top, endPoint: .bottom
            )
        }
    }

    // Border Bevel Colors
    public var borderLight: Color {
        switch self {
        case .audiophileGold: return Color(red: 0.85, green: 0.70, blue: 0.25).opacity(0.8)
        case .cyberpunkMatrix: return Color(red: 0.0, green: 0.9, blue: 1.0).opacity(0.8)
        case .stealthCarbon: return Color(red: 0.9, green: 0.2, blue: 0.25).opacity(0.8)
        case .rgbChromaFlow: return Color(red: 0.0, green: 1.0, blue: 0.6).opacity(0.8)
        case .rgbCyberWave: return Color(red: 0.0, green: 0.9, blue: 1.0).opacity(0.8)
        case .rgbLavaBlaze: return Color(red: 1.0, green: 0.4, blue: 0.0).opacity(0.8)
        case .classicModern: return Color(white: 0.45)
        case .classic1998: return Color(white: 0.50)
        case .obsidianBento: return Color(white: 0.30)
        case .cyberMatrix: return Color(red: 0.1, green: 0.4, blue: 0.2)
        case .champagneGold: return Color(red: 0.6, green: 0.5, blue: 0.35)
        case .solarFlare: return Color(red: 0.6, green: 0.25, blue: 0.2)
        case .rgbNeon: return Color(red: 0.0, green: 0.9, blue: 1.0).opacity(0.55)
        case .animeKawaii: return Color(red: 0.85, green: 0.75, blue: 0.90)
        case .auroraGradient: return Color(red: 0.2, green: 0.7, blue: 0.8)
        case .sunsetVaporwave: return Color(red: 0.9, green: 0.4, blue: 0.6)
        case .graphicBauhaus: return Color(red: 0.6, green: 0.65, blue: 0.75)
        case .retroSynthwave: return Color(red: 0.85, green: 0.2, blue: 0.8)
        case .cyberdeckHUD: return Color(red: 0.0, green: 0.9, blue: 1.0).opacity(0.7)
        case .cosmosNebula: return Color(red: 0.7, green: 0.3, blue: 1.0).opacity(0.7)
        case .neonSynthwave: return Color(red: 1.0, green: 0.2, blue: 0.6).opacity(0.7)
        case .obsidianGlass: return Color(red: 0.5, green: 0.6, blue: 0.7).opacity(0.7)
        case .mechaTactical: return Color(red: 1.0, green: 0.7, blue: 0.2).opacity(0.7)
        }
    }

    public var borderDark: Color {
        return Color(white: 0.05)
    }

    // Spectrum Gradient Colors (Bottom to Top)
    public var spectrumColors: [Color] {
        switch self {
        case .audiophileGold:
            return [Color(red: 0.7, green: 0.5, blue: 0.1), Color(red: 1.0, green: 0.85, blue: 0.25), Color.white]
        case .cyberpunkMatrix:
            return [Color.blue, Color(red: 0.0, green: 0.9, blue: 1.0), Color(red: 1.0, green: 0.0, blue: 0.6), Color.white]
        case .stealthCarbon:
            return [Color(red: 0.6, green: 0.05, blue: 0.1), Color(red: 1.0, green: 0.2, blue: 0.25), Color.white]
        case .rgbChromaFlow:
            return [.red, .orange, .yellow, .green, .cyan, .blue, .purple]
        case .rgbCyberWave:
            return [Color.blue, Color.cyan, Color(red: 1.0, green: 0.0, blue: 0.8), Color.white]
        case .rgbLavaBlaze:
            return [Color.red, Color.orange, Color.yellow, Color.white]
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
        case .rgbNeon:
            return [Color.blue, Color.cyan, Color.purple, Color(red: 1.0, green: 0.1, blue: 0.7)]
        case .animeKawaii:
            return [Color(red: 0.6, green: 0.85, blue: 0.9), Color(red: 0.8, green: 0.7, blue: 0.95), Color(red: 1.0, green: 0.7, blue: 0.8)]
        case .auroraGradient:
            return [Color.blue, Color(red: 0.0, green: 0.8, blue: 0.6), Color(red: 0.3, green: 1.0, blue: 0.7), Color.white]
        case .sunsetVaporwave:
            return [Color.purple, Color(red: 0.9, green: 0.1, blue: 0.5), Color(red: 1.0, green: 0.6, blue: 0.1), Color.yellow]
        case .graphicBauhaus:
            return [Color(red: 0.1, green: 0.3, blue: 0.8), Color(red: 0.9, green: 0.2, blue: 0.2), Color(red: 1.0, green: 0.8, blue: 0.0), Color.white]
        case .retroSynthwave:
            return [Color(red: 0.4, green: 0.0, blue: 0.8), Color(red: 0.9, green: 0.0, blue: 0.6), Color(red: 0.0, green: 0.9, blue: 1.0), Color.white]
        case .cyberdeckHUD:
            return [Color.blue, Color.cyan, Color.white]
        case .cosmosNebula:
            return [Color.purple, Color.cyan, Color.white]
        case .neonSynthwave:
            return [Color.purple, Color(red: 1.0, green: 0.0, blue: 0.5), Color(red: 1.0, green: 0.8, blue: 0.0)]
        case .obsidianGlass:
            return [Color(red: 0.0, green: 0.5, blue: 0.3), Color(red: 0.0, green: 0.9, blue: 0.4), Color.white]
        case .mechaTactical:
            return [Color(red: 0.8, green: 0.3, blue: 0.0), Color(red: 1.0, green: 0.6, blue: 0.0), Color.yellow]
        }
    }
}
