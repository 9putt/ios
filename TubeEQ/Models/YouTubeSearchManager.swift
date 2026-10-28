import Foundation

public class YouTubeSearchManager {
    public static let shared = YouTubeSearchManager()

    private init() {}

    /// Performs high-speed YouTube search and returns parsed TrackItems
    public func search(query: String, completion: @escaping ([TrackItem]) -> Void) {
        guard let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://www.youtube.com/results?search_query=\(encoded)") else {
            completion([])
            return
        }

        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 10.0

        URLSession.shared.dataTask(with: request) { data, response, error in
            guard let data = data, let html = String(data: data, encoding: .utf8), error == nil else {
                DispatchQueue.main.async { completion([]) }
                return
            }

            let tracks = self.parseSearchHTML(html)
            DispatchQueue.main.async {
                completion(tracks)
            }
        }.resume()
    }

    private func parseSearchHTML(_ html: String) -> [TrackItem] {
        var results: [TrackItem] = []

        // Extract ytInitialData JSON from script tag
        guard let startRange = html.range(of: "var ytInitialData = "),
              let endRange = html[startRange.upperBound...].range(of: "};") else {
            return fallbackRegexParse(html)
        }

        let jsonString = String(html[startRange.upperBound...endRange.lowerBound]) + "}"
        guard let jsonData = jsonString.data(using: .utf8) else {
            return fallbackRegexParse(html)
        }

        do {
            if let root = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any] {
                if let contents = (root["contents"] as? [String: Any])?["twoColumnSearchResultsRenderer"] as? [String: Any],
                   let primary = (contents["primaryContents"] as? [String: Any])?["sectionListRenderer"] as? [String: Any],
                   let sections = primary["contents"] as? [[String: Any]] {
                    
                    for section in sections {
                        if let itemSection = (section["itemSectionRenderer"] as? [String: Any])?["contents"] as? [[String: Any]] {
                            for item in itemSection {
                                if let vr = item["videoRenderer"] as? [String: Any] {
                                    if let track = self.extractVideoRenderer(vr) {
                                        results.append(track)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        } catch {
            return fallbackRegexParse(html)
        }

        return results.isEmpty ? fallbackRegexParse(html) : results
    }

    private func extractVideoRenderer(_ vr: [String: Any]) -> TrackItem? {
        guard let videoId = vr["videoId"] as? String, !videoId.isEmpty else { return nil }

        var title = "YouTube Track"
        if let titleObj = vr["title"] as? [String: Any],
           let runs = titleObj["runs"] as? [[String: Any]],
           let firstRun = runs.first,
           let text = firstRun["text"] as? String {
            title = text
        }

        var artist = "YouTube Music"
        if let owner = vr["ownerText"] as? [String: Any],
           let runs = owner["runs"] as? [[String: Any]],
           let firstRun = runs.first,
           let text = firstRun["text"] as? String {
            artist = text
        }

        var duration: TimeInterval = 210
        if let length = vr["lengthText"] as? [String: Any],
           let simpleText = length["simpleText"] as? String {
            duration = parseDuration(simpleText)
        }

        return TrackItem(
            title: title,
            artist: artist,
            duration: duration,
            urlString: "https://www.youtube.com/watch?v=\(videoId)",
            isLocal: false,
            videoId: videoId
        )
    }

    private func fallbackRegexParse(_ html: String) -> [TrackItem] {
        var items: [TrackItem] = []
        // Regex for /watch?v=VIDEO_ID
        let pattern = #"/watch\?v=([a-zA-Z0-9_-]{11})"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }

        let nsString = html as NSString
        let matches = regex.matches(in: html, range: NSRange(location: 0, length: nsString.length))
        var seenIDs = Set<String>()

        for match in matches {
            if match.numberOfRanges > 1 {
                let vid = nsString.substring(with: match.range(at: 1))
                if !seenIDs.contains(vid) {
                    seenIDs.insert(vid)
                    items.append(TrackItem(
                        title: "YouTube Video (\(vid))",
                        artist: "YouTube Stream",
                        duration: 210,
                        urlString: "https://www.youtube.com/watch?v=\(vid)",
                        isLocal: false,
                        videoId: vid
                    ))
                    if items.count >= 20 { break }
                }
            }
        }
        return items
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
