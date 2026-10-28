import SwiftUI

public struct YouTubeSearchSheet: View {
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject var engine = WinampPlayerEngine.shared
    @State private var query: String = ""
    @State private var urlInput: String = ""

    public var body: some View {
        NavigationView {
            ZStack {
                Color(red: 0.08, green: 0.09, blue: 0.12).ignoresSafeArea()

                VStack(spacing: 16) {
                    // Quick Paste URL Section
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Paste YouTube URL / Video ID")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.white)

                        HStack {
                            TextField("https://www.youtube.com/watch?v=...", text: $urlInput)
                                .autocapitalization(.none)
                                .disableAutocorrection(true)
                                .padding(10)
                                .background(Color.white.opacity(0.08))
                                .cornerRadius(8)
                                .foregroundColor(.white)

                            Button(action: addFromUrl) {
                                Text("Add")
                                    .font(.system(size: 13, weight: .bold))
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 10)
                                    .background(Color(red: 0.0, green: 1.0, blue: 0.35))
                                    .foregroundColor(.black)
                                    .cornerRadius(8)
                            }
                            .disabled(urlInput.trimmingCharacters(in: .whitespaces).isEmpty)
                        }
                    }
                    .padding(14)
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(12)
                    .padding(.horizontal, 16)
                    .padding(.top, 10)

                    // Popular Music Presets to add with 1 tap
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Suggested Music Streams")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.white.opacity(0.8))
                            .padding(.horizontal, 16)

                        let presets: [(String, String, String)] = [
                            ("Lofi Hip Hop Radio - Beats to relax/study to", "Lofi Girl", "jfKfPfyJRdk"),
                            ("Synthwave Radio - Chill Synth / Retro Beats", "Lofi Girl", "4xDzrJKXOOY"),
                            ("Classical Chillout - Mozart, Chopin, Beethoven", "HALIDONMUSIC", "mIYzp5rcTvU"),
                            ("Japanese 80s City Pop Night Drive", "CityPop Radio", "9Gj47G2e1Jc"),
                            ("Deep Focus Music - Binaural Ambient Study", "Body Mind Zone", "WPni755-Krg")
                        ]

                        ForEach(presets, id: \.2) { title, artist, vid in
                            Button(action: {
                                let track = TrackItem(
                                    title: title,
                                    artist: artist,
                                    duration: 240,
                                    urlString: "https://www.youtube.com/watch?v=\(vid)",
                                    isLocal: false,
                                    videoId: vid
                                )
                                engine.playlist.append(track)
                                let gen = UIImpactFeedbackGenerator(style: .medium)
                                gen.impactOccurred()
                                presentationMode.wrappedValue.dismiss()
                            }) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(title)
                                            .font(.system(size: 12, weight: .bold))
                                            .foregroundColor(.white)
                                            .lineLimit(1)
                                        Text(artist)
                                            .font(.system(size: 10))
                                            .foregroundColor(.gray)
                                    }
                                    Spacer()
                                    Image(systemName: "plus.circle.fill")
                                        .foregroundColor(Color(red: 0.0, green: 1.0, blue: 0.35))
                                }
                                .padding(10)
                                .background(Color.white.opacity(0.04))
                                .cornerRadius(8)
                            }
                            .padding(.horizontal, 16)
                        }
                    }

                    Spacer()
                }
            }
            .navigationTitle("Add YouTube Track")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
    }

    private func addFromUrl() {
        let trimmed = urlInput.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        var videoId = trimmed
        if trimmed.contains("v=") {
            let parts = trimmed.components(separatedBy: "v=")
            if let id = parts.last?.components(separatedBy: "&").first {
                videoId = id
            }
        } else if trimmed.contains("youtu.be/") {
            let parts = trimmed.components(separatedBy: "youtu.be/")
            if let id = parts.last?.components(separatedBy: "?").first {
                videoId = id
            }
        }

        let newTrack = TrackItem(
            title: "YouTube: \(videoId)",
            artist: "YouTube Stream",
            duration: 210,
            urlString: "https://www.youtube.com/watch?v=\(videoId)",
            isLocal: false,
            videoId: videoId
        )
        engine.playlist.append(newTrack)
        presentationMode.wrappedValue.dismiss()
    }
}
