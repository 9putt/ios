import SwiftUI
import WebKit

public struct WebPlayerView: UIViewRepresentable {
    @ObservedObject var engine = WinampPlayerEngine.shared

    public init(engine: WinampPlayerEngine = .shared) {
        self.engine = engine
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    public func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.allowsPictureInPictureMediaPlayback = false
        config.mediaTypesRequiringUserActionForPlayback = []
        config.websiteDataStore = WKWebsiteDataStore.default()

        let prefs = WKWebpagePreferences()
        prefs.allowsContentJavaScript = true
        config.defaultWebpagePreferences = prefs

        let contentController = WKUserContentController()
        contentController.add(context.coordinator, name: "winampBridge")

        // Mobile YouTube script: blocks fullscreens, hides ads/chrome, intercepts audio streams
        let scriptSource = """
        // 1. Permanently block native iOS fullscreen modal takeovers
        try {
            HTMLVideoElement.prototype.webkitEnterFullscreen = function() {};
            HTMLVideoElement.prototype.webkitRequestFullscreen = function() {};
            HTMLVideoElement.prototype.requestFullscreen = function() {};
            HTMLVideoElement.prototype.enterFullscreen = function() {};
        } catch(e) {}

        // 2. CSS UI cleaner (Ad block & remove mobile web chrome)
        (function() {
            var style = document.createElement('style');
            style.type = 'text/css';
            style.innerHTML = `
                #header-bar, #masthead-ad, ytm-mobile-topbar-renderer,
                ytm-pivot-bar-renderer, ytm-item-section-renderer,
                ytm-single-column-browse-results-renderer,
                .ytm-watch-metadata-app-promo-renderer,
                ytm-bottom-sheet-overlay-renderer, #global-loader,
                .fullscreen-icon, .ytp-fullscreen-button,
                .ytp-chrome-top, .ytp-chrome-bottom,
                ytm-watch-metadata-endpoint, ytm-comment-section-renderer,
                ytm-related-chip-cloud-renderer, #player-ads,
                ytd-merch-shelf-renderer, ytm-merch-shelf-renderer {
                    display: none !important;
                }
                html, body {
                    background: #000 !important;
                    overflow: hidden !important;
                    margin: 0 !important;
                    padding: 0 !important;
                    width: 100% !important;
                    height: 100% !important;
                }
                .player-container, #player-control-container, .html5-video-player {
                    position: fixed !important;
                    top: 0 !important;
                    left: 0 !important;
                    width: 100% !important;
                    height: 100% !important;
                    z-index: 9999 !important;
                }
                video {
                    object-fit: contain !important;
                    width: 100% !important;
                    height: 100% !important;
                }
            `;
            if (document.head) {
                document.head.appendChild(style);
            } else {
                document.addEventListener('DOMContentLoaded', function() {
                    document.head.appendChild(style);
                });
            }
        })();

        // 3. Audio stream interception via fetch & XMLHttpRequest
        (function() {
            function inspectURL(u) {
                if (!u || typeof u !== 'string') return;
                if (u.indexOf('videoplayback') !== -1) {
                    if (u.indexOf('itag=140') !== -1 || u.indexOf('mime=audio%2Fmp4') !== -1 || u.indexOf('mime=audio') !== -1) {
                        var cleanUrl = u.replace(/&range=[^&]+/, '');
                        try {
                            window.webkit.messageHandlers.winampBridge.postMessage({
                                action: 'capturedAudioStream',
                                url: cleanUrl
                            });
                        } catch(e) {}
                    }
                }
            }

            var origFetch = window.fetch;
            window.fetch = function() {
                var arg = arguments[0];
                if (arg) {
                    if (arg instanceof Request) { inspectURL(arg.url); }
                    else if (typeof arg === 'string') { inspectURL(arg); }
                }
                var p = origFetch.apply(this, arguments);
                p.then(function(res) {
                    try {
                        var u = (arg instanceof Request) ? arg.url : String(arg);
                        if (u.indexOf('/youtubei/v1/player') !== -1) {
                            res.clone().json().then(function(json) {
                                window.webkit.messageHandlers.winampBridge.postMessage({
                                    action: 'capturedPlayerResponse',
                                    data: json
                                });
                            }).catch(function(){});
                        }
                    } catch(e) {}
                }).catch(function(){});
                return p;
            };

            var origOpen = XMLHttpRequest.prototype.open;
            XMLHttpRequest.prototype.open = function(method, url) {
                inspectURL(url);
                return origOpen.apply(this, arguments);
            };
        })();

        // 4. Playback loop, promo dismissal, and auto-skip ads
        (function() {
            var hasNotifiedPlaying = false;
            setInterval(function() {
                var v = document.querySelector('video');
                if (v) {
                    v.playsInline = true;
                    v.setAttribute('playsinline', '1');
                    v.setAttribute('webkit-playsinline', '1');

                    if (v.paused && !window._userPaused) {
                        v.play().catch(function(){});
                    }

                    var cur = v.currentTime || 0;
                    var dur = v.duration || 0;
                    var isPlaying = !v.paused && !v.ended;

                    if (isPlaying && !hasNotifiedPlaying) {
                        hasNotifiedPlaying = true;
                        window.webkit.messageHandlers.winampBridge.postMessage({ action: 'playbackStarted' });
                    }

                    window.webkit.messageHandlers.winampBridge.postMessage({
                        action: 'timeUpdate',
                        currentTime: cur,
                        duration: isFinite(dur) ? dur : 0,
                        isPlaying: isPlaying
                    });

                    if (v.ended) {
                        window.webkit.messageHandlers.winampBridge.postMessage({ action: 'trackEnded' });
                    }
                }

                // Auto-skip ads
                var skipBtn = document.querySelector('.ytp-ad-skip-button, .ytp-ad-skip-button-modern, .videoAdUiSkipButton');
                if (skipBtn) { skipBtn.click(); }
                // Dismiss promo popups
                var dismissBtn = document.querySelector('button[aria-label="No thanks"], button[aria-label="Dismiss"], .ytSpecButtonShape--text');
                if (dismissBtn) { dismissBtn.click(); }
            }, 300);
        })();
        """

        let userScript = WKUserScript(source: scriptSource, injectionTime: .atDocumentStart, forMainFrameOnly: false)
        contentController.addUserScript(userScript)
        config.userContentController = contentController

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.customUserAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile Safari/604.1"
        webView.isOpaque = false
        webView.backgroundColor = .black
        webView.scrollView.isScrollEnabled = false
        webView.navigationDelegate = context.coordinator

        // Assign engine reference
        engine.webView = webView

        return webView
    }

