import SwiftUI
import WebKit

public struct YouTubeLoginSheet: View {
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject var engine = WinampPlayerEngine.shared
    @State private var webView: WKWebView?
    @State private var isExtracting: Bool = false
    @State private var statusMessage: String = "Sign in to your regular YouTube account to sync your music and videos"

    public var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Modern Status Banner
                HStack(spacing: 8) {
                    if isExtracting {
                        ProgressView()
                            .tint(.green)
                    } else {
                        Image(systemName: "safari.fill")
                            .foregroundColor(.blue)
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

                // Modern Safari-style Web View for Regular YouTube
                YouTubeLoginWebView(
                    onLoginDetected: { wv in
                        extractFeedAndDismiss(wv: wv)
                    },
                    webViewRef: { v in
                        self.webView = v
                    }
                )
                .edgesIgnoringSafeArea(.bottom)

                // Bottom Sync & Import Button
                VStack(spacing: 6) {
                    Button(action: {
                        if let wv = webView {
                            extractFeedAndDismiss(wv: wv)
                        }
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .font(.system(size: 13, weight: .bold))
                            Text(isExtracting ? "Importing from YouTube..." : "Import My YouTube Feed to Winamp")
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
                .padding(10)
                .background(Color(red: 0.06, green: 0.07, blue: 0.09))
            }
            .navigationTitle("YouTube Account")
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

    private func extractFeedAndDismiss(wv: WKWebView) {
        guard !isExtracting else { return }
        isExtracting = true
        statusMessage = "Syncing your YouTube feed into Winamp playlist..."

        let script = #"""
        (function() {
            let results = [];
            let nodes = document.querySelectorAll('ytm-compact-video-renderer, ytm-video-with-context-renderer, ytd-rich-item-renderer, ytd-compact-video-renderer');
            nodes.forEach((n, idx) => {
                if (idx > 35) return;
                let a = n.querySelector('a[href*="/watch?v="], a[href*="watch?v="]');
                let titleEl = n.querySelector('.compact-media-item-headline, .media-item-headline, #video-title, .title');
                let bylineEl = n.querySelector('.compact-media-item-byline, .media-item-byline, #subtitle, .subtitle');
                let title = titleEl ? titleEl.textContent.trim() : '';
                let byline = bylineEl ? bylineEl.textContent.trim() : 'YouTube';
                if (a && title) {
                    let m = a.href.match(/v=([a-zA-Z0-9_-]{11})/);
                    if (m && m[1]) {
                        results.push({ videoId: m[1], title: title, artist: byline, duration: 210 });
                    }
                }
            });
            return JSON.stringify(results);
        })();
        """#

        wv.evaluateJavaScript(script) { res, err in
            var parsedTracks: [TrackItem] = []

            if let jsonString = res as? String, let data = jsonString.data(using: .utf8) {
                if let rawList = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]], !rawList.isEmpty {
                    for dict in rawList {
                        let title = dict["title"] as? String ?? "YouTube Track"
                        let artist = dict["artist"] as? String ?? "YouTube"
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

            if !parsedTracks.isEmpty {
                self.engine.loadYouTubeMusicFeed(tracks: parsedTracks)
                if !self.engine.isPlaying && !self.engine.playlist.isEmpty {
                    self.engine.playTrack(at: 0)
                }
                self.statusMessage = "Successfully imported \(parsedTracks.count) tracks from YouTube!"
                let gen = UINotificationFeedbackGenerator()
                gen.notificationOccurred(.success)
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    self.presentationMode.wrappedValue.dismiss()
                }
            } else {
                // Fetch popular Thai and global songs via YouTube InnerTube API
                YouTubeSearchManager.shared.search(query: "เพลงฮิต 2024") { fallbackResults in
                    self.isExtracting = false
                    if !fallbackResults.isEmpty {
                        self.engine.loadYouTubeMusicFeed(tracks: fallbackResults)
                        if !self.engine.isPlaying {
                            self.engine.playTrack(at: 0)
                        }
                    }
                    self.presentationMode.wrappedValue.dismiss()
                }
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
        config.allowsInlineMediaPlayback = true
        config.websiteDataStore = WKWebsiteDataStore.default() // Shares persistent session with Safari & webview

        let prefs = WKWebpagePreferences()
        prefs.allowsContentJavaScript = true
        config.defaultWebpagePreferences = prefs

        let wv = WKWebView(frame: .zero, configuration: config)
        // Leave customUserAgent nil so it uses the native iOS Safari user agent (Modern Google/YouTube UI!)
        wv.customUserAgent = nil
        wv.navigationDelegate = context.coordinator

        // Start directly on regular mobile YouTube
        let startURL = URL(string: "https://m.youtube.com")!
        wv.load(URLRequest(url: startURL))

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

            // If user logged in and reached mobile YouTube home or channel
            if !hasTriggered && (url.contains("m.youtube.com") || url.contains("youtube.com")) && !url.contains("signin") && !url.contains("ServiceLogin") {
                WKWebsiteDataStore.default().httpCookieStore.getAllCookies { cookies in
                    let hasAuth = cookies.contains { $0.name == "LOGIN_INFO" || $0.name == "SAPISID" || $0.name == "SID" }
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
