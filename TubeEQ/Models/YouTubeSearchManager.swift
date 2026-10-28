import Foundation

public class YouTubeSearchManager {
    public static let shared = YouTubeSearchManager()

    private init() {}

    /// Checks if a YouTube video is a genuine music track (not a 1-hour or 2-hour longplay / compilation)
    public static func isSingleSong(title: String, duration: TimeInterval) -> Bool {
        // Any track longer than 12 minutes (720 seconds) is almost certainly a compilation
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

    /// Performs direct high-speed YouTube search using YouTube InnerTube API (Free, No Premium required)
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
                    "clientName": "WEB",
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

            if let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let contents = (root["contents"] as? [String: Any])?["twoColumnSearchResultsRenderer"] as? [String: Any],
               let primary = (contents["primaryContents"] as? [String: Any])?["sectionListRenderer"] as? [String: Any],
               let sections = primary["contents"] as? [[String: Any]] {

                for section in sections {
                    if let itemSection = (section["itemSectionRenderer"] as? [String: Any])?["contents"] as? [[String: Any]] {
                        for item in itemSection {
                            if let vr = item["videoRenderer"] as? [String: Any],
                               let vid = vr["videoId"] as? String, !vid.isEmpty {

                                var title = "YouTube Video"
                                if let titleDict = vr["title"] as? [String: Any],
                                   let runs = titleDict["runs"] as? [[String: Any]],
                                   let first = runs.first,
                                   let text = first["text"] as? String {
                                    title = text
                                }

                                var artist = "YouTube"
                                if let ownerDict = vr["ownerText"] as? [String: Any],
                                   let runs = ownerDict["runs"] as? [[String: Any]],
                                   let first = runs.first,
                                   let text = first["text"] as? String {
                                    artist = text
                                }

                                var durationSec: TimeInterval = 210
                                if let lenDict = vr["lengthText"] as? [String: Any] {
                                    if let simple = lenDict["simpleText"] as? String {
                                        durationSec = self.parseDuration(simple)
                                    } else if let runs = lenDict["runs"] as? [[String: Any]],
                                              let first = runs.first,
                                              let text = first["text"] as? String {
                                        durationSec = self.parseDuration(text)
                                    }
                                }

                                // Apply single-song filter if requested
                                if filterCompilations {
                                    if !YouTubeSearchManager.isSingleSong(title: title, duration: durationSec) {
                                        continue
                                    }
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
                        }
                    }
                }
            }

            DispatchQueue.main.async {
                completion(tracks)
            }
        }.resume()
    }

    /// Fetches trending Thai and International music hits to populate the playlist with real tracks on launch
    public func fetchInitialTrendingHits(completion: @escaping ([TrackItem]) -> Void) {
        search(query: "เพลงใหม่ Official MV", filterCompilations: true) { results in
            if !results.isEmpty {
                completion(results)
            } else {
                self.search(query: "Three Man Down Official MV", filterCompilations: true) { fallback in
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
