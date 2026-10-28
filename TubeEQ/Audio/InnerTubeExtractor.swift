import Foundation

/// Extracts direct audio stream URLs from YouTube using InnerTube API
/// Architecture modeled after Tube EQ's YoutubeExtractor + DlpExtractor
public class InnerTubeExtractor {
    public static let shared = InnerTubeExtractor()
    private var urlCache: [String: URL] = [:]
    private init() {}

    // MARK: - Public API
    public func extractAudioURL(videoId: String) async -> URL? {
        if let cached = urlCache[videoId] { return cached }

        // Strategy 1: IOS client (often returns direct URLs for music)
        if let url = await tryIOSClient(videoId: videoId) {
            urlCache[videoId] = url
            print("[InnerTube] ✅ IOS client resolved audio for \(videoId)")
            return url
        }

        // Strategy 2: ANDROID client
        if let url = await tryAndroidClient(videoId: videoId) {
            urlCache[videoId] = url
            print("[InnerTube] ✅ ANDROID client resolved audio for \(videoId)")
            return url
        }

        // Strategy 3: TV embedded client (historically more permissive)
        if let url = await tryTVClient(videoId: videoId) {
            urlCache[videoId] = url
            print("[InnerTube] ✅ TV client resolved audio for \(videoId)")
            return url
        }

        // Strategy 4: WEB client
        if let url = await tryWEBClient(videoId: videoId) {
            urlCache[videoId] = url
            print("[InnerTube] ✅ WEB client resolved audio for \(videoId)")
            return url
        }

        // Strategy 5: Invidious public instances
        if let url = await tryInvidious(videoId: videoId) {
            urlCache[videoId] = url
            print("[InnerTube] ✅ Invidious resolved audio for \(videoId)")
            return url
        }

        // Strategy 6: Piped public instances
        if let url = await tryPiped(videoId: videoId) {
            urlCache[videoId] = url
            print("[InnerTube] ✅ Piped resolved audio for \(videoId)")
            return url
        }

        // Strategy 7: Cobalt API
        if let url = await tryCobalt(videoId: videoId) {
            urlCache[videoId] = url
            print("[InnerTube] ✅ Cobalt resolved audio for \(videoId)")
            return url
        }

        print("[InnerTube] ❌ All extraction strategies failed for \(videoId)")
        return nil
    }

    /// Downloads audio to local file for CoreAudio playback with 10-Band EQ
    public func downloadAudio(videoId: String) async -> URL? {
        let tempDir = FileManager.default.temporaryDirectory
        let dest = tempDir.appendingPathComponent("\(videoId).m4a")

        // Check cache
        if FileManager.default.fileExists(atPath: dest.path),
           let attrs = try? FileManager.default.attributesOfItem(atPath: dest.path),
           (attrs[.size] as? UInt64 ?? 0) > 50000 {
            return dest
        }

        guard let streamURL = await extractAudioURL(videoId: videoId) else { return nil }

        do {
            let (tempFile, response) = try await URLSession.shared.download(from: streamURL)
            if let http = response as? HTTPURLResponse, (200...399).contains(http.statusCode) {
                try? FileManager.default.removeItem(at: dest)
                try FileManager.default.moveItem(at: tempFile, to: dest)

                let size = (try? FileManager.default.attributesOfItem(atPath: dest.path))?[.size] as? UInt64 ?? 0
                print("[InnerTube] Downloaded \(videoId).m4a (\(size / 1024)KB)")
                return dest
            }
        } catch {
            print("[InnerTube] Download error: \(error.localizedDescription)")
        }
        return nil
    }

    public func preload(videoId: String) {
        Task(priority: .background) { _ = await downloadAudio(videoId: videoId) }
    }

    // MARK: - InnerTube API Strategies

    private func tryIOSClient(videoId: String) async -> URL? {
        return await callInnerTube(
            videoId: videoId,
            endpoint: "https://www.youtube.com/youtubei/v1/player?prettyPrint=false",
            clientName: "IOS",
            clientVersion: "19.29.1",
            userAgent: "com.google.ios.youtube/19.29.1 (iPhone16,2; U; CPU iOS 17_5_1 like Mac OS X;)",
            extraClient: [
                "deviceMake": "Apple",
                "deviceModel": "iPhone16,2",
                "osName": "iOS",
                "osVersion": "17.5.1"
            ],
            clientNameId: "5"
        )
    }

