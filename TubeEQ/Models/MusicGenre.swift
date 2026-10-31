import Foundation

public enum MusicGenre: String, CaseIterable, Identifiable, Codable {
    case string = "สตริง"
    case lukThung = "ลูกทุ่ง"
    case pueaChiwit = "เพื่อชีวิต"
    case inter = "สากล"
    case rock = "ร็อค"
    case indie = "อินดี้"

    public var id: String { rawValue }

    public var englishTitle: String {
        switch self {
        case .string: return "Thai Pop / String"
        case .lukThung: return "Luk Thung Country"
        case .pueaChiwit: return "Songs For Life"
        case .inter: return "Billboard Global"
        case .rock: return "Thai & Global Rock"
        case .indie: return "Indie Alternative"
        }
    }

    public var icon: String {
        switch self {
        case .string: return "music.note"
        case .lukThung: return "guitars.fill"
        case .pueaChiwit: return "flame.fill"
        case .inter: return "globe.americas.fill"
        case .rock: return "bolt.fill"
        case .indie: return "headphones"
        }
    }

    public var searchQueries: [String] {
        switch self {
        case .string:
            return [
                "รวมเพลงสตริงฮิต 2026 ใหม่ล่าสุด Official MV",
                "T-POP Hot Hits รวมศิลปิน Official MV",
                "เพลงไทยสตริงฮิตติดชาร์ต รวมเพลงเพราะ Official MV",
                "เพลงป๊อปไทยยอดนิยม 2026 Official MV",
                "Billboard Thailand Top Thai Hits",
                "เพลงฮิตค่าย GeneLab WhatTheDuck GMM Official MV"
            ]
        case .lukThung:
            return [
                "รวมเพลงลูกทุ่งฮิต 2026 ใหม่ล่าสุด Official MV",
                "เพลงลูกทุ่งฮิตติดชาร์ต แกรมมี่โกลด์ รวมศิลปิน",
                "รวมเพลงลูกทุ่งอินดี้มาแรง 100 ล้านวิว",
                "ลูกทุ่งท็อปฮิตติดชาร์ต ท็อปไลน์ ไทดอล รวมศิลปิน",
                "รวมเพลงลูกทุ่งอีสานเพราะๆ รวมศิลปินดัง",
                "เพลงลูกทุ่งใหม่ล่าสุด 2026 เพราะๆ ซึ้งๆ"
            ]
        case .pueaChiwit:
            return [
                "รวมเพลงเพื่อชีวิตฮิตตลอดกาล รวมศิลปิน",
                "เพลงเพื่อชีวิตระดับตำนาน คาราบาว พงษ์สิทธิ์ มาลีฮวนน่า",
                "รวมเพลงเพื่อชีวิตยอดนิยมเพราะๆ ซึ้งๆ",
                "เพลงเพื่อชีวิตยุคใหม่ฮิตติดหู Official MV"
            ]
        case .inter:
            return [
                "Billboard Hot 100 Top Hits 2026 Official Video",
                "Today's Top Hits Global Official MV",
                "Pop International Hits 2026 Video",
                "Top Streaming Global Songs Official Video"
            ]
        case .rock:
            return [
                "รวมเพลงร็อคไทยฮิตติดชาร์ต Bodyslam Potato Cocktail",
                "เพลงร็อคไทยยอดนิยมตลอดกาล Official MV",
                "Thai Modern Rock Hits Official MV",
                "รวมเพลงร็อคโดนใจ ยุค 90 ถึงปัจจุบัน"
            ]
        case .indie:
            return [
                "รวมเพลงอินดี้ไทยฮิตติดหู 2026 Official MV",
                "Indie Pop Hits Thailand รวมศิลปิน",
                "เพลงนอกกระแสเพราะๆ ฟังสบาย Official MV",
                "รวมเพลงอินดี้มาแรง Safeplanet Dept Tilly Birds"
            ]
        }
    }
}
