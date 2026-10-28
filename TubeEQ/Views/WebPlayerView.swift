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

        // Injected Script: Instant Video Switcher + Auto-Play Audio + 10-Band Web Audio DSP + Real-time Clock Sync
        let scriptSource = """
        // 1. Prevent background pause on visibility or tab blur
        try {
            Object.defineProperty(document, 'hidden', { value: false, writable: false });
            Object.defineProperty(document, 'visibilityState', { value: 'visible', writable: false });
            document.addEventListener('visibilitychange', function(e) { e.stopImmediatePropagation(); }, true);
        } catch(e) {}
        window.addEventListener('blur', function(e) { e.stopImmediatePropagation(); }, true);

        // 2. Hide Mobile YouTube Chrome so ONLY the video fills the Winamp box
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

        // 3. Winamp Audio Engine & High-Performance Player Controller
        window.__winamp = {
            ctx: null,
            source: null,
            video: null,
            preampGain: null,
            masterGain: null,
            filters: [],
            isEqConnected: false,
            isManualPaused: false,
            currentVideoId: '',

            initAudioContext: function() {
                if (this.ctx) {
                    if (this.ctx.state === 'suspended') {
                        this.ctx.resume().catch(e => {});
                    }
                    return;
                }
                try {
                    const AudioCtx = window.AudioContext || window.webkitAudioContext;
                    if (!AudioCtx) return;
                    this.ctx = new AudioCtx();

                    // 10 Frequency Bands matching Winamp Classic Equalizer
                    const freqs = [70, 180, 320, 600, 1000, 3000, 6000, 12000, 14000, 16000];
                    this.filters = freqs.map((f, i) => {
                        let filter = this.ctx.createBiquadFilter();
                        if (i === 0) filter.type = 'lowshelf';
                        else if (i === freqs.length - 1) filter.type = 'highshelf';
                        else filter.type = 'peaking';
                        filter.frequency.value = f;
                        filter.Q.value = 1.2;
                        filter.gain.value = 0.0;
                        return filter;
                    });

                    for (let i = 0; i < this.filters.length - 1; i++) {
                        this.filters[i].connect(this.filters[i + 1]);
                    }

                    this.preampGain = this.ctx.createGain();
                    this.preampGain.gain.value = 1.0;
                    this.preampGain.connect(this.filters[0]);

                    this.masterGain = this.ctx.createGain();
                    this.masterGain.gain.value = 0.95;

                    const lastFilter = this.filters[this.filters.length - 1];
                    lastFilter.connect(this.masterGain);
                    this.masterGain.connect(this.ctx.destination);
                } catch(e) {
                    console.warn('[Winamp] Web Audio init error:', e);
                }
            },

            attachVideoToEQ: function(v) {
                if (!v || v.__winamp_eq_hooked) return;
                this.initAudioContext();
                if (!this.ctx) return;

                // IMPORTANT: Do NOT touch v.crossOrigin! Leave crossOrigin alone to prevent CORS blocking!
                try {
                    this.source = this.ctx.createMediaElementSource(v);
                    this.source.connect(this.preampGain);
                    v.__winamp_eq_hooked = true;
                    this.isEqConnected = true;
                } catch(e) {
                    // If cross-origin prevents Web Audio connection on this device,
                    // allow direct playback without silencing!
                    this.isEqConnected = false;
                }
            },

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

            // Instant Track Switch WITHOUT full-page reload
            loadVideo: function(id, crossfadeTime) {
                this.isManualPaused = false;
                this.currentVideoId = id;
                this.initAudioContext();
                if (this.ctx && this.ctx.state === 'suspended') {
                    this.ctx.resume().catch(e => {});
                }

                let v = document.querySelector('video');
                if (v && crossfadeTime > 0) {
                    // Smooth volume ducking
                    let origVol = (typeof v.volume === 'number' && !isNaN(v.volume)) ? v.volume : 1.0;
                    let fadeMs = Math.min(800, crossfadeTime * 250);
                    let start = Date.now();
                    let fadeInterval = setInterval(() => {
                        let elapsed = Date.now() - start;
                        let r = Math.max(0, 1.0 - (elapsed / fadeMs));
                        v.volume = origVol * r;
                        if (elapsed >= fadeMs) {
                            clearInterval(fadeInterval);
                            this.doSwitch(id);
                            v.volume = origVol;
                        }
                    }, 40);
                } else {
                    this.doSwitch(id);
                }
            },

            doSwitch: function(id) {
                // Method 1: YouTube HTML5 Video Player API (fastest: 50ms)
                let p = document.getElementById('movie_player') || document.querySelector('.html5-video-player');
                if (p && typeof p.loadVideoById === 'function') {
                    try {
                        p.loadVideoById(id);
                        if (typeof p.unMute === 'function') p.unMute();
                        if (typeof p.playVideo === 'function') p.playVideo();
                        return;
                    } catch(e) {}
                }

                // Method 2: YouTube Mobile SPA Navigation without reloading document
                let nav = document.getElementById('__winamp_spa_nav');
                if (!nav) {
                    nav = document.createElement('a');
                    nav.id = '__winamp_spa_nav';
                    nav.style.display = 'none';
                    document.body.appendChild(nav);
                }
                nav.href = '/watch?v=' + id;
                nav.click();

                // Ensure auto-playback triggers immediately
                setTimeout(() => {
                    this.ensurePlay();
                }, 300);
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
                    this.attachEvents(v);
                    this.attachVideoToEQ(v);

                    if (v.paused) {
                        let promise = v.play();
                        if (promise !== undefined) {
                            promise.catch(function() {
                                let btn = document.querySelector('.ytp-large-play-button, button.icon-button, [aria-label*="Play"], .player-control-play');
                                if (btn) btn.click();
                            });
                        }
                    }
                }
            },

            play: function() {
                this.isManualPaused = false;
                this.initAudioContext();
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
                let p = document.getElementById('movie_player') || document.querySelector('.html5-video-player');
                if (p && typeof p.setVolume === 'function') {
                    p.setVolume(Math.round(vol * 100));
                }
                let v = document.querySelector('video');
                if (v) v.volume = vol;
                if (this.masterGain && this.ctx) {
                    this.masterGain.gain.setValueAtTime(vol, this.ctx.currentTime);
                }
            },

            setGain: function(index, gain) {
                if (this.filters[index] && this.ctx) {
                    this.filters[index].gain.setValueAtTime(gain, this.ctx.currentTime);
                }
            },

            setPreamp: function(gain) {
                if (this.preampGain && this.ctx) {
                    let linear = Math.pow(10, gain / 20);
                    this.preampGain.gain.setValueAtTime(linear, this.ctx.currentTime);
                }
            }
        };

        // Resume AudioContext on any user interaction in the webview
        ['touchstart', 'touchend', 'click'].forEach(evt => {
            window.addEventListener(evt, function() {
                if (window.__winamp && window.__winamp.ctx && window.__winamp.ctx.state === 'suspended') {
                    window.__winamp.ctx.resume().catch(e => {});
                }
            }, { capture: true, passive: true });
        });

        // Continuous High-Speed Playback Supervisor
        setInterval(function() {
            if (!window.__winamp?.isManualPaused) {
                window.__winamp?.ensurePlay();
            }
        }, 300);

        // High-Precision Real-Time Clock & Duration Sync (200ms)
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
        }, 200);
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

        let initialVideoId = engine.currentTrack?.videoId ?? "dQw4w9WgXcQ"
        if let initialURL = URL(string: "https://m.youtube.com/watch?v=\(initialVideoId)") {
            webView.load(URLRequest(url: initialURL))
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
