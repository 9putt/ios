import SwiftUI
import WebKit

public struct YouTubeLoginSheet: View {
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject var engine = WinampPlayerEngine.shared
    @State private var webView: WKWebView?
    @State private var isExtracting: Bool = false
    @State private var statusMessage: String = "Sign in with Google. Session is saved to Keychain so you never have to sign in again after reinstalling."

    public var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Status Header
                HStack(spacing: 8) {
                    if isExtracting {
                        ProgressView()
                            .tint(.green)
                    } else {
                        Image(systemName: "lock.shield.fill")
                            .foregroundColor(Color(red: 0.0, green: 1.0, blue: 0.35))
                    }
                    Text(statusMessage)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(2)
                    Spacer()
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Color(red: 0.10, green: 0.12, blue: 0.16))

                // Direct Modern Google/YouTube Sign-In WebView
                YouTubeLoginWebView(
                    onLoginDetected: { wv in
                        extractFeedAndDismiss(wv: wv)
                    },
                    webViewRef: { v in
                        self.webView = v
                    }
                )
                .edgesIgnoringSafeArea(.bottom)

                // Bottom Manual Sync Button
                Button(action: {
                    if let wv = webView {
                        extractFeedAndDismiss(wv: wv)
                    }
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 13, weight: .bold))
                        Text(isExtracting ? "Importing Music Tracks..." : "Import My YouTube Feed Now")
                            .font(.system(size: 13, weight: .bold))
                    }
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .background(Color(red: 0.0, green: 1.0, blue: 0.35))
                    .cornerRadius(6)
                }
                .disabled(isExtracting)
                .padding(8)
                .background(Color(red: 0.06, green: 0.07, blue: 0.09))
            }
            .navigationTitle("Sign In to YouTube")
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

        // Persist session to iOS Keychain immediately
        KeychainCookieManager.shared.persistCookies(from: wv.configuration.websiteDataStore.httpCookieStore)

        let script = #"""
        (function() {
            let results = [];
            let nodes = document.querySelectorAll('ytm-compact-video-renderer, ytm-video-with-context-renderer, ytd-rich-item-renderer, ytd-compact-video-renderer');
            nodes.forEach((n, idx) => {
                if (idx > 50) return;
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
                        let dur = dict["duration"] as? Double ?? 210.0

                        if !vid.isEmpty && YouTubeSearchManager.isSingleSong(title: title, duration: dur) {
                            parsedTracks.append(TrackItem(
                                title: title,
                                artist: artist,
                                duration: dur,
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
                if !self.engine.playlist.isEmpty {
                    self.engine.playTrack(at: 0)
                }
                self.statusMessage = "Successfully imported \(parsedTracks.count) tracks from YouTube!"
                let gen = UINotificationFeedbackGenerator()
                gen.notificationOccurred(.success)
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    self.presentationMode.wrappedValue.dismiss()
                }
            } else {
                YouTubeSearchManager.shared.search(query: "เพลงใหม่มาแรง", filterCompilations: true) { fallbackResults in
                    self.isExtracting = false
                    if !fallbackResults.isEmpty {
                        self.engine.loadYouTubeMusicFeed(tracks: fallbackResults)
                        self.engine.playTrack(at: 0)
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
        config.websiteDataStore = WKWebsiteDataStore.default()

        let prefs = WKWebpagePreferences()
        prefs.allowsContentJavaScript = true
        config.defaultWebpagePreferences = prefs

        let wv = WKWebView(frame: .zero, configuration: config)
        // Standard iOS Safari Mobile User-Agent to render modern Safari Google Sign-In & allow Saved Passwords AutoFill
        wv.customUserAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 17_5 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.5 Mobile/15E148 Safari/604.1"
        wv.navigationDelegate = context.coordinator

        // Restore any Keychain-persisted cookies first
        KeychainCookieManager.shared.restoreCookies(to: config.websiteDataStore.httpCookieStore) {
            let startURL = URL(string: "https://accounts.google.com/ServiceLogin?service=youtube&continue=https://m.youtube.com")!
            wv.load(URLRequest(url: startURL))
        }

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

            // Auto-persist cookies to iOS Keychain
            KeychainCookieManager.shared.persistCookies(from: webView.configuration.websiteDataStore.httpCookieStore)

            // When user finishes login and reaches mobile YouTube
            if !hasTriggered && (url.contains("m.youtube.com") || url.contains("youtube.com")) && !url.contains("signin") && !url.contains("ServiceLogin") {
                WKWebsiteDataStore.default().httpCookieStore.getAllCookies { cookies in
                    let hasAuth = cookies.contains { $0.name == "LOGIN_INFO" || $0.name == "SAPISID" || $0.name == "SID" }
                    if hasAuth && !self.hasTriggered {
                        self.hasTriggered = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                            self.parent.onLoginDetected(webView)
                        }
                    }
                }
            }
        }
    }
}
