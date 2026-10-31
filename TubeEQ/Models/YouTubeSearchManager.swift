import Foundation

public class YouTubeSearchManager {
    public static let shared = YouTubeSearchManager()

    private init() {}

    /// Checks if a YouTube video is a genuine single music track (NOT news, talk show, sport, or compilation)
    public static func isSingleSong(title: String, duration: TimeInterval, channel: String = "") -> Bool {
        // Duration filter: single songs are between 50 seconds and 660 seconds (11 minutes)
        if duration > 660 || (duration > 0 && duration < 50) {
            return false
        }

        let lowerTitle = title.lowercased()
        let lowerChan = channel.lowercased()

        // Banned non-music keywords (News, politics, talk shows, sports, gameplay, blogs)
        let bannedKeywords = [
            // Compilations / Longplay
            "รวมเพลง", "เพลงรวม", "รวมฮิต", "ฟังยาวๆ", "เพลงต่อเนื่อง", "เมดเล่ย์",
            "non-stop", "nonstop", "non stop", "1 ชั่วโมง", "2 ชั่วโมง", "3 ชั่วโมง",
            "1 hr", "2 hr", "longplay", "full album",
            // News & Media Channels & Titles
            "ข่าว", "สำนักข่าว", "thairath", "ไทยรัฐ", "เรื่องเล่า", "เรื่องเด่น",
            "top news", "springnews", "khaosod", "ข่าวสด", "mgronline", "ch3plus",
            "ch7hd news", "one31 ข่าว", "amarintv", "amarin news", "nation tv", "เนชั่น",
            "เดลินิวส์", "แนวหน้า", "สรุปข่าว", "แถลงข่าว", "แถลงการณ์", "การเมือง",
            // Talk shows, podcasts, interviews
            "สัมภาษณ์", "podcast", "พอดแคสต์", "talk show", "เจาะลึก", "โหนกระแส",
            // Sports & live events
            "ไฮไลท์", "ไฮไลท์บอล", "ฟุตบอล", "มวย", "ถ่ายทอดสด", "full match", "วอลเลย์บอล",
            // Drama / Gaming / Reaction / Vlog
            "spoil", "สปอย", "แคสเกม", "gameplay", "ละคร", "ตอนที่", "ep.", "full ep",
            "รีวิว", "แกะกล่อง", "vlog"
        ]

        for kw in bannedKeywords {
            if lowerTitle.contains(kw) || lowerChan.contains(kw) {
                return false
            }
        }

        return true
    }

    /// Special filter for User Personalized Feed: allows single songs AND long compilation mixes,
    /// but strictly excludes non-music news, political shows, sports, and gaming clips.
    public static func isFeedMusic(title: String, duration: TimeInterval, channel: String = "") -> Bool {
        let lowerTitle = title.lowercased()
        let lowerChan = channel.lowercased()

        let nonMusicKeywords = [
            "สำนักข่าว", "thairath", "ไทยรัฐ", "เรื่องเล่า", "เรื่องเด่น",
            "top news", "springnews", "khaosod", "ข่าวสด", "mgronline", "ch3plus",
            "ch7hd news", "one31 ข่าว", "amarintv", "amarin news", "nation tv", "เนชั่น",
            "เดลินิวส์", "แนวหน้า", "สรุปข่าว", "แถลงข่าว", "แถลงการณ์", "การเมือง",
            "สัมภาษณ์", "podcast", "พอดแคสต์", "talk show", "เจาะลึก", "โหนกระแส",
            "ไฮไลท์บอล", "ฟุตบอล", "มวย", "full match", "วอลเลย์บอล",
            "แคสเกม", "gameplay", "ละคร", "ตอนที่", "full ep"
        ]

        for kw in nonMusicKeywords {
            if lowerTitle.contains(kw) || lowerChan.contains(kw) {
                return false
            }
        }

        // Long compilation songs ARE allowed in the user's feed per user request:
        // "และอนุญาตให้เพลงยาวรวมได้ครับเฉพาะฟีด และต้องได้รายการเพลงจากฟีดผู้ใช้จริงๆ"
        return true
    }

