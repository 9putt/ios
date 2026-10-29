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
                "เพลงสตริงฮิต 2026 Official MV",
                "เพลงไทยสตริงเพราะๆ Official MV",
                "T-POP Hot Hits Official MV",
                "Three Man Down Official MV",
                "BOWKYLION Official MV",
                "NONT TANONT Official MV",
                "Billkin Official MV",
                "Jeff Satur Official MV",
                "4EVE Official MV",
                "PROXIE Official MV"
            ]
        case .lukThung:
            return [
                "เพลงลูกทุ่งใหม่ล่าสุด Official MV",
                "เพลงลูกทุ่งฮิตติดชาร์ต Official MV",
                "ลูกทุ่งอินดี้ฮิต 2026 Official MV",
                "ไผ่ พงศธร Official MV",
                "มนต์แคน แก่นคูน Official MV",
                "ต่าย อรทัย Official MV",
                "เบลล์ นิภาดา Official MV",
                "ลำเพลิน วงศกร Official MV",
                "เวียง นฤมล Official MV"
            ]
        case .pueaChiwit:
            return [
                "เพลงเพื่อชีวิตเพราะๆ Official MV",
                "เพลงเพื่อชีวิตฮิตตลอดกาล Official MV",
                "คาราบาว Official MV",
                "ปู พงษ์สิทธิ์ คำภีร์ Official MV",
                "มาลีฮวนน่า Official MV",
                "คนด่านเกวียน Official MV",
                "คาราวาน Official MV",
                "เพลงเพื่อชีวิตซึ้งๆ Official MV"
            ]
        case .inter:
            return [
                "Billboard Hot 100 Official Video",
                "Top Global Hits 2026 Official MV",
                "Pop International Hits Official Video",
                "Taylor Swift Official MV",
                "Bruno Mars Official MV",
                "Ed Sheeran Official MV",
                "Billie Eilish Official MV",
                "The Weeknd Official MV",
                "Dua Lipa Official MV",
                "Post Malone Official MV"
            ]
        case .rock:
            return [
                "เพลงร็อคไทยฮิต Official MV",
                "BODYSLAM Official MV",
                "Potato Official MV",
                "Cocktail Official MV",
                "Paper Planes Official MV",
                "Silly Fools Official MV",
                "Lomosonic Official MV",
                "Sweet Mullet Official MV"
            ]
        case .indie:
            return [
                "เพลงอินดี้ไทย เพราะๆ Official MV",
                "Safeplanet Official MV",
                "Dept Official MV",
                "Anatomy Rabbit Official MV",
                "Tilly Birds Official MV",
                "Television off Official MV",
                "Purpeech Official MV",
                "Blackbeans Official MV"
            ]
        }
    }
}
