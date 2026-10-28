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

        // Injected Script: Audio DSP + Auto-Play + Hide Mobile YouTube UI to fit video neatly into Winamp Box
        let scriptSource = """
        // 1. Prevent background pause on tab blur
        try {
            Object.defineProperty(document, 'hidden', { value: false, writable: false });
            Object.defineProperty(document, 'visibilityState', { value: 'visible', writable: false });
            document.addEventListener('visibilitychange', function(e) { e.stopImmediatePropagation(); }, true);
        } catch(e) {}
        window.addEventListener('blur', function(e) { e.stopImmediatePropagation(); }, true);

        // 2. Hide Mobile YouTube Chrome so ONLY the video fills the container
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
            .ytp-watermark, .ytp-pause-overlay, ytm-engagement-panel-section-list-renderer {
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

        // 3. Winamp DSP & Video Automation Object
        window.__winamp = {
            ctx: null,
            source: null,
            video: null,
            preampGain: null,
            masterGain: null,
            filters: [],
            analyser: null,
            normalGain: null,
            karaokeGain: null,
            isVocalMuted: false,
            isManualPaused: false,

            initAudio: function() {
                if (this.ctx) return;
                const AudioCtx = window.AudioContext || window.webkitAudioContext;
                if (!AudioCtx) return;
                this.ctx = new AudioCtx();

                const freqs = [70, 180, 320, 600, 1000, 3000, 6000, 12000, 14000, 16000];
                this.filters = freqs.map((f, i) => {
                    let filter = this.ctx.createBiquadFilter();
                    if (i === 0) filter.type = 'lowshelf';
                    else if (i === freqs.length - 1) filter.type = 'highshelf';
                    else filter.type = 'peaking';
                    filter.frequency.value = f;
                    filter.Q.value = 1.0;
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
                this.masterGain.gain.value = 0.85;

                this.analyser = this.ctx.createAnalyser();
                this.analyser.fftSize = 64;

                const lastFilter = this.filters[this.filters.length - 1];

                this.normalGain = this.ctx.createGain();
                lastFilter.connect(this.normalGain);
                this.normalGain.connect(this.masterGain);

                let splitter = this.ctx.createChannelSplitter(2);
                let merger = this.ctx.createChannelMerger(2);
                let inverter = this.ctx.createGain();
                inverter.gain.value = -1.0;
                this.karaokeGain = this.ctx.createGain();
                this.karaokeGain.gain.value = 0.0;

                lastFilter.connect(splitter);
                splitter.connect(merger, 0, 0);
                splitter.connect(merger, 0, 1);
                splitter.connect(inverter, 1, 0);
                inverter.connect(merger, 0, 0);
                inverter.connect(merger, 0, 1);
                merger.connect(this.karaokeGain);
                this.karaokeGain.connect(this.masterGain);

                this.masterGain.connect(this.analyser);
                this.analyser.connect(this.ctx.destination);
            },

            attachVideo: function(v) {
                if (!v || this.video === v) return;
                this.initAudio();
                if (v.__winamp_attached) return;
                try {
                    v.crossOrigin = 'anonymous';
                    this.source = this.ctx.createMediaElementSource(v);
                    this.source.connect(this.preampGain);
                    v.__winamp_attached = true;
                    this.video = v;

                    v.addEventListener('ended', function() {
                        window.webkit?.messageHandlers?.winampBridge?.postMessage({ action: 'trackEnded' });
                    });
                } catch(e) {}
            },

            loadVideo: function(id, crossfadeTime) {
                this.isManualPaused = false;
                this.initAudio();
                if (this.masterGain && crossfadeTime > 0) {
                    let cur = this.masterGain.gain.value;
                    let now = this.ctx.currentTime;
                    this.masterGain.gain.setValueAtTime(cur, now);
                    this.masterGain.gain.linearRampToValueAtTime(0.001, now + (crossfadeTime / 2));
                    setTimeout(() => {
                        window.location.replace("https://m.youtube.com/watch?v=" + id);
                    }, crossfadeTime * 450);
                } else {
                    window.location.replace("https://m.youtube.com/watch?v=" + id);
                }
            },

            play: function() {
                this.isManualPaused = false;
                if (this.ctx && this.ctx.state === 'suspended') {
                    this.ctx.resume();
                }
                let v = document.querySelector('video');
                if (v) v.play().catch(e => {});
            },

            pause: function() {
                this.isManualPaused = true;
                let v = document.querySelector('video');
                if (v) v.pause();
            },

            stop: function() {
                this.isManualPaused = true;
                let v = document.querySelector('video');
                if (v) { v.pause(); v.currentTime = 0; }
            },

            seek: function(sec) {
                let v = document.querySelector('video');
                if (v) v.currentTime = sec;
            },

            setVolume: function(vol) {
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
            },

            setVocalRemover: function(enabled) {
                this.isVocalMuted = enabled;
                if (this.normalGain && this.karaokeGain && this.ctx) {
                    let now = this.ctx.currentTime;
                    this.normalGain.gain.setValueAtTime(enabled ? 0.0 : 1.0, now);
                    this.karaokeGain.gain.setValueAtTime(enabled ? 1.0 : 0.0, now);
                }
            }
        };

        // Auto-attach and start playback
        setInterval(() => {
            let v = document.querySelector('video');
            if (v) {
                if (!v.__winamp_attached) {
                    window.__winamp?.attachVideo(v);
                }
                if (v.paused && !window.__winamp?.isManualPaused) {
                    v.play().catch(e => {});
                }
            }
        }, 300);
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

        // Load mobile YouTube directly (No Error 152 / Error 150!)
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
                if let action = dict["action"] as? String, action == "trackEnded" {
                    DispatchQueue.main.async {
                        self.parent.engine.nextTrack()
                    }
                }
            }
        }
    }
}
