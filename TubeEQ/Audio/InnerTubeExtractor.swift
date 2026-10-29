import Foundation

/// High-speed YouTube audio stream extractor & downloader
/// Uses the VisionOS (Client 101) InnerTube protocol — the exact same engine used by yt-dlp & Tube EQ
/// Bypasses bot verification, requires zero JS deciphering, and extracts direct unthrottled 128kbps AAC streams.
public class InnerTubeExtractor {
    public static let shared = InnerTubeExtractor()
    private var urlCache: [String: URL] = [:]
    private var inFlightTasks: [String: Task<URL?, Never>] = [:]

    // Cached visitorData and signature timestamp
    private static var cachedVisitorData: String? = nil
    private static var cachedSTS: Int = 20752
    private static var isWarmingUpVisitorData = false

    private init() {
        Task(priority: .background) {
            _ = await self.getOrFetchVisitorData()
        }
    }

    // MARK: - Warm up / Fetch Visitor Data
    private func getOrFetchVisitorData() async -> String? {
        if let vd = Self.cachedVisitorData, !vd.isEmpty {
            return vd
        }
        do {
            guard let url = URL(string: "https://www.youtube.com") else { return nil }
            var req = URLRequest(url: url)
            req.setValue("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36", forHTTPHeaderField: "User-Agent")
            req.setValue("en-US,en;q=0.9", forHTTPHeaderField: "Accept-Language")
            req.timeoutInterval = 4.0
            let (data, _) = try await URLSession.shared.data(for: req)
            if let html = String(data: data, encoding: .utf8),
               let range = html.range(of: #""VISITOR_DATA"\s*:\s*"([^"]+)""#, options: .regularExpression) {
                let sub = String(html[range])
                let comps = sub.components(separatedBy: "\"")
                if let found = comps.first(where: { $0.count > 20 && !$0.contains("VISITOR_DATA") }) {
                    Self.cachedVisitorData = found
                    print("[Extractor] Cached new visitorData: \(found.prefix(20))...")
                    return found
                }
            }
        } catch {
            print("[Extractor] Failed to fetch visitorData: \(error)")
        }
        return nil
    }

    // MARK: - Extract Direct Audio Stream URL (VisionOS Client 101)
    public func extractAudioURL(videoId: String) async -> URL? {
        if let cached = urlCache[videoId] { return cached }

        if let existing = inFlightTasks[videoId] {
            return await existing.value
        }

        let task = Task<URL?, Never> {
            do {
                let visitorData = await getOrFetchVisitorData()
                let apiKey = "AIzaSyAO_FJ2SlqU8Q4STEHLGCilw_Y9_11qcW8"
                let sts = Self.cachedSTS

                // Query InnerTube Player API using VisionOS Client (Direct URLs, takes ~0.3s)
                guard let playerURL = URL(string: "https://www.youtube.com/youtubei/v1/player?key=\(apiKey)&prettyPrint=false") else { return nil }
                var playerReq = URLRequest(url: playerURL)
                playerReq.httpMethod = "POST"
                playerReq.setValue("application/json", forHTTPHeaderField: "Content-Type")
                playerReq.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 15_7_3) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/26.0 Safari/605.1.15", forHTTPHeaderField: "User-Agent")
                playerReq.setValue("101", forHTTPHeaderField: "X-YouTube-Client-Name")
                playerReq.setValue("1.02", forHTTPHeaderField: "X-YouTube-Client-Version")
                playerReq.setValue("https://www.youtube.com", forHTTPHeaderField: "Origin")
                if let vd = visitorData {
                    playerReq.setValue(vd, forHTTPHeaderField: "X-Goog-Visitor-Id")
                }
                playerReq.timeoutInterval = 6.0

                var clientDict: [String: Any] = [
                    "clientName": "VISIONOS",
                    "clientVersion": "1.02",
                    "deviceMake": "Apple",
                    "deviceModel": "RealityDevice17,1",
                    "userAgent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 15_7_3) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/26.0 Safari/605.1.15",
                    "osName": "visionOS",
                    "osVersion": "26.5.23O471",
                    "hl": "th",
                    "gl": "TH"
                ]
                if let vd = visitorData {
                    clientDict["visitorData"] = vd
                }

                let bodyDict: [String: Any] = [
                    "context": ["client": clientDict],
                    "videoId": videoId,
                    "playbackContext": [
                        "contentPlaybackContext": [
                            "html5Preference": "HTML5_PREF_WANTS",
                            "signatureTimestamp": sts
                        ]
                    ],
                    "contentCheckOk": true,
                    "racyCheckOk": true
                ]

                playerReq.httpBody = try JSONSerialization.data(withJSONObject: bodyDict)

                let (playerData, _) = try await URLSession.shared.data(for: playerReq)
                guard let json = try JSONSerialization.jsonObject(with: playerData) as? [String: Any] else { return nil }

                let streaming = json["streamingData"] as? [String: Any]
                let adaptive = streaming?["adaptiveFormats"] as? [[String: Any]] ?? []

                // Priority 1: itag 140 (128kbps AAC M4A)
                for f in adaptive {
                    if let itag = f["itag"] as? Int, itag == 140,
                       let urlStr = f["url"] as? String,
                       let streamURL = URL(string: urlStr) {
                        print("[Extractor] ✅ VisionOS resolved direct 128k AAC audio for \(videoId)")
                        return streamURL
                    }
                }

                // Priority 2: Compatible Apple Audio formats (AAC / MP4 only, NEVER WebM Opus)
                for f in adaptive {
                    let mime = f["mimeType"] as? String ?? ""
                    if (mime.contains("audio/mp4") || mime.contains("mp4a") || mime.contains("audio/aac")),
                       let urlStr = f["url"] as? String,
                       let streamURL = URL(string: urlStr) {
                        print("[Extractor] ✅ VisionOS resolved compatible AAC format (\(mime)) for \(videoId)")
                        return streamURL
                    }
                }

                // Priority 3: HLS Manifest URL (AVPlayer handles natively)
                if let hlsStr = streaming?["hlsManifestUrl"] as? String,
                   let hlsURL = URL(string: hlsStr) {
                    print("[Extractor] ✅ VisionOS resolved HLS manifest for \(videoId)")
                    return hlsURL
                }
            } catch {
                print("[Extractor] ❌ VisionOS extraction error for \(videoId): \(error)")
            }

            return nil
        }