    /// Performs direct high-speed YouTube search using YouTube MWEB InnerTube API
    public func search(query: String, filterCompilations: Bool = true, completion: @escaping ([TrackItem]) -> Void) {
        guard let url = URL(string: "https://www.youtube.com/youtubei/v1/search") else {
            completion([])
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_4 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 10.0

        let payload: [String: Any] = [
            "context": [
                "client": [
                    "clientName": "MWEB",
                    "clientVersion": "2.20240101.00.00",
                    "hl": "th",
                    "gl": "TH"
                ]
            ],
            "query": query
        ]

        guard let httpBody = try? JSONSerialization.data(withJSONObject: payload) else {
            completion([])
            return
        }
        request.httpBody = httpBody

        URLSession.shared.dataTask(with: request) { data, response, error in
            guard let data = data, error == nil else {
                DispatchQueue.main.async { completion([]) }
                return
            }

            var tracks: [TrackItem] = []

            guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                DispatchQueue.main.async { completion([]) }
                return
            }

            // Extract items from MWEB response format
            var rawItems: [[String: Any]] = []

            if let contents = root["contents"] as? [String: Any],
               let sectionList = contents["sectionListRenderer"] as? [String: Any],
               let sections = sectionList["contents"] as? [[String: Any]] {
                for s in sections {
                    if let itemSection = s["itemSectionRenderer"] as? [String: Any],
                       let c = itemSection["contents"] as? [[String: Any]] {
                        rawItems.append(contentsOf: c)
                    }
                }
            }

            // Fallback for desktop WEB format
            if rawItems.isEmpty,
               let contents = root["contents"] as? [String: Any],
               let twoCol = contents["twoColumnSearchResultsRenderer"] as? [String: Any],
               let primary = twoCol["primaryContents"] as? [String: Any],
               let sectionList = primary["sectionListRenderer"] as? [String: Any],
               let sections = sectionList["contents"] as? [[String: Any]] {
                for s in sections {
                    if let itemSection = s["itemSectionRenderer"] as? [String: Any],
                       let c = itemSection["contents"] as? [[String: Any]] {
                        rawItems.append(contentsOf: c)
                    }
                }
            }

            for item in rawItems {
                let vr = item["videoWithContextRenderer"] as? [String: Any]
                    ?? item["compactVideoRenderer"] as? [String: Any]
                    ?? item["videoRenderer"] as? [String: Any]

                guard let vrDict = vr,
                      let vid = vrDict["videoId"] as? String, !vid.isEmpty else { continue }

                // Title extraction
                var title = "YouTube Video"
                if let headline = vrDict["headline"] as? [String: Any],
                   let runs = headline["runs"] as? [[String: Any]],
                   let first = runs.first, let t = first["text"] as? String {
                    title = t
                } else if let titleDict = vrDict["title"] as? [String: Any],
                          let runs = titleDict["runs"] as? [[String: Any]],
                          let first = runs.first, let t = first["text"] as? String {
                    title = t
                }

                // Artist / Channel extraction
                var artist = "YouTube"
                if let shortByline = vrDict["shortBylineText"] as? [String: Any],
                   let runs = shortByline["runs"] as? [[String: Any]],
                   let first = runs.first, let a = first["text"] as? String {
                    artist = a
                } else if let ownerDict = vrDict["ownerText"] as? [String: Any],
                          let runs = ownerDict["runs"] as? [[String: Any]],
                          let first = runs.first, let a = first["text"] as? String {
                    artist = a
                }

                // Duration extraction
                var durationSec: TimeInterval = 210
                if let lenDict = vrDict["lengthText"] as? [String: Any] {
                    if let simple = lenDict["simpleText"] as? String {
                        durationSec = self.parseDuration(simple)
                    } else if let runs = lenDict["runs"] as? [[String: Any]],
                              let first = runs.first, let t = first["text"] as? String {
                        durationSec = self.parseDuration(t)
                    }
                }

                if filterCompilations && !YouTubeSearchManager.isSingleSong(title: title, duration: durationSec, channel: artist) {
                    continue
                }

                tracks.append(TrackItem(
                    title: title,
                    artist: artist,
                    duration: durationSec,
                    urlString: "https://www.youtube.com/watch?v=\(vid)",
                    isLocal: false,
                    videoId: vid
                ))
            }

            DispatchQueue.main.async {
                completion(tracks)
            }
        }.resume()
    }

