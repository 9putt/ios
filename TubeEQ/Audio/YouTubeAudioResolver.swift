import Foundation
#if canImport(YouTubeKit)
import YouTubeKit
#endif

public class YouTubeAudioResolver {
    public static let shared = YouTubeAudioResolver()

    private var cache: [String: URL] = [:]
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
}