    private func tryAndroidClient(videoId: String) async -> URL? {
        return await callInnerTube(
            videoId: videoId,
            endpoint: "https://www.youtube.com/youtubei/v1/player?prettyPrint=false",
            clientName: "ANDROID",
            clientVersion: "19.09.37",
            userAgent: "com.google.android.youtube/19.09.37 (Linux; U; Android 12; US) gzip",
            extraClient: [
                "androidSdkVersion": 31,
                "osName": "Android",
                "osVersion": "12"
            ],
            clientNameId: "3"
        )
    }

    private func tryTVClient(videoId: String) async -> URL? {
        return await callInnerTube(
            videoId: videoId,
            endpoint: "https://www.youtube.com/youtubei/v1/player?prettyPrint=false",
            clientName: "TVHTML5_SIMPLY_EMBEDDED_PLAYER",
            clientVersion: "2.0",
            userAgent: "Mozilla/5.0 (ChromiumStylePlatform) Cobalt/Version",
            extraClient: [:],
            clientNameId: "85"
        )
    }

    private func tryWEBClient(videoId: String) async -> URL? {
        return await callInnerTube(
            videoId: videoId,
            endpoint: "https://www.youtube.com/youtubei/v1/player?prettyPrint=false",
            clientName: "WEB",
            clientVersion: "2.20241001.00.00",
            userAgent: "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.5 Safari/605.1.15",
            extraClient: [:],
            clientNameId: "1"
        )
    }

    private func callInnerTube(
        videoId: String,
        endpoint: String,
        clientName: String,
        clientVersion: String,
        userAgent: String,
        extraClient: [String: Any],
        clientNameId: String
    ) async -> URL? {
        guard let url = URL(string: endpoint) else { return nil }

        var clientDict: [String: Any] = [
            "clientName": clientName,
            "clientVersion": clientVersion,
            "hl": "en",
            "gl": "US"
        ]
        for (k, v) in extraClient { clientDict[k] = v }

        let payload: [String: Any] = [
            "context": ["client": clientDict],
            "videoId": videoId,
            "contentCheckOk": true,
            "racyCheckOk": true,
            "playbackContext": [
                "contentPlaybackContext": [
                    "html5Preference": "HTML5_PREF_WANTS"
                ]
            ]
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("https://www.youtube.com", forHTTPHeaderField: "Origin")
        request.setValue(clientNameId, forHTTPHeaderField: "X-YouTube-Client-Name")
        request.setValue(clientVersion, forHTTPHeaderField: "X-YouTube-Client-Version")
        request.httpBody = try? JSONSerialization.data(withJSONObject: payload)
        request.timeoutInterval = 8

        do {
            let (data, resp) = try await URLSession.shared.data(for: request)
            guard let http = resp as? HTTPURLResponse, http.statusCode == 200 else { return nil }
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }

            // Check playability
            if let ps = json["playabilityStatus"] as? [String: Any],
               let status = ps["status"] as? String, status != "OK" {
                print("[InnerTube] \(clientName): status=\(status)")
                return nil
            }

            return extractBestAudioURL(from: json)
        } catch {
            print("[InnerTube] \(clientName) error: \(error.localizedDescription)")
            return nil
        }
    }

    private func extractBestAudioURL(from json: [String: Any]) -> URL? {
        guard let sd = json["streamingData"] as? [String: Any] else { return nil }

        // Priority 1: Direct AAC/M4A audio from adaptiveFormats
        if let formats = sd["adaptiveFormats"] as? [[String: Any]] {
            // Find audio/mp4 (AAC) — natively supported by iOS CoreAudio
            var aacAudio: [[String: Any]] = []
            var anyAudio: [[String: Any]] = []

            for fmt in formats {
                let mime = (fmt["mimeType"] as? String ?? "").lowercased()
                guard mime.contains("audio") else { continue }
                guard let urlStr = fmt["url"] as? String, !urlStr.isEmpty else { continue }

                anyAudio.append(fmt)
                if mime.contains("mp4a") || mime.contains("audio/mp4") {
                    aacAudio.append(fmt)
                }
            }

            // Sort by bitrate (highest first)
            let sorted = (aacAudio.isEmpty ? anyAudio : aacAudio).sorted {
                ($0["bitrate"] as? Int ?? 0) > ($1["bitrate"] as? Int ?? 0)
            }

            if let best = sorted.first, let urlStr = best["url"] as? String, let url = URL(string: urlStr) {
                let bitrate = best["bitrate"] as? Int ?? 0
                print("[InnerTube] Found audio: \(best["mimeType"] ?? "?") @ \(bitrate/1000)kbps")
                return url
            }
        }

        // Priority 2: HLS manifest (iOS AVPlayer handles HLS natively)
        if let hls = sd["hlsManifestUrl"] as? String, let url = URL(string: hls) {
            print("[InnerTube] Found HLS manifest")
            return url
        }

        return nil
    }

