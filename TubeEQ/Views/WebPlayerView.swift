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

        // 2. Prevent background pausing
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

        // 4. Web Audio API Engine
        window.__tubeEQ = {
            ctx: null,
            source: null,
            filters: [],
            splitter: null,
            merger: null,
            vocalInvertGain: null,
            outputNode: null,
            isVocalMuted: false,

            init: function() {
                let video = document.querySelector('video');
                if (!video || this.source) return;
                try {
                    const AudioContext = window.AudioContext || window.webkitAudioContext;
                    this.ctx = new AudioContext();
                    this.source = this.ctx.createMediaElementSource(video);

                    const freqs = [32, 64, 125, 250, 500, 1000, 2000, 4000, 8000, 16000];
                    let lastNode = this.source;

                    this.filters = freqs.map((f, i) => {
                        let filter = this.ctx.createBiquadFilter();
                        if (i === 0) filter.type = 'lowshelf';
                        else if (i === freqs.length - 1) filter.type = 'highshelf';
                        else filter.type = 'peaking';
                        filter.frequency.value = f;
                        filter.Q.value = 1.0;
                        filter.gain.value = 0.0;
                        lastNode.connect(filter);
                        lastNode = filter;
                        return filter;
                    });

                    this.outputNode = lastNode;

                    // Vocal Remover Nodes (Phase Cancellation: Left - Right)
                    this.splitter = this.ctx.createChannelSplitter(2);
                    this.merger = this.ctx.createChannelMerger(2);
                    this.vocalInvertGain = this.ctx.createGain();
                    this.vocalInvertGain.gain.value = -1.0;

                    this.outputNode.connect(this.ctx.destination);
                    console.log("[TubeEQ] DSP Audio Engine initialized!");
                } catch(e) {
                    console.log("[TubeEQ] Init error:", e);
                }
            },

            setGain: function(bandIndex, gainVal) {
                if (!this.ctx) this.init();
                if (this.ctx && this.ctx.state === 'suspended') this.ctx.resume();
                if (this.filters[bandIndex]) {
                    this.filters[bandIndex].gain.value = parseFloat(gainVal);
                }
            },

            setBassBoost: function(enable) {
                if (!this.ctx) this.init();
                if (this.ctx && this.ctx.state === 'suspended') this.ctx.resume();
                const boost = enable ? 10.0 : 0.0;
                if (this.filters[0]) this.filters[0].gain.value = boost;
                if (this.filters[1]) this.filters[1].gain.value = boost * 0.8;
            },

            setVocalRemover: function(enable) {
                if (!this.ctx) this.init();
                if (this.ctx && this.ctx.state === 'suspended') this.ctx.resume();
                this.isVocalMuted = enable;
                try {
                    this.outputNode.disconnect();
                    if (enable) {
                        this.outputNode.connect(this.splitter);
                        this.splitter.connect(this.merger, 0, 0);
                        this.splitter.connect(this.merger, 0, 1);
                        this.splitter.connect(this.vocalInvertGain, 1);
                        this.vocalInvertGain.connect(this.merger, 0, 0);
                        this.vocalInvertGain.connect(this.merger, 0, 1);
                        this.merger.connect(this.ctx.destination);
                    } else {
                        this.outputNode.connect(this.ctx.destination);
                    }
                } catch(e) {
                    console.log("[TubeEQ] Vocal remover error:", e);
                }
            }
        };

        // Attach listeners to initialize upon playback
        ['play', 'playing', 'timeupdate'].forEach(evt => {
            document.addEventListener(evt, function(e) {
                if (e.target.tagName === 'VIDEO') {
                    window.__tubeEQ.init();
                    if (window.__tubeEQ.ctx && window.__tubeEQ.ctx.state === 'suspended') {
                        window.__tubeEQ.ctx.resume();
                    }
                }
            }, true);
        });
        """
        let userScript = WKUserScript(source: userScriptSource, injectionTime: .atDocumentEnd, forMainFrameOnly: false)
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