    public func updateUIView(_ uiView: WKWebView, context: Context) {}

    public static func loadVideo(webView: WKWebView?, videoId: String) {
        guard let wv = webView else { return }
        let urlStr = "https://m.youtube.com/watch?v=\(videoId)&persist_app=1&app=m"
        if let url = URL(string: urlStr) {
            var request = URLRequest(url: url)
            request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile Safari/604.1", forHTTPHeaderField: "User-Agent")
            wv.load(request)
            print("[WebPlayerView] Navigating to \(urlStr)")
        }
    }

    public class Coordinator: NSObject, WKScriptMessageHandler, WKNavigationDelegate {
        var parent: WebPlayerView
        private var lastCapturedStream: String?

        init(_ parent: WebPlayerView) {
            self.parent = parent
        }

        public func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard let dict = message.body as? [String: Any],
                  let action = dict["action"] as? String else { return }

            DispatchQueue.main.async {
                switch action {
                case "playbackStarted":
                    self.parent.engine.isPlaying = true

                case "timeUpdate":
                    let isPlaying = dict["isPlaying"] as? Bool ?? false
                    let cur = dict["currentTime"] as? Double ?? 0
                    let dur = dict["duration"] as? Double ?? 0

                    if !NativeAudioEngine.shared.isPlaying {
                        self.parent.engine.currentTime = cur
                        if dur > 0 {
                            self.parent.engine.duration = dur
                        }
                        self.parent.engine.isPlaying = isPlaying
                    }

                case "trackEnded":
                    self.parent.engine.nextTrack()

                case "capturedAudioStream":
                    if let urlStr = dict["url"] as? String,
                       let streamURL = URL(string: urlStr),
                       self.lastCapturedStream != urlStr {
                        self.lastCapturedStream = urlStr
                        print("[WebPlayerView] 🎵 Intercepted authorized audio stream: \(urlStr.prefix(60))...")

                        // 1. Play directly via AVPlayer
                        NativeAudioEngine.shared.playStreamURL(streamURL)

                        // 2. Mute web video to prevent duplicate audio
                        self.parent.engine.webView?.evaluateJavaScript("""
                            var v = document.querySelector('video');
                            if (v) { v.muted = true; }
                        """, completionHandler: nil)

                        // 3. Cache M4A file in background for 10-band hardware EQ & balance transition
                        let vid = self.parent.engine.currentTrack?.videoId ?? "current"
                        Task {
                            if let localFile = await InnerTubeExtractor.shared.downloadAudio(videoId: vid, streamURL: streamURL) {
                                await MainActor.run {
                                    let cur = NativeAudioEngine.shared.currentAudioPosition
                                    NativeAudioEngine.shared.transitionToLocalFile(localFile, atTime: cur)
                                }
                            }
                        }
                    }

                case "capturedPlayerResponse":
                    if let data = dict["data"] as? [String: Any],
                       let streaming = data["streamingData"] as? [String: Any],
                       let adaptive = streaming["adaptiveFormats"] as? [[String: Any]] {
                        for fmt in adaptive {
                            if let itag = fmt["itag"] as? Int, itag == 140,
                               let urlStr = fmt["url"] as? String,
                               let streamURL = URL(string: urlStr),
                               self.lastCapturedStream != urlStr {
                                self.lastCapturedStream = urlStr
                                print("[WebPlayerView] 🎵 Captured itag 140 stream from playerResponse")
                                NativeAudioEngine.shared.playStreamURL(streamURL)
                                self.parent.engine.webView?.evaluateJavaScript("var v = document.querySelector('video'); if (v) v.muted = true;", completionHandler: nil)
                                break
                            }
                        }
                    }

                default:
                    break
                }
            }
        }

        public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            print("[WebPlayerView] Page navigation completed")
        }
    }
}
