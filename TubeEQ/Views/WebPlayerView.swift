import SwiftUI
import WebKit

public struct WebPlayerView: UIViewRepresentable {
    @ObservedObject var engine = WinampPlayerEngine.shared
    var onTrackExtracted: (([TrackItem]) -> Void)? = nil

    public func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    public func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.allowsPictureInPictureMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []

        let prefs = WKWebpagePreferences()
        prefs.allowsContentJavaScript = true
        config.defaultWebpagePreferences = prefs

        let contentController = WKUserContentController()
        contentController.add(context.coordinator, name: "winampBridge")

        // Injected Web Audio Engine with 10-band EQ, Analyser, and Crossfade
        let scriptSource = """
        // Prevent background pausing
        try {
            Object.defineProperty(document, 'hidden', { value: false, writable: false });
            Object.defineProperty(document, 'visibilityState', { value: 'visible', writable: false });
            document.addEventListener('visibilitychange', function(e) { e.stopImmediatePropagation(); }, true);
        } catch(e) {}
        window.addEventListener('blur', function(e) { e.stopImmediatePropagation(); }, true);

        // Inject Responsive Video Container Styling
        let style = document.createElement('style');
        style.textContent = `
            html, body {
                background-color: #000000 !important;
                margin: 0 !important;
                padding: 0 !important;
                overflow: hidden !important;
            }
            #player, .html5-video-player, video {
                width: 100% !important;
                height: 100% !important;
                object-fit: cover !important;
            }
            .ytp-chrome-top, .ytp-chrome-bottom, .ytp-watermark, .ytp-pause-overlay {
                display: none !important;
            }
        `;
        document.head.appendChild(style);

        // Winamp DSP Engine Object
        window.__winamp = {
            ctx: null,
            source: null,
            video: null,
            preampGain: null,
            masterGain: null,
            panNode: null,
            filters: [],
            analyser: null,
            normalGain: null,
            karaokeGain: null,
            isVocalMuted: false,

            initAudio: function() {
                if (this.ctx) return;
                const AudioCtx = window.AudioContext || window.webkitAudioContext;
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

                // Vocal remover cancellation nodes
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
                console.log('[Winamp] Audio DSP graph initialized');
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
                    console.log('[Winamp] Video attached to Web Audio DSP');
                } catch(e) {
                    console.log('[Winamp] Attach error:', e);
                }
            },

            loadVideo: function(id, crossfadeTime) {
                this.initAudio();
                let v = document.querySelector('video');
                if (this.masterGain && crossfadeTime > 0) {
                    let cur = this.masterGain.gain.value;
                    let now = this.ctx.currentTime;
                    this.masterGain.gain.setValueAtTime(cur, now);
                    this.masterGain.gain.linearRampToValueAtTime(0.001, now + (crossfadeTime / 2));
                    setTimeout(() => {
                        window.location.replace('https://www.youtube.com/embed/' + id + '?autoplay=1&playsinline=1&controls=0&modestbranding=1&rel=0&iv_load_policy=3');
                    }, crossfadeTime * 400);
                } else {
                    window.location.replace('https://www.youtube.com/embed/' + id + '?autoplay=1&playsinline=1&controls=0&modestbranding=1&rel=0&iv_load_policy=3');
                }
            },

            play: function() {
                if (this.ctx && this.ctx.state === 'suspended') {
                    this.ctx.resume();
                }
                let v = document.querySelector('video');
                if (v) v.play();
            },

            pause: function() {
                let v = document.querySelector('video');
                if (v) v.pause();
            },

            stop: function() {
                let v = document.querySelector('video');
                if (v) {
                    v.pause();
                    v.currentTime = 0;
                }
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

        // Auto attach to video element when created
        setInterval(() => {
            let v = document.querySelector('video');
            if (v && !v.__winamp_attached) {
                window.__winamp?.attachVideo(v);
            }
        }, 500);
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

        // Load initial embedded player
        let initialVideoId = engine.currentTrack?.videoId ?? "dQw4w9WgXcQ"
        let initialURL = URL(string: "https://www.youtube.com/embed/\(initialVideoId)?autoplay=0&playsinline=1&controls=0&modestbranding=1&rel=0")!
        webView.load(URLRequest(url: initialURL))

        return webView
    }

    public func updateUIView(_ uiView: WKWebView, context: Context) {
        // Keeps reference up to date
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
                if let action = dict["action"] as? String, action == "tracksExtracted", let rawTracks = dict["tracks"] as? [[String: Any]] {
                    var parsed: [TrackItem] = []
                    for t in rawTracks {
                        let title = t["title"] as? String ?? "YouTube Music Track"
                        let artist = t["artist"] as? String ?? "YouTube Music"
                        let vid = t["videoId"] as? String ?? ""
                        let duration = t["duration"] as? TimeInterval ?? 210.0
                        if !vid.isEmpty {
                            parsed.append(TrackItem(
                                title: title,
                                artist: artist,
                                duration: duration,
                                urlString: "https://www.youtube.com/watch?v=\(vid)",
                                isLocal: false,
                                videoId: vid
                            ))
                        }
                    }
                    self.parent.onTrackExtracted?(parsed)
                }
            }
        }

        public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            webView.evaluateJavaScript("window.__winamp?.initAudio();", completionHandler: nil)
        }
    }
}
