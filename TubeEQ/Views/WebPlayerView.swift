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
        config.allowsPictureInPictureMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        config.websiteDataStore = WKWebsiteDataStore.default()

        let prefs = WKWebpagePreferences()
        prefs.allowsContentJavaScript = true
        config.defaultWebpagePreferences = prefs

        let contentController = WKUserContentController()
        contentController.add(context.coordinator, name: "winampBridge")

        // Injected Script: Instant Video Switcher + Auto-Play Audio + Real-time Clock Sync
        let scriptSource = """
        // 1. Prevent background pause on visibility or tab blur
        try {
            Object.defineProperty(document, 'hidden', { value: false, writable: false });
            Object.defineProperty(document, 'visibilityState', { value: 'visible', writable: false });
            document.addEventListener('visibilitychange', function(e) { e.stopImmediatePropagation(); }, true);
        } catch(e) {}
        window.addEventListener('blur', function(e) { e.stopImmediatePropagation(); }, true);

        // 2. Hide Mobile YouTube Chrome so ONLY the clean video fills the Winamp box
        let style = document.createElement('style');
        style.textContent = `
            html, body {
                background: #000000 !important;
                margin: 0 !important;
                padding: 0 !important;
                overflow: hidden !important;
            }
            header, ytm-mobile-topbar-renderer, ytm-pivot-bar-renderer,
            ytm-item-section-renderer, ytm-watch-metadata, ytm-single-column-watch-next-results-renderer,
            #comments, .related-chips-slot-wrapper, ytm-playlist, ytm-app-promo,
            .ytm-app-promo-renderer, #player-control-overlay, .ytp-chrome-top, .ytp-chrome-bottom,
            .ytp-watermark, .ytp-pause-overlay, ytm-engagement-panel-section-list-renderer,
            .ytp-endscreen-content, .ytp-spinner {
                display: none !important;
            }
            .video-player-container, #player-container-id, #player, video {
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

        // 3. Winamp Player Controller (Fast switching, Auto-play, Clean Sound)
        window.__winamp = {
            video: null,
            isManualPaused: false,
            currentVideoId: '',
            baseVolume: 0.85,
            preampMultiplier: 1.0,

            attachEvents: function(v) {
                if (!v || v.__winamp_events_hooked) return;
                v.__winamp_events_hooked = true;
                this.video = v;

                v.addEventListener('ended', function() {
                    window.webkit?.messageHandlers?.winampBridge?.postMessage({ action: 'trackEnded' });
                });

                v.addEventListener('timeupdate', function() {
                    if (v.currentTime > 0) {
                        window.webkit?.messageHandlers?.winampBridge?.postMessage({
                            action: 'timeUpdate',
                            currentTime: v.currentTime,
                            duration: v.duration || 0,
                            isPlaying: !v.paused
                        });
                    }
                });
            },

            loadVideo: function(id, crossfadeTime) {
                this.isManualPaused = false;
                this.currentVideoId = id;

                let p = document.getElementById('movie_player') || document.querySelector('.html5-video-player');
                if (p && typeof p.loadVideoById === 'function') {
                    try {
                        p.loadVideoById({ videoId: id, startSeconds: 0 });
                        if (typeof p.unMute === 'function') p.unMute();
                        if (typeof p.playVideo === 'function') p.playVideo();
                        this.ensurePlay();
                        return;
                    } catch(e) {}
                }

                // If player is not yet initialised, navigate directly
                window.location.replace('https://m.youtube.com/watch?v=' + id);
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
                    v.removeAttribute('muted');
                    this.attachEvents(v);

                    if (v.paused) {
                        let promise = v.play();
                        if (promise !== undefined) {
                            promise.catch(function() {
                                // Simulate click on the YouTube large play button if paused
                                let btn = document.querySelector('.ytp-large-play-button') ||
                                          document.querySelector('button.icon-button') ||
                                          document.querySelector('[aria-label*="Play"]') ||
                                          document.querySelector('.player-control-play');
                                if (btn) {
                                    btn.click();
                                }
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
                if (p && typeof p.pauseVideo === 'function') {
                    p.pauseVideo();
                }
                let v = document.querySelector('video');
                if (v) v.pause();
            },

            stop: function() {
                this.isManualPaused = true;
                let p = document.getElementById('movie_player') || document.querySelector('.html5-video-player');
                if (p && typeof p.stopVideo === 'function') {
                    p.stopVideo();
                }
                let v = document.querySelector('video');
                if (v) { v.pause(); v.currentTime = 0; }
            },

            seek: function(sec) {
                let p = document.getElementById('movie_player') || document.querySelector('.html5-video-player');
                if (p && typeof p.seekTo === 'function') {
                    p.seekTo(sec, true);
                }
                let v = document.querySelector('video');
                if (v) v.currentTime = sec;
            },

            setVolume: function(vol) {
                this.baseVolume = Math.max(0.0, Math.min(1.0, vol));
                let p = document.getElementById('movie_player') || document.querySelector('.html5-video-player');
                if (p && typeof p.setVolume === 'function') {
                    p.setVolume(Math.round(this.baseVolume * 100));
                }
                let v = document.querySelector('video');
                if (v) {
                    v.volume = this.baseVolume;
                }
            },

            setPreamp: function(gain) {
                let linear = Math.pow(10, gain / 20.0);
                this.preampMultiplier = linear;
                let finalVol = Math.max(0.0, Math.min(1.0, this.baseVolume * this.preampMultiplier));
                let p = document.getElementById('movie_player') || document.querySelector('.html5-video-player');
                if (p && typeof p.setVolume === 'function') {
                    p.setVolume(Math.round(finalVol * 100));
                }
            },

            muteVideo: function() {
                let v = document.querySelector('video');
                if (v) v.muted = true;
                let p = document.getElementById('movie_player') || document.querySelector('.html5-video-player');
                if (p && typeof p.mute === 'function') p.mute();
            },

            unmuteDirect: function() {
                let v = document.querySelector('video');
                if (v) v.muted = false;
                let p = document.getElementById('movie_player') || document.querySelector('.html5-video-player');
                if (p && typeof p.unMute === 'function') p.unMute();
            }
        };

        // Continuous Auto-Play Supervisor: Ensures immediate playback with sound
        setInterval(function() {
            if (!window.__winamp?.isManualPaused) {
                window.__winamp?.ensurePlay();
            }
        }, 400);

        // High-Precision Real-Time Clock & Duration Sync (250ms)
        setInterval(function() {
            let p = document.getElementById('movie_player') || document.querySelector('.html5-video-player');
            let v = document.querySelector('video');

            let curTime = 0;
            let durTime = 0;
            let isPlaying = false;

            if (p && typeof p.getCurrentTime === 'function') {
                curTime = p.getCurrentTime() || 0;
                durTime = p.getDuration() || 0;
                if (typeof p.getPlayerState === 'function') {
                    isPlaying = (p.getPlayerState() === 1);
                }
            }

            if (v) {
                if (curTime <= 0) curTime = v.currentTime || 0;
                if (durTime <= 0) durTime = v.duration || 0;
                if (!isPlaying) isPlaying = !v.paused;
            }

            if (curTime > 0 || isPlaying) {
                window.webkit?.messageHandlers?.winampBridge?.postMessage({
                    action: 'timeUpdate',
                    currentTime: curTime,
                    duration: durTime,
                    isPlaying: isPlaying
                });
            }
        }, 250);
        """

        let userScript = WKUserScript(source: scriptSource, injectionTime: .atDocumentEnd, forMainFrameOnly: false)
        contentController.addUserScript(userScript)
        config.userContentController = contentController

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.backgroundColor = .black
        webView.isOpaque = true
        webView.scrollView.isScrollEnabled = false
        webView.navigationDelegate = context.coordinator

        engine.webView = webView

        // Restore Google/YouTube cookies from iOS Keychain so user never has to re-login after reinstalling!
        KeychainCookieManager.shared.restoreCookies(to: webView.configuration.websiteDataStore.httpCookieStore) {
            let initialVideoId = self.engine.currentTrack?.videoId ?? "jfKfPfyJRdk"
            if let initialURL = URL(string: "https://m.youtube.com/watch?v=\(initialVideoId)") {
                webView.load(URLRequest(url: initialURL))
            }
        }

        return webView
    }

    public func updateUIView(_ uiView: WKWebView, context: Context) {
        if engine.webView != uiView {
            engine.webView = uiView
        }
    }

    public class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        var parent: WebPlayerView

        init(_ parent: WebPlayerView) {
            self.parent = parent
        }

        public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            // Persist updated session cookies to Keychain
            KeychainCookieManager.shared.persistCookies(from: webView.configuration.websiteDataStore.httpCookieStore)
        }

        public func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            if message.name == "winampBridge", let dict = message.body as? [String: Any] {
                guard let action = dict["action"] as? String else { return }

                if action == "timeUpdate" {
                    let cur = dict["currentTime"] as? Double ?? 0.0
                    let dur = dict["duration"] as? Double ?? 0.0
                    let playing = dict["isPlaying"] as? Bool ?? true

                    DispatchQueue.main.async {
                        self.parent.engine.currentTime = cur
                        if dur > 0 && !dur.isNaN && !dur.isInfinite {
                            self.parent.engine.duration = dur
                        }
                        self.parent.engine.isPlaying = playing

                        // Smart outro ending credit skip (smoothly transition to next song before silent credit roll)
                        if dur > 25 && (dur - cur) <= 6.0 && !self.parent.engine.hasTriggeredOutroSkip {
                            self.parent.engine.hasTriggeredOutroSkip = true
                            self.parent.engine.nextTrack()
                        }
                    }
                } else if action == "trackEnded" {
                    DispatchQueue.main.async {
                        self.parent.engine.nextTrack()
                    }
                } else if action == "playState" {
                    if let playing = dict["isPlaying"] as? Bool {
                        DispatchQueue.main.async {
                            self.parent.engine.isPlaying = playing
                        }
                    }
                }
            }
        }
    }
}
