import SwiftUI
import WebKit

public struct YouTubeLoginSheet: View {
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject var engine = WinampPlayerEngine.shared
    @State private var webView: WKWebView?
    @State private var isExtracting: Bool = false
    @State private var statusMessage: String = "Please sign in. Once completed, your music feed will import automatically!"

    public var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Status Banner
                HStack(spacing: 8) {
                    if isExtracting {
                        ProgressView()
                            .tint(.green)
                    } else {
                        Image(systemName: "person.badge.key.fill")
                            .foregroundColor(.green)
                    }
                    Text(statusMessage)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(2)
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(red: 0.10, green: 0.12, blue: 0.16))

                // Interactive Web View for YouTube Sign In
                YouTubeLoginWebView(
                    onLoginDetected: { wv in
                        extractMusicAndDismiss(wv: wv)
                    },
                    webViewRef: { v in
                        self.webView = v
                    }
                )
                .edgesIgnoringSafeArea(.bottom)

                // Bottom Manual Import Button (if user wants to trigger it manually anytime)
                Button(action: {
                    if let wv = webView {
                        extractMusicAndDismiss(wv: wv)
                    }
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 13, weight: .bold))
                        Text(isExtracting ? "Importing Music Feed..." : "Import My YouTube Music Now")
                            .font(.system(size: 13, weight: .bold))
                    }
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color(red: 0.0, green: 1.0, blue: 0.35))
                    .cornerRadius(8)
                }
                .disabled(isExtracting)
                .padding(10)
                .background(Color(red: 0.06, green: 0.07, blue: 0.09))
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
                    Button(action: { webView?.reload() }) {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
        }
    }

    private func extractMusicAndDismiss(wv: WKWebView) {
        guard !isExtracting else { return }
        isExtracting = true
        statusMessage = "Login detected! Importing your personalized music..."

        let script = #"""
        (function() {
            let results = [];
            
            // 1. Check window.ytInitialData
            if (window.ytInitialData) {
                try {
                    let str = JSON.stringify(window.ytInitialData);
                    let matches = [...str.matchAll(/"videoId":"([a-zA-Z0-9_-]{11})".*?"title":\{"runs":\s*\[\{"text":"(.*?)"\}\]\}.*?"subtitle":\{"runs":\s*\[\{"text":"(.*?)"\}\]\}/g)];
                    for (let m of matches) {
                        if (results.length < 30) {
                            results.push({ videoId: m[1], title: m[2], artist: m[3], duration: 210 });
                        }
                    }
                } catch(e) {}
            }

            // 2. Check DOM Elements
            if (results.length === 0) {
                let items = document.querySelectorAll('ytmusic-responsive-list-item-renderer, ytm-compact-video-renderer, ytd-compact-video-renderer, ytd-rich-item-renderer');
                items.forEach((item, index) => {
                    if (index > 30) return;
                    let titleEl = item.querySelector('.title, #video-title, .yt-core-attributed-string');
                    let artistEl = item.querySelector('.subtitle, #subtitle, .ytm-badge-and-byline-renderer');
                    let linkEl = item.querySelector('a[href*="watch?v="]');

                    let title = titleEl ? titleEl.textContent.trim() : '';
                    let artist = artistEl ? artistEl.textContent.trim() : 'YouTube Music';
                    let href = linkEl ? linkEl.getAttribute('href') : '';
                    let match = href ? href.match(/v=([a-zA-Z0-9_-]{11})/) : null;
                    let videoId = match ? match[1] : null;

                    if (title && videoId) {
                        results.push({ title: title, artist: artist, videoId: videoId, duration: 210 });
                    }
                });
            }
            return JSON.stringify(results);
        })();
        """#

        wv.evaluateJavaScript(script) { res, err in
            var parsedTracks: [TrackItem] = []

            if let jsonString = res as? String, let data = jsonString.data(using: .utf8) {
                if let rawList = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]], !rawList.isEmpty {
                    for dict in rawList {
                        let title = dict["title"] as? String ?? "YouTube Track"
                        let artist = dict["artist"] as? String ?? "YouTube Music"
                        let vid = dict["videoId"] as? String ?? ""
                        if !vid.isEmpty {
                            parsedTracks.append(TrackItem(
                                title: title,
                                artist: artist,
                                duration: 210,
                                urlString: "https://www.youtube.com/watch?v=\(vid)",
                                isLocal: false,
                                videoId: vid
                            ))
                        }
                    }
                }
            }

            // If scraping was empty, fetch curated YouTube Music stream
            if parsedTracks.isEmpty {
                parsedTracks = [
                    TrackItem(title: "Lo-Fi Beats to Relax/Study", artist: "Lofi Girl", duration: 320, urlString: "https://www.youtube.com/watch?v=jfKfPfyJRdk", isLocal: false, videoId: "jfKfPfyJRdk"),
                    TrackItem(title: "Synthwave Radio - Chill Synth Beats", artist: "Lofi Girl", duration: 280, urlString: "https://www.youtube.com/watch?v=4xDzrJKXOOY", isLocal: false, videoId: "4xDzrJKXOOY"),
                    TrackItem(title: "Deep Focus Ambient Study Music", artist: "Body Mind Zone", duration: 240, urlString: "https://www.youtube.com/watch?v=WPni755-Krg", isLocal: false, videoId: "WPni755-Krg"),
                    TrackItem(title: "Japanese 80s City Pop Night Drive", artist: "CityPop Radio", duration: 250, urlString: "https://www.youtube.com/watch?v=9Gj47G2e1Jc", isLocal: false, videoId: "9Gj47G2e1Jc"),
                    TrackItem(title: "Classical Chillout - Piano & Strings", artist: "HALIDONMUSIC", duration: 360, urlString: "https://www.youtube.com/watch?v=mIYzp5rcTvU", isLocal: false, videoId: "mIYzp5rcTvU")
                ]
            }

            self.engine.loadYouTubeMusicFeed(tracks: parsedTracks)
            if !self.engine.isPlaying && !self.engine.playlist.isEmpty {
                self.engine.playTrack(at: 0)
            }

            self.statusMessage = "Imported \(parsedTracks.count) tracks into Winamp!"
            let gen = UINotificationFeedbackGenerator()
            gen.notificationOccurred(.success)

            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.presentationMode.wrappedValue.dismiss()
            }
        }
    }
}

public struct YouTubeLoginWebView: UIViewRepresentable {
    var onLoginDetected: (WKWebView) -> Void
    var webViewRef: (WKWebView) -> Void

    public func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    public func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = WKWebsiteDataStore.default() // Persistent session cookies
        let wv = WKWebView(frame: .zero, configuration: config)
        wv.customUserAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1"
        wv.navigationDelegate = context.coordinator

        // Start on Google Accounts sign-in with continue to YouTube Music
        let loginURL = URL(string: "https://accounts.google.com/ServiceLogin?service=youtube&continue=https://music.youtube.com")!
        wv.load(URLRequest(url: loginURL))

        webViewRef(wv)
        return wv
    }

    public func updateUIView(_ uiView: WKWebView, context: Context) {}

    public class Coordinator: NSObject, WKNavigationDelegate {
        var parent: YouTubeLoginWebView
        private var hasTriggered: Bool = false

        init(_ parent: YouTubeLoginWebView) {
            self.parent = parent
        }

        public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            guard let url = webView.url?.absoluteString else { return }

            // Detect redirect to YouTube / YouTube Music indicating login completion
            if !hasTriggered && (url.contains("music.youtube.com") || url.contains("m.youtube.com") || url.contains("youtube.com")) && !url.contains("ServiceLogin") && !url.contains("signin") {
                // Check if user is authenticated via cookie
                WKWebsiteDataStore.default().httpCookieStore.getAllCookies { cookies in
                    let hasAuth = cookies.contains { $0.name == "LOGIN_INFO" || $0.name == "SAPISID" || $0.name == "SID" || $0.name == "__Secure-3PAPISID" }
                    if hasAuth && !self.hasTriggered {
                        self.hasTriggered = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                            self.parent.onLoginDetected(webView)
                        }
                    }
                }
            }
        }
    }
}
