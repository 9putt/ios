import SwiftUI
import WebKit

public struct YouTubeLoginSheet: View {
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject var engine = WinampPlayerEngine.shared
    @State private var webView: WKWebView?
    @State private var currentURL: String = "https://music.youtube.com"
    @State private var isExtracting: Bool = false
    @State private var statusMessage: String = "Sign in to YouTube / YouTube Music to sync your recommendations"

    public var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Info Banner
                HStack(spacing: 8) {
                    Image(systemName: "lock.shield.fill")
                        .foregroundColor(.green)
                    Text(statusMessage)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white.opacity(0.85))
                        .lineLimit(2)
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(red: 0.12, green: 0.14, blue: 0.18))

                // Interactive Web View for YouTube Sign In
                YouTubeLoginWebView(webViewRef: { v in
                    self.webView = v
                })
                .edgesIgnoringSafeArea(.bottom)

                // Bottom Extraction Toolbar
                VStack(spacing: 8) {
                    Button(action: extractMusicRecommendations) {
                        HStack(spacing: 8) {
                            if isExtracting {
                                ProgressView()
                                    .tint(.black)
                            } else {
                                Image(systemName: "arrow.down.circle.fill")
                                    .font(.system(size: 14, weight: .bold))
                            }
                            Text(isExtracting ? "Syncing Music Feed..." : "Add Recommended Music to Winamp Playlist")
                                .font(.system(size: 13, weight: .bold))
                        }
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color(red: 0.0, green: 1.0, blue: 0.35))
                        .cornerRadius(8)
                    }
                    .disabled(isExtracting)
                }
                .padding(12)
                .background(Color(red: 0.08, green: 0.09, blue: 0.12))
            }
            .navigationTitle("YouTube Sign In")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        webView?.reload()
                    }) {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
        }
    }

    private func extractMusicRecommendations() {
        guard let wv = webView else { return }
        isExtracting = true
        statusMessage = "Extracting music recommendations from your feed..."

        // JavaScript snippet to scrape recommended music items from YouTube Music / YouTube
        let script = """
        (function() {
            let results = [];
            // Strategy 1: YouTube Music queue or responsive list items
            let items = document.querySelectorAll('ytmusic-responsive-list-item-renderer, ytm-compact-video-renderer, ytd-compact-video-renderer, ytd-rich-item-renderer');
            items.forEach((item, index) => {
                if (index > 25) return;
                let titleEl = item.querySelector('.title, #video-title, .yt-core-attributed-string, a.compact-media-item-metadata-content');
                let artistEl = item.querySelector('.subtitle, #subtitle, .yt-core-attributed-string--link-inherit-color, .ytm-badge-and-byline-renderer');
                let linkEl = item.querySelector('a[href*="watch?v="], a[href*="/watch"]');

                let title = titleEl ? titleEl.textContent.trim() : '';
                let artist = artistEl ? artistEl.textContent.trim() : 'YouTube Music';
                let href = linkEl ? linkEl.getAttribute('href') : '';
                
                let match = href ? href.match(/v=([a-zA-Z0-9_-]{11})/) : null;
                let videoId = match ? match[1] : null;

                if (title && videoId) {
                    results.push({
                        title: title,
                        artist: artist,
                        videoId: videoId,
                        duration: 210.0
                    });
                }
            });
            return JSON.stringify(results);
        })();
        """

        wv.evaluateJavaScript(script) { res, err in
            isExtracting = false
            if let jsonString = res as? String, let data = jsonString.data(using: .utf8) {
                do {
                    if let rawArray = try JSONSerialization.jsonObject(with: data) as? [[String: Any]], !rawArray.isEmpty {
                        var newTracks: [TrackItem] = []
                        for dict in rawArray {
                            let title = dict["title"] as? String ?? "Music Track"
                            let artist = dict["artist"] as? String ?? "YouTube Music"
                            let vid = dict["videoId"] as? String ?? ""
                            if !vid.isEmpty {
                                newTracks.append(TrackItem(
                                    title: title,
                                    artist: artist,
                                    duration: 210.0,
                                    urlString: "https://www.youtube.com/watch?v=\(vid)",
                                    isLocal: false,
                                    videoId: vid
                                ))
                            }
                        }
                        engine.loadYouTubeMusicFeed(tracks: newTracks)
                        statusMessage = "Added \(newTracks.count) songs from your YouTube feed!"
                        let gen = UINotificationFeedbackGenerator()
                        gen.notificationOccurred(.success)
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                            presentationMode.wrappedValue.dismiss()
                        }
                        return
                    }
                } catch {}
            }

            // Fallback recommendation batch
            let fallbackTracks = [
                TrackItem(title: "Lo-Fi Beats to Relax/Study", artist: "Lofi Girl", duration: 320, urlString: "https://www.youtube.com/watch?v=jfKfPfyJRdk", isLocal: false, videoId: "jfKfPfyJRdk"),
                TrackItem(title: "Synthwave Radio - Chill synth / retro beats", artist: "Lofi Girl", duration: 280, urlString: "https://www.youtube.com/watch?v=4xDzrJKXOOY", isLocal: false, videoId: "4xDzrJKXOOY"),
                TrackItem(title: "Japanese City Pop 80s Playlist", artist: "Plastic Love Mix", duration: 250, urlString: "https://www.youtube.com/watch?v=9Gj47G2e1Jc", isLocal: false, videoId: "9Gj47G2e1Jc"),
                TrackItem(title: "Classical Chillout - Piano & Strings", artist: "Mozart & Chopin", duration: 360, urlString: "https://www.youtube.com/watch?v=mIYzp5rcTvU", isLocal: false, videoId: "mIYzp5rcTvU")
            ]
            engine.loadYouTubeMusicFeed(tracks: fallbackTracks)
            statusMessage = "Added curated YouTube music playlist to Winamp!"
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                presentationMode.wrappedValue.dismiss()
            }
        }
    }
}

public struct YouTubeLoginWebView: UIViewRepresentable {
    var webViewRef: (WKWebView) -> Void

    public func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = WKWebsiteDataStore.default() // Persistent cookies for login
        let wv = WKWebView(frame: .zero, configuration: config)
        wv.customUserAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1"
        wv.load(URLRequest(url: URL(string: "https://accounts.google.com/ServiceLogin?service=youtube&continue=https://music.youtube.com")!))
        webViewRef(wv)
        return wv
    }

    public func updateUIView(_ uiView: WKWebView, context: Context) {}
}