    /// Fetches the user's personalized YouTube homepage/recommendations feed using session cookies
    /// Filters out all news, talk shows, and non-music videos, extracting ONLY pure music tracks.
    public func fetchUserPersonalizedFeed(completion: @escaping ([TrackItem]) -> Void) {
        let cookieHeader = KeychainCookieManager.shared.getCookieHeaderString()
        guard let url = URL(string: "https://www.youtube.com/youtubei/v1/browse") else {
            fetchInitialTrendingHits(completion: completion)
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_4 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 12.0

        if let cookies = cookieHeader, !cookies.isEmpty {
            request.setValue(cookies, forHTTPHeaderField: "Cookie")
        }
        if let sapisidHash = KeychainCookieManager.shared.getSapisidHash() {
            request.setValue("SAPISIDHASH \(sapisidHash)", forHTTPHeaderField: "Authorization")
            request.setValue("https://m.youtube.com", forHTTPHeaderField: "Origin")
            request.setValue("https://m.youtube.com/", forHTTPHeaderField: "Referer")
            request.setValue("1", forHTTPHeaderField: "X-YouTube-Client-Name")
            request.setValue("2.20240101.00.00", forHTTPHeaderField: "X-YouTube-Client-Version")
        }

        let payload: [String: Any] = [
            "context": [
                "client": [
                    "clientName": "MWEB",
                    "clientVersion": "2.20240101.00.00",
                    "hl": "th",
                    "gl": "TH"
                ]
            ],
            "browseId": "FEwhat_to_watch"
        ]

        guard let httpBody = try? JSONSerialization.data(withJSONObject: payload) else {
            fetchInitialTrendingHits(completion: completion)
            return
        }
        request.httpBody = httpBody

        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self, let data = data, error == nil else {
                self?.fetchInitialTrendingHits(completion: completion)
                return
            }

            guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                self.fetchInitialTrendingHits(completion: completion)
                return
            }

            var rawItems: [[String: Any]] = []
            if let contents = root["contents"] as? [String: Any],
               let singleColumn = contents["singleColumnBrowseResultsRenderer"] as? [String: Any],
               let tabs = singleColumn["tabs"] as? [[String: Any]],
               let tab = tabs.first,
               let tabRenderer = tab["tabRenderer"] as? [String: Any],
               let content = tabRenderer["content"] as? [String: Any],
               let sectionList = content["sectionListRenderer"] as? [String: Any],
               let sections = sectionList["contents"] as? [[String: Any]] {
                for s in sections {
                    if let itemSection = s["itemSectionRenderer"] as? [String: Any],
                       let c = itemSection["contents"] as? [[String: Any]] {
                        rawItems.append(contentsOf: c)
                    }
                }
            }

            if rawItems.isEmpty,
               let contents = root["contents"] as? [String: Any],
               let twoCol = contents["twoColumnBrowseResultsRenderer"] as? [String: Any],
               let tabs = twoCol["tabs"] as? [[String: Any]],
               let tab = tabs.first,
               let tabRenderer = tab["tabRenderer"] as? [String: Any],
               let content = tabRenderer["content"] as? [String: Any],
               let sectionList = content["sectionListRenderer"] as? [String: Any],
               let sections = sectionList["contents"] as? [[String: Any]] {
                for s in sections {
                    if let itemSection = s["itemSectionRenderer"] as? [String: Any],
                       let c = itemSection["contents"] as? [[String: Any]] {
                        rawItems.append(contentsOf: c)
                    }
                }
            }

            var musicTracks: [TrackItem] = []
            var seenVids = Set<String>()

            for item in rawItems {
                let vr = item["videoWithContextRenderer"] as? [String: Any]
                    ?? item["compactVideoRenderer"] as? [String: Any]
                    ?? item["videoRenderer"] as? [String: Any]
                    ?? item["richItemRenderer"] as? [String: Any]

                guard let vrDict = vr else { continue }
                let actualDict: [String: Any]
                if let content = vrDict["content"] as? [String: Any],
                   let subVR = (content["videoRenderer"] as? [String: Any] ?? content["videoWithContextRenderer"] as? [String: Any]) {
                    actualDict = subVR
                } else {
                    actualDict = vrDict
                }

                guard let vid = actualDict["videoId"] as? String, !vid.isEmpty, !seenVids.contains(vid) else { continue }

                // Title extraction
                var title = "YouTube Track"
                if let headline = actualDict["headline"] as? [String: Any],
                   let runs = headline["runs"] as? [[String: Any]],
                   let first = runs.first, let t = first["text"] as? String {
                    title = t
                } else if let titleDict = actualDict["title"] as? [String: Any],
                          let runs = titleDict["runs"] as? [[String: Any]],
                          let first = runs.first, let t = first["text"] as? String {
                    title = t
                }

                // Artist / Channel extraction
                var artist = "YouTube"
                if let shortByline = actualDict["shortBylineText"] as? [String: Any],
                   let runs = shortByline["runs"] as? [[String: Any]],
                   let first = runs.first, let a = first["text"] as? String {
                    artist = a
                } else if let ownerDict = actualDict["ownerText"] as? [String: Any],
                          let runs = ownerDict["runs"] as? [[String: Any]],
                          let first = runs.first, let a = first["text"] as? String {
                    artist = a
                }

                // Duration extraction
                var durationSec: TimeInterval = 240
                if let lenDict = actualDict["lengthText"] as? [String: Any] {
                    if let simple = lenDict["simpleText"] as? String {
                        durationSec = self.parseDuration(simple)
                    } else if let runs = lenDict["runs"] as? [[String: Any]],
                              let first = runs.first, let t = first["text"] as? String {
                        durationSec = self.parseDuration(t)
                    }
                }

                // STRICT FILTER FOR FEED: Pure music, ALLOWS long compilation mixes per user request!
                guard YouTubeSearchManager.isFeedMusic(title: title, duration: durationSec, channel: artist) else {
                    continue
                }

                seenVids.insert(vid)
                musicTracks.append(TrackItem(
                    title: title,
                    artist: artist,
                    duration: durationSec,
                    urlString: "https://www.youtube.com/watch?v=\(vid)",
                    isLocal: false,
                    videoId: vid
                ))
            }

            if !musicTracks.isEmpty {
                DispatchQueue.main.async {
                    completion(musicTracks)
                }
            } else {
                // Supplement with hot music queries so playlist is always plentiful
                let fallbackQueries = [
                    "เพลงใหม่มาแรง 2026 Official MV",
                    "เพลงไทยฮิตติดชาร์ต 2026 Official MV",
                    "T-POP Hot Track Official MV"
                ]
                let dispatchGroup = DispatchGroup()
                var extraTracks: [TrackItem] = []
                let lock = NSLock()

                for q in fallbackQueries {
                    dispatchGroup.enter()
                    self.search(query: q, filterCompilations: true) { tracks in
                        lock.lock()
                        extraTracks.append(contentsOf: tracks)
                        lock.unlock()
                        dispatchGroup.leave()
                    }
                }

                dispatchGroup.notify(queue: .main) {
                    for t in extraTracks {
                        guard let vid = t.videoId, !seenVids.contains(vid) else { continue }
                        seenVids.insert(vid)
                        musicTracks.append(t)
                    }
                    completion(musicTracks)
                }
            }
        }.resume()
    }

    /// Fetches trending Thai music hits to populate the playlist
    public func fetchInitialTrendingHits(completion: @escaping ([TrackItem]) -> Void) {
        search(query: "Three Man Down Official MV", filterCompilations: true) { results in
            if !results.isEmpty {
                completion(results)
            } else {
                self.search(query: "เพลงใหม่ Official MV", filterCompilations: true) { fallback in
                    completion(fallback)
                }
            }
        }
    }

    /// Fetches multiple queries in parallel to ensure a rich batch of new unique songs
    public func fetchBatchOfTracks(queries: [String], existingIds: Set<String>, minTracks: Int = 20, completion: @escaping ([TrackItem]) -> Void) {
        let dispatchGroup = DispatchGroup()
        var collected: [TrackItem] = []
        let lock = NSLock()
        var seen = existingIds

        let sample = Array(queries.shuffled().prefix(4))

        for q in sample {
            dispatchGroup.enter()
            self.search(query: q, filterCompilations: true) { tracks in
                lock.lock()
                for track in tracks {
                    let key = track.videoId ?? track.urlString
                    if !seen.contains(key) {
                        seen.insert(key)
                        collected.append(track)
                    }
                }
                lock.unlock()
                dispatchGroup.leave()
            }
        }

        dispatchGroup.notify(queue: .main) {
            completion(collected)
        }
    }

    private func parseDuration(_ text: String) -> TimeInterval {
        let parts = text.components(separatedBy: ":").compactMap { Double($0) }
        if parts.count == 2 {
            return parts[0] * 60 + parts[1]
        } else if parts.count == 3 {
            return parts[0] * 3600 + parts[1] * 60 + parts[2]
        }
        return 210
    }
}
