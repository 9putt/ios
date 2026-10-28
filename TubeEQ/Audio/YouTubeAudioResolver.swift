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

            // 1. Prioritize MP4 / M4A (AAC) streams that Apple CoreAudio decodes natively
            let m4aStream = audioOnly.first(where: {
                $0.subtype.lowercased() == "mp4" ||
                $0.mimeType.lowercased().contains("mp4") ||
                $0.mimeType.lowercased().contains("m4a") ||
                $0.mimeType.lowercased().contains("aac")
            })

            if let chosen = m4aStream ?? audioOnly.highestAudioBitrateStream() ?? audioOnly.first {
                let directURL = chosen.url
                cache[videoId] = directURL
                print("[YouTubeAudioResolver] Found audio stream for \(videoId) (format: \(chosen.subtype), mime: \(chosen.mimeType))")
                return directURL
            }
        } catch {
            print("[YouTubeAudioResolver] YouTubeKit stream resolution error for \(videoId): \(error)")
        }
        #endif

        return nil
    }

    /// Downloads and caches direct audio file for 100% CoreAudio 10-Band EQ, Pan Balance, and true Crossfade
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
                    print("[YouTubeAudioResolver] Successfully cached \(videoId).m4a at \(destination.path)")
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
}
