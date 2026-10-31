import Foundation

public enum MusicGenre: String, CaseIterable, Identifiable, Codable {
    case userFeed = "ฟีดเพลง"
    case string = "สตริง"
    case lukThung = "ลูกทุ่ง"
    case pueaChiwit = "เพื่อชีวิต"
    case inter = "สากล"
    case rock = "ร็อค"
    case indie = "อินดี้"

    public var id: String { rawValue }

    public var englishTitle: String {
        switch self {
        case .userFeed: return "My Music Feed (Personalized)"
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
        case .userFeed: return "sparkles.tv"
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
        case .userFeed:
            return [
                "เพลงใหม่มาแรง 2026 Official MV",
                "T-POP Hot Track 2026 Official MV",
                "เพลงไทยเพราะๆ ซึ้งๆ Official MV",
                "เพลงฮิตติดชาร์ตมาแรง 2026 Official MV",
                "Global Top Music Hits 2026 Official Video"
            ]
        case .string:
            return [
                "เพลงไทยสตริงใหม่ล่าสุด 2026 Official MV",
                "T-POP Hot Hits Official MV",
                "เพลงป๊อปไทยยอดนิยม 2026 Official MV",
                "GeneLab Official MV",
                "What The Duck Official MV",
                "GMM Grammy Official MV",
                "เพลงรักเพราะๆ ซึ้งๆ Official MV"
            ]
        case .lukThung:
            return [
                "มนต์แคน แก่นคูน Official MV",
                "ก้อง ห้วยไร่ Official MV",
                "ต่าย อรทัย Official MV",
                "เบิ้ล ปทุมราช Official MV",
                "ไผ่ พงศธร Official MV",
                "ลำเพลิน วงศกร Official MV",
                "เต๋า ภูศิลป์ Official MV",
                "แกรมมี่โกลด์ เพลงใหม่ Official MV",
                "ไทดอลมิวสิค Official MV",
                "เพลงลูกทุ่งใหม่ล่าสุด Official MV",
                "เพลงลูกทุ่งอินดี้มาแรง Official MV",
                "เพลงลูกทุ่งฮิตติดชาร์ต Official MV"
            ]
        case .pueaChiwit:
            return [
                "คาราบาว Official MV",
                "พงษ์สิทธิ์ คำภีร์ Official MV",
                "มาลีฮวนน่า Official Audio",
                "ปู พงษ์สิทธิ์ Official MV",
                "พงษ์เทพ กระโดนชำนาญ Official MV",
                "คนด่านเกวียน Official Audio",
                "เพลงเพื่อชีวิตฮิต Official MV",
                "คาราวาน Official MV",
                "วงแทมมะริน Official MV",
                "วงกะลา เพื่อชีวิต Official MV",
                "เพลงเพื่อชีวิตใหม่ล่าสุด Official MV"
            ]
        case .inter:
            return [
                "Billboard Hot 100 2026 Official MV",
                "Top Global Hits 2026 Official Video",
                "New Pop Songs 2026 Official Video",
                "Taylor Swift Bruno Mars Official MV",
                "Viral Hits 2026 Official Music Video",
                "The Weeknd Official Music Video"
            ]
        case .rock:
            return [
                "Bodyslam Official MV",
                "Potato Official MV",
                "Cocktail Official MV",
                "Lomosonic Official MV",
                "Silly Fools Official MV",
                "เพลงร็อคไทยฮิต Official MV",
                "Retrospect Sweet Mullet Official MV",
                "Big Ass Official MV"
            ]
        case .indie:
            return [
                "Safeplanet Official MV",
                "Dept Official MV",
                "Tilly Birds Official MV",
                "Anatomy Rabbit Official MV",
                "Three Man Down Official MV",
                "Television off Official MV",
                "เพลงอินดี้ไทย Official MV",
                "Mirrr Official MV"
            ]
        }
    }
}
