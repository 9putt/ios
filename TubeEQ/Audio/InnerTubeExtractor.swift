import Foundation
import YouTubeKit

/// High-speed YouTube audio stream extractor & downloader
/// Leverages native YouTubeKit engine for deciphering signatures + fast CDN streaming
public class InnerTubeExtractor {
    public static let shared = InnerTubeExtractor()
    private var urlCache: [String: URL] = [:]
    private var inFlightTasks: [String: Task<URL?, Never>] = [:]

    private init() {}

    // MARK: - Extract Streaming URL
    public func extractAudioURL(videoId: String) async -> URL? {
        if let cached = urlCache[videoId] { return cached }

        // Prevent duplicate concurrent extractions for same video
        if let existing = inFlightTasks[videoId] {
            return await existing.value
        }

        let task = Task<URL?, Never> {
            // Strategy 1: YouTubeKit (Native Swift YouTube engine with JS deciphering)
            do {
                let video = YouTube(videoID: videoId)
                let streams = try await video.streams
                let audioStreams = streams.filterAudioOnly()
                if let best = audioStreams.highestAudioBitrateStream() ?? streams.highestAudioBitrateStream() ?? streams.first {
                    print("[Extractor] ✅ YouTubeKit resolved direct audio for \(videoId): \(best.url.absoluteString.prefix(60))...")
                    return best.url
                }
            } catch {
                print("[Extractor] YouTubeKit extraction error for \(videoId): \(error.localizedDescription)")
            }

            // Strategy 2: Fast Piped & Invidious instances (concurrent, 3s timeout)
            if let fallbackURL = await fetchFastFallbackStream(videoId: videoId) {
                print("[Extractor] ✅ Fallback resolved audio for \(videoId)")
                return fallbackURL
            }

            print("[Extractor] ❌ All extraction attempts failed for \(videoId)")
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
           (attrs[.size] as? UInt64 ?? 0) > 50000 {
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

        // 3. Download the M4A/AAC audio file
        do {
            var request = URLRequest(url: targetURL)
            request.timeoutInterval = 20
            request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile Safari/604.1", forHTTPHeaderField: "User-Agent")
            let (tempFile, response) = try await URLSession.shared.download(for: request)
            if let http = response as? HTTPURLResponse, (200...399).contains(http.statusCode) {
                try? FileManager.default.removeItem(at: dest)
                try FileManager.default.moveItem(at: tempFile, to: dest)
                let size = (try? FileManager.default.attributesOfItem(atPath: dest.path))?[.size] as? UInt64 ?? 0
                print("[Extractor] ✅ Successfully cached \(videoId).m4a (\(size / 1024) KB)")
                return dest
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

    // MARK: - Fast Parallel Fallback
    private func fetchFastFallbackStream(videoId: String) async -> URL? {
        let pipedEndpoints = [
            "https://pipedapi.kavin.rocks/streams/\(videoId)",
            "https://api.piped.privacydev.net/streams/\(videoId)",
            "https://piped-api.garudalinux.org/streams/\(videoId)"
        ]

        return await withTaskGroup(of: URL?.self) { group in
            for ep in pipedEndpoints {
                group.addTask {
                    guard let url = URL(string: ep) else { return nil }
                    var req = URLRequest(url: url)
                    req.timeoutInterval = 3.0
                    do {
                        let (data, resp) = try await URLSession.shared.data(for: req)
                        guard let http = resp as? HTTPURLResponse, http.statusCode == 200 else { return nil }
                        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                              let streams = json["audioStreams"] as? [[String: Any]] else { return nil }
                        for s in streams {
                            let mime = (s["mimeType"] as? String ?? "").lowercased()
                            if mime.contains("mp4") || mime.contains("aac") || mime.contains("m4a") {
                                if let urlStr = s["url"] as? String, let resURL = URL(string: urlStr) {
                                    return resURL
                                }
                            }
                        }
                        if let first = streams.first, let urlStr = first["url"] as? String {
                            return URL(string: urlStr)
                        }
                    } catch {}
                    return nil
                }
            }

            for await result in group {
                if let url = result {
                    group.cancelAll()
                    return url
                }
            }
            return nil
        }
    }
}
