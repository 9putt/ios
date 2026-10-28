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

        // Injected Script: Fullscreen Blocker + Playsinline Enforcer + YouTube Controls
        // NOTE: All audio DSP (Volume, EQ, Balance) is handled by NativeAudioEngine.
        // WebView is ONLY used for YouTube video loading and visual display.
        // iOS WebKit blocks video.volume (always 1.0) and AudioContext.createMediaElementSource
        // fails due to CORS, making WebAudio DSP impossible for cross-origin YouTube content.
        let scriptSource = """
        // 1. Permanently neuter native fullscreen calls to prevent iOS native video player popup
        try {
            HTMLVideoElement.prototype.webkitEnterFullscreen = function() {};
            HTMLVideoElement.prototype.webkitRequestFullscreen = function() {};
            HTMLVideoElement.prototype.requestFullscreen = function() {};
            HTMLVideoElement.prototype.enterFullscreen = function() {};
        } catch(e) {}

        function lockVideoInline(v) {
            if (!v) return;
            v.setAttribute('playsinline', 'true');
            v.setAttribute('webkit-playsinline', 'true');
            v.setAttribute('x5-playsinline', 'true');
            v.playsInline = true;
            v.webkitPlaysInline = true;
            v.controls = false;
            v.removeAttribute('controls');
        }

        const domObserver = new MutationObserver(function() {
            document.querySelectorAll('video').forEach(lockVideoInline);
        });
        domObserver.observe(document.documentElement, { childList: true, subtree: true });

        // 2. Prevent background pause on visibility or tab blur
        try {
            Object.defineProperty(document, 'hidden', { value: false, writable: false });
            Object.defineProperty(document, 'visibilityState', { value: 'visible', writable: false });
            document.addEventListener('visibilitychange', function(e) { e.stopImmediatePropagation(); }, true);
        } catch(e) {}
        window.addEventListener('blur', function(e) { e.stopImmediatePropagation(); }, true);

        // 3. Hide all YouTube UI chrome & iOS media controls
        let style = document.createElement('style');
        style.textContent = `
            html, body {
                background: #000000 !important;
                margin: 0 !important;
                padding: 0 !important;
                overflow: hidden !important;
            }
            #masthead, ytd-masthead, #header, ytm-mobile-topbar-renderer,
            #related, #comments, #secondary, ytd-watch-next-secondary-results-renderer,
            .ytp-chrome-top, .ytp-chrome-bottom, .ytp-watermark, .ytp-pause-overlay,
            .ytp-endscreen-content, .ytp-ce-element, #player-control-overlay,
            .ytp-spinner, ytm-engagement-panel-section-list-renderer {
                display: none !important;
            }
            video::-webkit-media-controls,
            video::-webkit-media-controls-enclosure,
            *::-webkit-media-controls-panel,
            *::-webkit-media-controls-play-button,
            *::-webkit-media-controls-start-playback-button {
                display: none !important;
            }
            #player, #movie_player, .html5-video-player, video {
                position: fixed !important;
                top: 0 !important;
                left: 0 !important;
                width: 100vw !important;
                height: 100vh !important;
                object-fit: cover !important;
                z-index: 99999 !important;
            }
        `;
        document.head.appendChild(style);

        // 4. Winamp Player Controller (video control only — NO audio DSP)
        window.__winamp = {
            isManualPaused: false,
            currentVideoId: '',
            hasTriggeredOutro: false,

            loadVideo: function(id) {
                this.isManualPaused = false;
                this.currentVideoId = id;
                this.hasTriggeredOutro = false;

                let p = document.getElementById('movie_player') || document.querySelector('.html5-video-player');
                if (p && typeof p.loadVideoById === 'function') {
                    p.loadVideoById({ videoId: id, startSeconds: 0 });
                    if (typeof p.unMute === 'function') p.unMute();
                    if (typeof p.playVideo === 'function') p.playVideo();
                    this.ensurePlay();
                    return;
                }

                window.location.replace('https://www.youtube.com/watch?v=' + id);
            },

            ensurePlay: function() {
                if (this.isManualPaused) return;

                let p = document.getElementById('movie_player') || document.querySelector('.html5-video-player');
                if (p) {
                    if (typeof p.unMute === 'function') p.unMute();
                    if (typeof p.playVideo === 'function') p.playVideo();
                }

                let v = document.querySelector('video');
                if (v) {
                    v.playsInline = true;
                    v.muted = false;
                    if (v.paused) {
                        let promise = v.play();
                        if (promise !== undefined) {
                            promise.catch(function() {
                                let btn = document.querySelector('.ytp-large-play-button') ||
                                          document.querySelector('button.icon-button') ||
                                          document.querySelector('[aria-label*="Play"]');
                                if (btn) btn.click();
                            });
                        }
                    }
                }
            },

            play: function() {
                this.isManualPaused = false;
                this.ensurePlay();
            },

            pause: function() {
                this.isManualPaused = true;
                let p = document.getElementById('movie_player') || document.querySelector('.html5-video-player');
                if (p && typeof p.pauseVideo === 'function') p.pauseVideo();
                let v = document.querySelector('video');
                if (v) v.pause();
            },

            stop: function() {
                this.isManualPaused = true;
                let p = document.getElementById('movie_player') || document.querySelector('.html5-video-player');
                if (p && typeof p.stopVideo === 'function') p.stopVideo();
                let v = document.querySelector('video');
                if (v) { v.pause(); v.currentTime = 0; }
            },

            seek: function(sec) {
                let p = document.getElementById('movie_player') || document.querySelector('.html5-video-player');
                if (p && typeof p.seekTo === 'function') p.seekTo(sec, true);
                let v = document.querySelector('video');
                if (v) v.currentTime = sec;
            }
        };

        // 5. Time & Duration Sync (only used as fallback when NativeAudioEngine is not active)
        setInterval(function() {
            let v = document.querySelector('video');
            let p = document.getElementById('movie_player') || document.querySelector('.html5-video-player');

            let cur = 0;
            let dur = 0;
            let isPlaying = false;

            if (v) {
                cur = v.currentTime || 0;
                dur = v.duration || 0;
                isPlaying = !v.paused;
            } else if (p && typeof p.getCurrentTime === 'function') {
                cur = p.getCurrentTime() || 0;
                dur = p.getDuration() || 0;
                if (typeof p.getPlayerState === 'function') isPlaying = (p.getPlayerState() === 1);
            }

            if (cur > 0 || isPlaying) {
                window.webkit?.messageHandlers?.winampBridge?.postMessage({
                    action: 'timeUpdate',
                    currentTime: cur,
                    duration: dur,
                    isPlaying: isPlaying
                });

                // Smart Outro Silence Skip in last 4 seconds
                if (dur > 20 && (dur - cur) <= 4.0 && !window.__winamp.hasTriggeredOutro) {
                    window.__winamp.hasTriggeredOutro = true;
                    window.webkit?.messageHandlers?.winampBridge?.postMessage({ action: 'smartOutro' });
                }
            }
        }, 120);

        // Auto-Play Supervisor: Keeps audio active without touch
        setInterval(function() {
            if (!window.__winamp?.isManualPaused) {
                window.__winamp?.ensurePlay();
            }
        }, 500);
        """

        let userScript = WKUserScript(source: scriptSource, injectionTime: .atDocumentEnd, forMainFrameOnly: false)
        contentController.addUserScript(userScript)
        config.userContentController = contentController

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.isOpaque = false
        webView.backgroundColor = .black
        webView.scrollView.isScrollEnabled = false
        webView.navigationDelegate = context.coordinator

        // Set Desktop Safari User-Agent to completely bypass mobile YouTube gesture gating
        webView.customUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.5 Safari/605.1.15"

        // Load initial track
        let vid = engine.currentTrack?.videoId ?? "jfKfPfyJRdk"
        if let initialURL = URL(string: "https://www.youtube.com/watch?v=\(vid)") {
            webView.load(URLRequest(url: initialURL))
        }

        // Store reference in player engine
        engine.webView = webView
        return webView
    }

    public func updateUIView(_ uiView: WKWebView, context: Context) {}

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
                    // Only use WebView time if NativeAudioEngine is NOT actively playing
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

                case "trackEnded", "smartOutro":
                    // Only trigger if NativeAudioEngine is NOT handling track endings
                    if !NativeAudioEngine.shared.isPlaying {
                        print("[WinampBridge] Track ended or smart outro triggered. Advancing to next track.")
                        engine.nextTrack()
                    }

                default:
                    break
                }
            }
        }
    }
}
