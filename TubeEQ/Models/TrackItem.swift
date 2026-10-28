import Foundation

public struct TrackItem: Identifiable, Codable, Equatable {
    public var id: UUID
    public var title: String
    public var artist: String
    public var duration: TimeInterval
    public var urlString: String
    public var isLocal: Bool
    public var thumbnailURL: String?
    public var videoId: String?

    public init(
        id: UUID = UUID(),
        title: String,
        artist: String = "YouTube Music",
        duration: TimeInterval = 0,
        urlString: String,
        isLocal: Bool = false,
        thumbnailURL: String? = nil,
        videoId: String? = nil
    ) {
        self.id = id
        self.title = title
        self.artist = artist
        self.duration = duration
        self.urlString = urlString
        self.isLocal = isLocal
        self.thumbnailURL = thumbnailURL
        self.videoId = videoId
    }

    public var formattedDuration: String {
        guard duration > 0 else { return "--:--" }
        let totalSeconds = Int(duration)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    public var displayTitle: String {
        if artist.isEmpty || artist == "Unknown Artist" || artist == "YouTube Music" {
            return title
        }
        return "\(artist) - \(title)"
    }
}