    // MARK: - Third-Party Fallbacks

    private func tryInvidious(videoId: String) async -> URL? {
        let instances = [
            "https://inv.tux.pizza",
            "https://invidious.nerdvpn.de",
            "https://yewtu.be",
            "https://vid.puffyan.us",
            "https://invidious.fdn.fr"
        ]
        for inst in instances {
            if let url = await queryInvidious(instance: inst, videoId: videoId) { return url }
        }
        return nil
    }

    private func queryInvidious(instance: String, videoId: String) async -> URL? {
        guard let url = URL(string: "\(instance)/api/v1/videos/\(videoId)") else { return nil }
        var req = URLRequest(url: url)
        req.timeoutInterval = 4
        do {
            let (data, resp) = try await URLSession.shared.data(for: req)
            guard let http = resp as? HTTPURLResponse, http.statusCode == 200 else { return nil }
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
            if let formats = json["adaptiveFormats"] as? [[String: Any]] {
                for fmt in formats {
                    let type = (fmt["type"] as? String ?? "").lowercased()
                    if (type.contains("audio/mp4") || type.contains("mp4a")),
                       let urlStr = fmt["url"] as? String, let streamURL = URL(string: urlStr) {
                        return streamURL
                    }
                }
            }
        } catch {}
        return nil
    }

    private func tryPiped(videoId: String) async -> URL? {
        let instances = [
            "https://pipedapi.kavin.rocks",
            "https://api.piped.privacydev.net",
            "https://piped-api.garudalinux.org"
        ]
        for inst in instances {
            if let url = await queryPiped(instance: inst, videoId: videoId) { return url }
        }
        return nil
    }

    private func queryPiped(instance: String, videoId: String) async -> URL? {
        guard let url = URL(string: "\(instance)/streams/\(videoId)") else { return nil }
        var req = URLRequest(url: url)
        req.timeoutInterval = 4
        do {
            let (data, resp) = try await URLSession.shared.data(for: req)
            guard let http = resp as? HTTPURLResponse, http.statusCode == 200 else { return nil }
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let streams = json["audioStreams"] as? [[String: Any]] else { return nil }
            // Prefer m4a/aac
            for s in streams {
                let mime = (s["mimeType"] as? String ?? "").lowercased()
                let fmt = (s["format"] as? String ?? "").lowercased()
                if (mime.contains("mp4") || mime.contains("aac") || fmt.contains("m4a")),
                   let urlStr = s["url"] as? String, let streamURL = URL(string: urlStr) {
                    return streamURL
                }
            }
            // Fallback: any audio
            if let first = streams.first, let urlStr = first["url"] as? String {
                return URL(string: urlStr)
            }
        } catch {}
        return nil
    }

    private func tryCobalt(videoId: String) async -> URL? {
        let instances = ["https://api.cobalt.tools"]
        for inst in instances {
            guard let url = URL(string: "\(inst)/api/json") else { continue }
            var req = URLRequest(url: url)
            req.httpMethod = "POST"
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.setValue("application/json", forHTTPHeaderField: "Accept")
            req.timeoutInterval = 6
            let body: [String: Any] = [
                "url": "https://www.youtube.com/watch?v=\(videoId)",
                "isAudioOnly": true,
                "aFormat": "mp3"
            ]
            req.httpBody = try? JSONSerialization.data(withJSONObject: body)
            do {
                let (data, resp) = try await URLSession.shared.data(for: req)
                guard let http = resp as? HTTPURLResponse, http.statusCode == 200 else { continue }
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let urlStr = json["url"] as? String, let streamURL = URL(string: urlStr) {
                    return streamURL
                }
            } catch { continue }
        }
        return nil
    }
}