        inFlightTasks[videoId] = task
        let result = await task.value
        inFlightTasks[videoId] = nil

        if let res = result {
            urlCache[videoId] = res
        }
        return result
    }

    // MARK: - Download Local Audio File (For Hardware 10-Band EQ & Balance)
    public func downloadAudio(videoId: String, streamURL: URL? = nil) async -> URL? {
        let tempDir = FileManager.default.temporaryDirectory
        let dest = tempDir.appendingPathComponent("\(videoId).m4a")

        // 1. Check if already cached on disk
        if FileManager.default.fileExists(atPath: dest.path),
           let attrs = try? FileManager.default.attributesOfItem(atPath: dest.path),
           (attrs[.size] as? UInt64 ?? 0) > 100000 {
            return dest
        }

        // 2. Resolve URL if not provided
        let targetURL: URL
        if let u = streamURL {
            targetURL = u
            urlCache[videoId] = u
        } else if let resolved = await extractAudioURL(videoId: videoId) {
            targetURL = resolved
        } else {
            return nil
        }

        // 3. Download the M4A/AAC audio file with Range: bytes=0- (bypasses Google playback throttling!)
        do {
            var request = URLRequest(url: targetURL)
            request.timeoutInterval = 15
            request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile Safari/604.1", forHTTPHeaderField: "User-Agent")
            request.setValue("bytes=0-", forHTTPHeaderField: "Range")
            let (tempFile, response) = try await URLSession.shared.download(for: request)
            if let http = response as? HTTPURLResponse, (200...399).contains(http.statusCode) {
                try? FileManager.default.removeItem(at: dest)
                try FileManager.default.moveItem(at: tempFile, to: dest)
                let size = (try? FileManager.default.attributesOfItem(atPath: dest.path))?[.size] as? UInt64 ?? 0
                if size > 100000 {
                    print("[Extractor] ✅ Successfully cached \(videoId).m4a (\(size / 1024) KB) in high-speed mode")
                    return dest
                } else {
                    print("[Extractor] ⚠️ Downloaded file too small (\(size) bytes)")
                    try? FileManager.default.removeItem(at: dest)
                }
            }
        } catch {
            print("[Extractor] Download failed for \(videoId): \(error.localizedDescription)")
        }
        return nil
    }

    // MARK: - Preload Track Ahead in Background
    public func preload(videoId: String) {
        Task(priority: .background) {
            _ = await downloadAudio(videoId: videoId)
        }
    }
}
