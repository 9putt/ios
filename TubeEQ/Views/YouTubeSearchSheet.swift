import SwiftUI

public struct YouTubeSearchSheet: View {
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject var engine = WinampPlayerEngine.shared
    @State private var searchQuery: String = ""
    @State private var isSearching: Bool = false
    @State private var searchResults: [TrackItem] = []
    @State private var urlInput: String = ""

    private let quickSuggestions = [
        "Three Man Down", "BOWKYLION", "NONT TANONT", "Jeff Satur",
        "4EVE", "bodyslam", "Tilly Birds", "Cocktail", "Billkin"
    ]

    public var body: some View {
        NavigationView {
            ZStack {
                Color(red: 0.08, green: 0.09, blue: 0.12).ignoresSafeArea()

                VStack(spacing: 12) {
                    // Search Bar
                    HStack(spacing: 8) {
                        HStack(spacing: 6) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(.gray)

                            TextField("Search YouTube songs or artists...", text: $searchQuery, onCommit: {
                                executeSearch()
                            })
                            .font(.system(size: 14))
                            .foregroundColor(.white)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)

                            if isSearching {
                                ProgressView()
                                    .scaleEffect(0.7)
                            } else if !searchQuery.isEmpty {
                                Button(action: {
                                    searchQuery = ""
                                    searchResults = []
                                }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 13))
                                        .foregroundColor(.gray)
                                }
                            }
                        }
                        .padding(10)
                        .background(Color.white.opacity(0.08))
                        .cornerRadius(10)

                        Button(action: executeSearch) {
                            Text("Search")
                                .font(.system(size: 13, weight: .bold))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                .background(Color(red: 0.0, green: 1.0, blue: 0.35))
                                .foregroundColor(.black)
                                .cornerRadius(10)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 10)

                    // Quick Search Suggestion Tags
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(quickSuggestions, id: \.self) { tag in
                                Button(action: {
                                    searchQuery = tag
                                    executeSearch()
                                }) {
                                    Text(tag)
                                        .font(.system(size: 11, weight: .semibold))
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 5)
                                        .background(Color.white.opacity(0.1))
                                        .foregroundColor(Color(red: 0.0, green: 1.0, blue: 0.35))
                                        .cornerRadius(12)
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                    }

                    // Search Results List or Suggestions
                    if !searchResults.isEmpty {
                        List {
                            ForEach(searchResults) { track in
                                Button(action: {
                                    addAndPlay(track: track)
                                }) {
                                    HStack(spacing: 12) {
                                        if let vid = track.videoId {
                                            AsyncImage(url: URL(string: "https://img.youtube.com/vi/\(vid)/default.jpg")) { phase in
                                                switch phase {
                                                case .success(let img):
                                                    img.resizable().aspectRatio(contentMode: .fill)
                                                default:
                                                    Color.black.opacity(0.3)
                                                }
                                            }
                                            .frame(width: 48, height: 36)
                                            .cornerRadius(4)
                                        }

                                        VStack(alignment: .leading, spacing: 3) {
                                            Text(track.title)
                                                .font(.system(size: 13, weight: .bold))
                                                .foregroundColor(.white)
                                                .lineLimit(1)

                                            HStack(spacing: 6) {
                                                Text(track.artist)
                                                    .font(.system(size: 11))
                                                    .foregroundColor(.gray)
                                                    .lineLimit(1)

                                                if track.duration > 0 {
                                                    Text("•")
                                                        .foregroundColor(.gray.opacity(0.5))
                                                    Text(formatTime(track.duration))
                                                        .font(.system(size: 11))
                                                        .foregroundColor(.gray)
                                                }
                                            }
                                        }

                                        Spacer()

                                        Image(systemName: "play.circle.fill")
                                            .font(.system(size: 22))
                                            .foregroundColor(Color(red: 0.0, green: 1.0, blue: 0.35))
                                    }
                                    .padding(.vertical, 4)
                                }
                                .listRowBackground(Color.white.opacity(0.04))
                            }
                        }
                        .listStyle(PlainListStyle())
                    } else if !isSearching {
                        // URL paste fallback
                        VStack(spacing: 16) {
                            Spacer()

                            VStack(alignment: .leading, spacing: 8) {
                                Text("Or Paste YouTube URL / Video ID")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(.white.opacity(0.7))

                                HStack {
                                    TextField("https://www.youtube.com/watch?v=...", text: $urlInput)
                                        .autocapitalization(.none)
                                        .disableAutocorrection(true)
                                        .padding(10)
                                        .background(Color.white.opacity(0.08))
                                        .cornerRadius(8)
                                        .foregroundColor(.white)

                                    Button(action: addFromUrl) {
                                        Text("Play")
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

                            Spacer()
                        }
                    } else {
                        Spacer()
                    }
                }
            }
            .navigationTitle("Search & Add Songs")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
    }

    private func executeSearch() {
        let trimmed = searchQuery.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        isSearching = true
        let gen = UIImpactFeedbackGenerator(style: .medium)
        gen.impactOccurred()

        YouTubeSearchManager.shared.search(query: trimmed, filterCompilations: true) { results in
            self.isSearching = false
            self.searchResults = results
        }
    }

    private func addAndPlay(track: TrackItem) {
        let gen = UIImpactFeedbackGenerator(style: .medium)
        gen.impactOccurred()

        engine.playlist.append(track)
        let idx = engine.playlist.count - 1
        engine.playTrack(at: idx)
        presentationMode.wrappedValue.dismiss()
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
        addAndPlay(track: newTrack)
    }

    private func formatTime(_ seconds: TimeInterval) -> String {
        let total = Int(seconds)
        let mins = total / 60
        let secs = total % 60
        return String(format: "%d:%02d", mins, secs)
    }
}
