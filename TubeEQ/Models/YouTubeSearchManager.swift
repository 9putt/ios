import Foundation

public class YouTubeSearchManager {
    public static let shared = YouTubeSearchManager()

    private init() {}

    /// Checks if a YouTube video is a genuine music track (not a 1-hour compilation)
    public static func isSingleSong(title: String, duration: TimeInterval) -> Bool {
        if duration > 720 && duration > 0 {
            return false
        }

        let lower = title.lowercased()
        let bannedKeywords = [
            "รวมเพลง", "เพลงรวม", "รวมฮิต", "ฟังยาวๆ",
            "เพลงต่อเนื่อง", "เมดเล่ย์", "non-stop", "nonstop", "non stop",
            "1 ชั่วโมง", "2 ชั่วโมง", "3 ชั่วโมง", "1 hr", "2 hr", "longplay"
        ]
        for kw in bannedKeywords {
            if lower.contains(kw) {
                return false
            }
        }
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
                // Support videoWithContextRenderer (MWEB standard), compactVideoRenderer, and videoRenderer
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

                if filterCompilations && !YouTubeSearchManager.isSingleSong(title: title, duration: durationSec) {
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
