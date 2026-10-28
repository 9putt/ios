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

        // Injected Script: Desktop Autoplay + Instant Switching + Real-time Clock Sync + WebAudio DSP
        let scriptSource = """
        // 1. Prevent background pause on visibility or tab blur
        try {
            Object.defineProperty(document, 'hidden', { value: false, writable: false });
            Object.defineProperty(document, 'visibilityState', { value: 'visible', writable: false });
            document.addEventListener('visibilitychange', function(e) { e.stopImmediatePropagation(); }, true);
        } catch(e) {}
        window.addEventListener('blur', function(e) { e.stopImmediatePropagation(); }, true);

        // 2. Hide all YouTube UI chrome so ONLY the clean video fills the Winamp box
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

        // 3. WebAudio DSP for 10-Band EQ & Stereo Balance
        let audioCtx = null;
        let biquadBands = [];
        let stereoPanner = null;
        let gainNode = null;
        const eqFrequencies = [70, 180, 320, 600, 1000, 3000, 6000, 12000, 14000, 16000];

        function initWebAudio() {
            if (audioCtx) return;
            try {
                const AC = window.AudioContext || window.webkitAudioContext;
                if (!AC) return;
                audioCtx = new AC();
                let lastNode = null;
                for (let i = 0; i < 10; i++) {
                    let f = audioCtx.createBiquadFilter();
                    f.frequency.value = eqFrequencies[i];
                    f.gain.value = 0;
                    if (i === 0) f.type = 'lowshelf';
                    else if (i === 9) f.type = 'highshelf';
                    else f.type = 'peaking';
                    biquadBands.push(f);
                    if (lastNode) lastNode.connect(f);
                    lastNode = f;
                }
                if (audioCtx.createStereoPanner) {
                    stereoPanner = audioCtx.createStereoPanner();
                    lastNode.connect(stereoPanner);
                    lastNode = stereoPanner;
                }
                gainNode = audioCtx.createGain();
                lastNode.connect(gainNode);
                gainNode.connect(audioCtx.destination);

                let v = document.querySelector('video');
                if (v) {
                    let src = audioCtx.createMediaElementSource(v);
                    src.connect(biquadBands[0]);
                }
            } catch(e) {}
        }

        // 4. Winamp Player Controller
        window.__winamp = {
            isManualPaused: false,
            currentVideoId: '',
            baseVolume: 0.85,
            preampMultiplier: 1.0,
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
                    this.updateVolume();
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
                initWebAudio();
            },

            play: function() {
                this.isManualPaused = false;
                this.ensurePlay();
                if (audioCtx && audioCtx.state === 'suspended') {
                    audioCtx.resume();
                }
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
            },

            setVolume: function(vol) {
                this.baseVolume = Math.max(0.0, Math.min(1.0, vol));
                this.updateVolume();
            },

            setPreamp: function(gain) {
                this.preampMultiplier = Math.pow(10.0, gain / 20.0);
                this.updateVolume();
            },

            updateVolume: function() {
                let finalVol = Math.max(0.0, Math.min(1.0, this.baseVolume * this.preampMultiplier));
                let p = document.getElementById('movie_player') || document.querySelector('.html5-video-player');
                if (p && typeof p.setVolume === 'function') {
                    p.setVolume(Math.round(finalVol * 100));
                    if (finalVol > 0 && typeof p.unMute === 'function') p.unMute();
                }
                let v = document.querySelector('video');
                if (v) v.volume = finalVol;
                if (gainNode) gainNode.gain.value = finalVol;
            },

            setBalance: function(pan) {
                if (stereoPanner) {
                    stereoPanner.pan.value = Math.max(-1.0, Math.min(1.0, pan));
                }
            },

            setGain: function(index, gain) {
                if (biquadBands[index]) {
                    biquadBands[index].gain.value = gain * 2.0;
                }
            }
        };

        // 5. High-Frequency Real-Time Time & Duration Sync (120ms)
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
                    if let cur = dict["currentTime"] as? Double, cur > 0 {
                        engine.currentTime = cur
                    }
                    if let dur = dict["duration"] as? Double, dur > 0 {
                        engine.duration = dur
                    }
                    if let playing = dict["isPlaying"] as? Bool {
                        engine.isPlaying = playing
                    }

                case "trackEnded", "smartOutro":
                    print("[WinampBridge] Track ended or smart outro triggered. Advancing to next track.")
                    engine.nextTrack()

                default:
                    break
                }
            }
        }
    }
}
