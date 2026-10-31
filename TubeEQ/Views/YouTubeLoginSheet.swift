import SwiftUI
import WebKit

public struct YouTubeLoginSheet: View {
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject var engine = WinampPlayerEngine.shared
    @State private var webView: WKWebView?
    @State private var isExtracting: Bool = false
    @State private var statusMessage: String = "ลงชื่อเข้าใช้ Google เพื่อซิงก์ฟีดเพลงโปรไฟล์ของคุณ (บันทึกเซสชันลง Keychain อัตโนมัติ)"
    @State private var canGoBack = false
    @State private var canGoForward = false

    public var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Modern SSL Security & Navigation Bar
                HStack(spacing: 10) {
                    HStack(spacing: 6) {
                        Button(action: { webView?.goBack() }) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(canGoBack ? .white : .gray.opacity(0.4))
                        }
                        .disabled(!canGoBack)

                        Button(action: { webView?.goForward() }) {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(canGoForward ? .white : .gray.opacity(0.4))
                        }
                        .disabled(!canGoForward)

                        Button(action: { webView?.reload() }) {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 12))
                                .foregroundColor(.white.opacity(0.8))
                        }
                    }

                    // Security URL Capsule
                    HStack(spacing: 5) {
                        Image(systemName: "lock.shield.fill")
                            .font(.system(size: 11))
                            .foregroundColor(Color.green)
                        Text("accounts.google.com / youtube.com")
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundColor(.white.opacity(0.85))
                            .lineLimit(1)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.white.opacity(0.08))
                    .cornerRadius(6)

                    Spacer()

                    if isExtracting {
                        ProgressView().tint(.green).scaleEffect(0.7)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(red: 0.08, green: 0.09, blue: 0.12))

                // Modern WebKit View with Safari Google Sign-In Compatibility
                ModernYouTubeWebView(
                    onLoginDetected: { wv in
                        extractFeedAndDismiss(wv: wv)
                    },
                    webViewRef: { v in
                        self.webView = v
                    },
                    canGoBack: $canGoBack,
                    canGoForward: $canGoForward
                )
                .edgesIgnoringSafeArea(.bottom)

                // Bottom Action & Sync Bar
                VStack(spacing: 8) {
                    Text(statusMessage)
                        .font(.system(size: 11))
                        .foregroundColor(.gray)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)

                    Button(action: {
                        if let wv = webView {
                            extractFeedAndDismiss(wv: wv)
                        }
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 14, weight: .bold))
                            Text(isExtracting ? "กำลังดึงฟีดเพลงส่วนตัวของคุณ..." : "⚡ นำเข้าฟีดเพลงของฉันเดี๋ยวนี้ (Sync Feed)")
                                .font(.system(size: 14, weight: .bold))
                        }
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(LinearGradient(colors: [Color.green, Color(red: 0.0, green: 0.9, blue: 0.7)], startPoint: .leading, endPoint: .trailing))
                        .cornerRadius(8)
                        .shadow(color: Color.green.opacity(0.3), radius: 5)
                    }
                    .disabled(isExtracting)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color(red: 0.07, green: 0.08, blue: 0.10))
            }
            .navigationTitle("ลงชื่อเข้าใช้ YouTube")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("ปิด") {
                        presentationMode.wrappedValue.dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
        }
    }

    private func extractFeedAndDismiss(wv: WKWebView) {
        guard !isExtracting else { return }
        isExtracting = true
        statusMessage = "กำลังคัดกรองฟีดเพลงจากโปรไฟล์ YouTube ของคุณ..."

        // Persist session to iOS Keychain immediately
        KeychainCookieManager.shared.persistCookies(from: wv.configuration.websiteDataStore.httpCookieStore)

        let script = #"""
        (function() {
            let results = [];
            let nodes = document.querySelectorAll('ytm-compact-video-renderer, ytm-video-with-context-renderer, ytd-rich-item-renderer, ytd-compact-video-renderer, ytd-video-renderer');
            nodes.forEach((n, idx) => {
                if (idx > 60) return;
                let a = n.querySelector('a[href*="/watch?v="], a[href*="watch?v="]');
                let titleEl = n.querySelector('.compact-media-item-headline, .media-item-headline, #video-title, .title');
                let bylineEl = n.querySelector('.compact-media-item-byline, .media-item-byline, #subtitle, .subtitle');
                let title = titleEl ? titleEl.textContent.trim() : '';
                let byline = bylineEl ? bylineEl.textContent.trim() : 'YouTube';
                if (a && title) {
                    let m = a.href.match(/v=([a-zA-Z0-9_-]{11})/);
                    if (m && m[1]) {
                        results.push({ videoId: m[1], title: title, artist: byline, duration: 240 });
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
                        let dur = dict["duration"] as? Double ?? 240.0

                        // STRICT FILTER: Keep genuine music, ALLOW long compilation mixes as requested!
                        if !vid.isEmpty && YouTubeSearchManager.isFeedMusic(title: title, duration: dur, channel: artist) {
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
                self.statusMessage = "ดึงฟีดสำเร็จ \(parsedTracks.count) เพลงเรียบร้อยแล้ว!"
                let gen = UINotificationFeedbackGenerator()
                gen.notificationOccurred(.success)
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    self.presentationMode.wrappedValue.dismiss()
                }
            } else {
                // If direct DOM scrape had no videos yet, use InnerTube authenticated browse
                YouTubeSearchManager.shared.fetchUserPersonalizedFeed { feedResults in
                    self.isExtracting = false
                    if !feedResults.isEmpty {
                        self.engine.loadYouTubeMusicFeed(tracks: feedResults)
                        self.engine.playTrack(at: 0)
                    }
                    self.presentationMode.wrappedValue.dismiss()
                }
            }
        }
    }
}

public struct ModernYouTubeWebView: UIViewRepresentable {
    var onLoginDetected: (WKWebView) -> Void
    var webViewRef: (WKWebView) -> Void
    @Binding var canGoBack: Bool
    @Binding var canGoForward: Bool

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
        config.preferences.javaScriptCanOpenWindowsAutomatically = true

        let wv = WKWebView(frame: .zero, configuration: config)
        // Standard clean Safari iOS 17.5 User-Agent (Prevents Google's "This browser or app may not be secure" error)
        wv.customUserAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 17_5 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.5 Mobile/15E148 Safari/604.1"
        wv.navigationDelegate = context.coordinator
        wv.allowsBackForwardNavigationGestures = true

        // Restore any Keychain-persisted cookies first, then navigate through trusted YouTube signin trampoline
        KeychainCookieManager.shared.restoreCookies(to: config.websiteDataStore.httpCookieStore) {
            let startURL = URL(string: "https://www.youtube.com/signin?hl=th&feature=passive&next=%2F")!
            wv.load(URLRequest(url: startURL))
        }

        webViewRef(wv)
        return wv
    }

    public func updateUIView(_ uiView: WKWebView, context: Context) {}

    public class Coordinator: NSObject, WKNavigationDelegate {
        var parent: ModernYouTubeWebView
        private var hasTriggered: Bool = false

        init(_ parent: ModernYouTubeWebView) {
            self.parent = parent
        }

        public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            parent.canGoBack = webView.canGoBack
            parent.canGoForward = webView.canGoForward

            guard let url = webView.url?.absoluteString else { return }

            // Auto-persist cookies to iOS Keychain
            KeychainCookieManager.shared.persistCookies(from: webView.configuration.websiteDataStore.httpCookieStore)

            // When user finishes login and reaches mobile YouTube
            if !hasTriggered && (url.contains("m.youtube.com") || url.contains("youtube.com")) && !url.contains("signin") && !url.contains("ServiceLogin") {
                webView.configuration.websiteDataStore.httpCookieStore.getAllCookies { cookies in
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
