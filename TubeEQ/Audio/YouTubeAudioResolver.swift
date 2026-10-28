import Foundation
#if canImport(YouTubeKit)
import YouTubeKit
#endif

public class YouTubeAudioResolver {
    public static let shared = YouTubeAudioResolver()

    private var cache: [String: URL] = [:]
    private var downloadTasks: [String: Task<URL?, Never>] = [:]

    private init() {}

    /// Resolves direct audio stream URL for a YouTube video
    public func resolveAudioStreamURL(videoId: String) async -> URL? {
        if let cached = cache[videoId] {
            return cached
        }

        #if canImport(YouTubeKit)
        do {
            let yt = YouTube(videoID: videoId)
            let streams = try await yt.streams
            if let audio = streams.filterAudioOnly().highestAudioBitrateStream() {
                let directURL = audio.url
                cache[videoId] = directURL
                print("[YouTubeAudioResolver] Successfully extracted direct audio stream for \(videoId)")
                return directURL
            }
        } catch {
            print("[YouTubeAudioResolver] YouTubeKit stream extraction error for \(videoId): \(error)")
        }
        #endif

        return nil
    }

    /// Downloads and caches direct audio file for 100% CoreAudio EQ, Pan balance, and true crossfade
    public func fetchLocalAudioFile(videoId: String) async -> URL? {
        let tempDir = FileManager.default.temporaryDirectory
        let destination = tempDir.appendingPathComponent("\(videoId).m4a")

        if FileManager.default.fileExists(atPath: destination.path) {
            return destination
        }

        guard let streamURL = await resolveAudioStreamURL(videoId: videoId) else {
            return nil
        }

        do {
            let (tempLocation, response) = try await URLSession.shared.download(from: streamURL)
            if let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) {
                try? FileManager.default.removeItem(at: destination)
                try FileManager.default.moveItem(at: tempLocation, to: destination)
                print("[YouTubeAudioResolver] Cached local audio for \(videoId) at \(destination.path)")
                return destination
            }
        } catch {
            print("[YouTubeAudioResolver] Download error for \(videoId): \(error)")
        }

        return nil
    }
}
