import Foundation
#if canImport(YouTubeKit)
import YouTubeKit
#endif

public class YouTubeAudioResolver {
    public static let shared = YouTubeAudioResolver()

    private var cache: [String: URL] = [:]
    private var downloadTasks: [String: Task<URL?, Never>] = [:]

    private init() {}

    /// Resolves direct audio stream URL for a YouTube video, prioritizing native Apple-supported AAC/M4A
    public func resolveAudioStreamURL(videoId: String) async -> URL? {
        if let cached = cache[videoId] {
            return cached
        }

        #if canImport(YouTubeKit)
        do {
            let yt = YouTube(videoID: videoId)
            let streams = try await yt.streams
            let audioOnly = streams.filterAudioOnly()

            // Prioritize MP4 / M4A (AAC) streams that Apple CoreAudio decodes natively
            let m4aStream = audioOnly.first(where: {
                $0.subtype.lowercased() == "mp4" ||
                $0.mimeType.lowercased().contains("mp4") ||
                $0.mimeType.lowercased().contains("m4a") ||
                $0.mimeType.lowercased().contains("aac")
            })

            if let chosen = m4aStream ?? audioOnly.highestAudioBitrateStream() ?? audioOnly.first {
                let directURL = chosen.url
                cache[videoId] = directURL
                print("[YouTubeAudioResolver] Found YouTubeKit stream for \(videoId): \(directURL)")
                return directURL
            }
        } catch {
            print("[YouTubeAudioResolver] YouTubeKit stream resolution error for \(videoId): \(error)")
        }
        #endif

        // Fallback 1: Invidious public REST API
        if let fallbackURL = await resolveViaInvidious(videoId: videoId) {
            cache[videoId] = fallbackURL
            return fallbackURL
        }

        // Fallback 2: Piped public REST API
        if let pipedURL = await resolveViaPiped(videoId: videoId) {
            cache[videoId] = pipedURL
            return pipedURL
        }

        return nil
    }

    private func resolveViaPiped(videoId: String) async -> URL? {
        let instances = [
            "https://pipedapi.kavin.rocks",
            "https://api.piped.privacydev.net",
            "https://piped-api.garudalinux.org"
        ]

        for instance in instances {
            guard let url = URL(string: "\(instance)/streams/\(videoId)") else { continue }
            do {
                var req = URLRequest(url: url)
                req.timeoutInterval = 4.0
                let (data, res) = try await URLSession.shared.data(for: req)
                guard let http = res as? HTTPURLResponse, http.statusCode == 200 else { continue }

                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let audioStreams = json["audioStreams"] as? [[String: Any]] {
                    for stream in audioStreams {
                        let fmt = (stream["format"] as? String ?? "").lowercased()
                        let mime = (stream["mimeType"] as? String ?? "").lowercased()
                        if fmt.contains("m4a") || mime.contains("mp4") || mime.contains("m4a") || mime.contains("aac") {
                            if let urlStr = stream["url"] as? String, let streamURL = URL(string: urlStr) {
                                print("[YouTubeAudioResolver] Resolved via Piped (\(instance)) for \(videoId)")
                                return streamURL
                            }
                        }
                    }
                    if let first = audioStreams.first, let urlStr = first["url"] as? String, let streamURL = URL(string: urlStr) {
                        return streamURL
                    }
                }
            } catch {
                continue
            }
        }
        return nil
    }

    private func resolveViaInvidious(videoId: String) async -> URL? {
        let instances = [
            "https://inv.tux.pizza",
            "https://invidious.nerdvpn.de",
            "https://yewtu.be",
            "https://vid.puffyan.us"
        ]

        for instance in instances {
            guard let url = URL(string: "\(instance)/api/v1/videos/\(videoId)") else { continue }
            do {
                var req = URLRequest(url: url)
                req.timeoutInterval = 4.0
                let (data, res) = try await URLSession.shared.data(for: req)
                guard let http = res as? HTTPURLResponse, http.statusCode == 200 else { continue }

                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let adaptiveFormats = json["adaptiveFormats"] as? [[String: Any]] {
                    // Find audio/mp4 format
                    for fmt in adaptiveFormats {
                        let type = fmt["type"] as? String ?? ""
                        if type.contains("audio/mp4") || type.contains("audio/m4a") || type.contains("audio/aac") {
                            if let urlStr = fmt["url"] as? String, let streamURL = URL(string: urlStr) {
                                print("[YouTubeAudioResolver] Resolved via \(instance) for \(videoId)")
                                return streamURL
                            }
                        }
                    }
                }
            } catch {
                continue
            }
        }
        return nil
    }

    /// Downloads and caches direct audio file for 100% CoreAudio 10-Band EQ, Pan Balance, and True Crossfade
    public func fetchLocalAudioFile(videoId: String) async -> URL? {
        let tempDir = FileManager.default.temporaryDirectory
        let destination = tempDir.appendingPathComponent("\(videoId).m4a")

        // If file already exists and is valid (> 50KB)
        if FileManager.default.fileExists(atPath: destination.path) {
            if let attrs = try? FileManager.default.attributesOfItem(atPath: destination.path),
               let size = attrs[.size] as? UInt64, size > 50000 {
                return destination
            }
        }

        // Avoid duplicate concurrent download tasks for the same video
        if let ongoing = downloadTasks[videoId] {
            return await ongoing.value
        }

        let task = Task<URL?, Never> {
            guard let streamURL = await self.resolveAudioStreamURL(videoId: videoId) else {
                return nil
            }

            do {
                let (tempLocation, response) = try await URLSession.shared.download(from: streamURL)
                if let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) {
                    try? FileManager.default.removeItem(at: destination)
                    try FileManager.default.moveItem(at: tempLocation, to: destination)
                    print("[YouTubeAudioResolver] Successfully downloaded and cached \(videoId).m4a")
                    return destination
                }
            } catch {
                print("[YouTubeAudioResolver] Download error for \(videoId): \(error)")
            }

            return nil
        }

        downloadTasks[videoId] = task
        let result = await task.value
        downloadTasks.removeValue(forKey: videoId)
        return result
    }

    /// Preload next track in background
    public func preload(videoId: String) {
        Task(priority: .background) {
            _ = await self.fetchLocalAudioFile(videoId: videoId)
        }
    }
}
