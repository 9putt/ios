import SwiftUI
import WebKit

public struct WebPlayerView: UIViewRepresentable {
    @ObservedObject var engine = WinampPlayerEngine.shared

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

        // Block all native iOS fullscreen calls permanently
        let blockScript = """
        try {
            HTMLVideoElement.prototype.webkitEnterFullscreen = function() {};
            HTMLVideoElement.prototype.webkitRequestFullscreen = function() {};
            HTMLVideoElement.prototype.requestFullscreen = function() {};
            HTMLVideoElement.prototype.enterFullscreen = function() {};
        } catch(e) {}
        """
        let userScript = WKUserScript(source: blockScript, injectionTime: .atDocumentStart, forMainFrameOnly: false)
        contentController.addUserScript(userScript)
        config.userContentController = contentController

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.isOpaque = false
        webView.backgroundColor = .black
        webView.scrollView.isScrollEnabled = false
        webView.navigationDelegate = context.coordinator

        // Store reference in engine
        engine.webView = webView

        // Load initial player HTML
        let initialVid = engine.currentTrack?.videoId ?? "k4x8vMvVq68"
        loadEmbeddedPlayer(webView: webView, videoId: initialVid)

        return webView
    }

    public func updateUIView(_ uiView: WKWebView, context: Context) {}

    public static func loadVideo(webView: WKWebView?, videoId: String) {
        guard let wv = webView else { return }
        let js = "if(window.player && window.player.loadVideoById){ window.player.loadVideoById('\(videoId)', 0); window.player.playVideo(); } else { window.location.replace('https://www.youtube-nocookie.com/embed/\(videoId)?autoplay=1&playsinline=1&controls=0&fs=0&enablejsapi=1'); }"
        wv.evaluateJavaScript(js, completionHandler: nil)
    }

    private func loadEmbeddedPlayer(webView: WKWebView, videoId: String) {
        let html = """
        <!DOCTYPE html>
        <html>
        <head>
        <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
        <style>
        * { margin:0; padding:0; background:#000; overflow:hidden; }
        html, body { width:100%; height:100%; background:#000; }
        #player { width:100%; height:100%; position:fixed; top:0; left:0; pointer-events:none; }
        </style>
        </head>
        <body>
        <div id="player"></div>
        <script src="https://www.youtube.com/iframe_api"></script>
        <script>
        try {
            HTMLVideoElement.prototype.webkitEnterFullscreen = function() {};
            HTMLVideoElement.prototype.webkitRequestFullscreen = function() {};
        } catch(e) {}

        var player;
        function onYouTubeIframeAPIReady() {
            player = new YT.Player('player', {
                height: '100%',
                width: '100%',
                videoId: '\(videoId)',
                playerVars: {
                    'autoplay': 1,
                    'playsinline': 1,
                    'controls': 0,
                    'disablekb': 1,
                    'fs': 0,
                    'rel': 0,
                    'modestbranding': 1,
                    'iv_load_policy': 3
                },
                events: {
                    'onReady': onPlayerReady,
                    'onStateChange': onPlayerStateChange
                }
            });
            window.player = player;
        }

        function onPlayerReady(event) {
            event.target.playVideo();
            syncTime();
        }

        function onPlayerStateChange(event) {
            if (event.data === 0) {
                window.webkit.messageHandlers.winampBridge.postMessage({ action: 'trackEnded' });
            }
        }

        function syncTime() {
            setInterval(function() {
                if (window.player && typeof window.player.getCurrentTime === 'function') {
                    var cur = window.player.getCurrentTime() || 0;
                    var dur = window.player.getDuration() || 0;
                    var state = window.player.getPlayerState();
                    window.webkit.messageHandlers.winampBridge.postMessage({
                        action: 'timeUpdate',
                        currentTime: cur,
                        duration: dur,
                        isPlaying: (state === 1)
                    });
                }
            }, 250);
        }
        </script>
        </body>
        </html>
        """
        webView.loadHTMLString(html, baseURL: URL(string: "https://www.youtube-nocookie.com"))
    }

    public class Coordinator: NSObject, WKScriptMessageHandler, WKNavigationDelegate {
        var parent: WebPlayerView
        init(_ parent: WebPlayerView) {
            self.parent = parent
        }

        public func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard let dict = message.body as? [String: Any],
                  let action = dict["action"] as? String else { return }

            DispatchQueue.main.async {
                let engine = self.parent.engine
                switch action {
                case "timeUpdate":
                    // Only use web player time if NativeAudioEngine is not actively playing
                    if !NativeAudioEngine.shared.isPlaying {
                        if let cur = dict["currentTime"] as? Double, cur > 0 {
                            engine.currentTime = cur
                        }
                        if let dur = dict["duration"] as? Double, dur > 0 {
                            engine.duration = dur
                        }
                        if let playing = dict["isPlaying"] as? Bool {
                            engine.isPlaying = playing
                        }
                    }

                case "trackEnded":
                    if !NativeAudioEngine.shared.isPlaying {
                        engine.nextTrack()
                    }

                default:
                    break
                }
            }
        }
    }
}
