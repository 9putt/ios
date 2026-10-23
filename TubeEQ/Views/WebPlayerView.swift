import SwiftUI
import WebKit

public struct WebPlayerView: UIViewRepresentable {
    @Binding var currentUrlString: String
    @Binding var canGoBack: Bool
    @Binding var canGoForward: Bool
    var webViewRef: (WKWebView) -> Void = { _ in }

    public func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    public func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        configuration.allowsPictureInPictureMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []
        
        let preferences = WKWebpagePreferences()
        preferences.allowsContentJavaScript = true
        configuration.defaultWebpagePreferences = preferences

        if #available(iOS 15.4, *) {
            configuration.preferences.isElementFullscreenEnabled = true
        }

        // Web Audio API DSP Core (10-Band Equalizer + Vocal Remover + Bass Boost)
        let userScriptSource = """
        // 1. Viewport configuration
        let meta = document.createElement('meta');
        meta.name = 'viewport';
        meta.content = 'width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no, viewport-fit=cover';
        document.getElementsByTagName('head')[0]?.appendChild(meta);

        // 2. Prevent background pausing by mocking visibility
        try {
            Object.defineProperty(document, 'hidden', { value: false, writable: false });
            Object.defineProperty(document, 'visibilityState', { value: 'visible', writable: false });
            document.addEventListener('visibilitychange', function(e) {
                e.stopImmediatePropagation();
            }, true);
        } catch(e) {}

        window.addEventListener('blur', function(e) {
            e.stopImmediatePropagation();
        }, true);

        // 3. CSS Adjustments: Hide YouTube bottom bar and top redundant logo
        let style = document.createElement('style');
        style.textContent = `
            html, body {
                background-color: #0f0f0f !important;
                margin: 0 !important;
                padding: 0 !important;
            }
            ytm-pivot-bar-renderer { display: none !important; }
            ytm-app-promo, .ytm-app-promo-renderer { display: none !important; }
            .header-logo, ytm-home-logo { opacity: 0.1 !important; pointer-events: none !important; }
            #player, .html5-video-player, video {
                width: 100% !important;
            }
        `;
        document.head.appendChild(style);

        // 4. Professional Web Audio DSP Engine
        window.__tubeEQ = {
            ctx: null,
            source: null,
            attachedVideo: null,
            filters: [],
            normalGain: null,
            karaokeGain: null,
            splitter: null,
            merger: null,
            inverter: null,
            isVocalMuted: false,
            gains: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0],

            buildGraph: function() {
                if (!this.ctx) return;
                const freqs = [32, 64, 125, 250, 500, 1000, 2000, 4000, 8000, 16000];
                
                this.filters = freqs.map((f, i) => {
                    let filter = this.ctx.createBiquadFilter();
                    if (i === 0) filter.type = 'lowshelf';
                    else if (i === freqs.length - 1) filter.type = 'highshelf';
                    else filter.type = 'peaking';
                    filter.frequency.value = f;
                    filter.Q.value = 1.0;
                    filter.gain.value = this.gains[i] || 0.0;
                    return filter;
                });

                for (let i = 0; i < this.filters.length - 1; i++) {
                    this.filters[i].connect(this.filters[i + 1]);
                }

                const lastFilter = this.filters[this.filters.length - 1];

                this.normalGain = this.ctx.createGain();
                this.normalGain.gain.value = this.isVocalMuted ? 0.0 : 1.0;
                lastFilter.connect(this.normalGain);
                this.normalGain.connect(this.ctx.destination);

                this.splitter = this.ctx.createChannelSplitter(2);
                this.merger = this.ctx.createChannelMerger(2);
                this.inverter = this.ctx.createGain();
                this.inverter.gain.value = -1.0;
                this.karaokeGain = this.ctx.createGain();
                this.karaokeGain.gain.value = this.isVocalMuted ? 1.0 : 0.0;

                lastFilter.connect(this.splitter);
                this.splitter.connect(this.merger, 0, 0);
                this.splitter.connect(this.merger, 0, 1);
                this.splitter.connect(this.inverter, 1, 0);
                this.inverter.connect(this.merger, 0, 0);
                this.inverter.connect(this.merger, 0, 1);

                this.merger.connect(this.karaokeGain);
                this.karaokeGain.connect(this.ctx.destination);
                console.log('[TubeEQ] Audio DSP graph built successfully!');
            },

            attachToVideo: function(video) {
                if (!video) return;
                try {
                    const AudioContext = window.AudioContext || window.webkitAudioContext;
                    if (!this.ctx) {
                        this.ctx = new AudioContext();
                        this.buildGraph();
                    }

                    if (this.attachedVideo === video && this.source) return;
                    if (video.__tube_sourced) return;

                    video.crossOrigin = 'anonymous';
                    this.source = this.ctx.createMediaElementSource(video);
                    video.__tube_sourced = true;
                    this.attachedVideo = video;
                    this.source.connect(this.filters[0]);
                    console.log('[TubeEQ] Attached MediaElementSource to video element!');
                } catch(e) {
                    console.log('[TubeEQ] Video attach error:', e);
                }
            },

            ensureAttached: function() {
                let video = document.querySelector('video.html5-main-video') || document.querySelector('video');
                if (video) {
                    this.attachToVideo(video);
                }
            },

            userGestureInit: function() {
                this.ensureAttached();
                if (this.ctx && this.ctx.state === 'suspended') {
                    this.ctx.resume().catch(function() {});
                }
            },

            setGain: function(bandIndex, gainVal) {
                const val = parseFloat(gainVal);
                this.gains[bandIndex] = val;
                this.ensureAttached();
                if (this.ctx && this.ctx.state === 'suspended') {
                    this.ctx.resume().catch(function() {});
                }
                if (this.filters[bandIndex] && this.ctx) {
                    this.filters[bandIndex].gain.setTargetAtTime(val, this.ctx.currentTime, 0.02);
                }
            },

            setBassBoost: function(enable) {
                const boost = enable ? 12.0 : 0.0;
                this.setGain(0, boost);
                this.setGain(1, boost * 0.8);
            },

            setVocalRemover: function(enable) {
                this.isVocalMuted = enable;
                this.ensureAttached();
                if (this.ctx && this.ctx.state === 'suspended') {
                    this.ctx.resume().catch(function() {});
                }
                const now = this.ctx ? this.ctx.currentTime : 0;
                if (this.normalGain && this.karaokeGain) {
                    this.normalGain.gain.setTargetAtTime(enable ? 0.0 : 1.0, now, 0.02);
                    this.karaokeGain.gain.setTargetAtTime(enable ? 1.0 : 0.0, now, 0.02);
                    console.log('[TubeEQ] Vocal remover toggled:', enable);
                }
            }
        };

        function unlockAudioEngine() {
            if (window.__tubeEQ) {
                window.__tubeEQ.ensureAttached();
                if (window.__tubeEQ.ctx && window.__tubeEQ.ctx.state === 'suspended') {
                    window.__tubeEQ.ctx.resume().catch(function() {});
                }
            }
        }
        ['touchstart', 'touchend', 'click'].forEach(evt => {
            window.addEventListener(evt, unlockAudioEngine, { capture: true, passive: true });
        });

        ['play', 'playing', 'loadedmetadata'].forEach(evt => {
            document.addEventListener(evt, function(e) {
                if (e.target.tagName === 'VIDEO') {
                    unlockAudioEngine();
                }
            }, true);
        });

        setInterval(function() {
            if (window.__tubeEQ) {
                window.__tubeEQ.ensureAttached();
            }
        }, 1000);
        """
        let userScript = WKUserScript(source: userScriptSource, injectionTime: .atDocumentEnd, forMainFrameOnly: true)
        configuration.userContentController.addUserScript(userScript)

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true
        webView.scrollView.isScrollEnabled = true
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.isOpaque = false
        webView.backgroundColor = .black
        webView.scrollView.backgroundColor = .black

        if let url = URL(string: currentUrlString) {
            let request = URLRequest(url: url)
            webView.load(request)
        }

        DispatchQueue.main.async {
            self.webViewRef(webView)
        }

        return webView
    }

    public func updateUIView(_ uiView: WKWebView, context: Context) {
        DispatchQueue.main.async {
            self.canGoBack = uiView.canGoBack
            self.canGoForward = uiView.canGoForward
        }
    }

    public class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        var parent: WebPlayerView

        init(_ parent: WebPlayerView) {
            self.parent = parent
        }

        public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            DispatchQueue.main.async {
                self.parent.canGoBack = webView.canGoBack
                self.parent.canGoForward = webView.canGoForward
                if let url = webView.url?.absoluteString {
                    self.parent.currentUrlString = url
                }
                // Trigger audio init if video is already present
                webView.evaluateJavaScript("window.__tubeEQ?.init();", completionHandler: nil)
            }
        }
    }
}
