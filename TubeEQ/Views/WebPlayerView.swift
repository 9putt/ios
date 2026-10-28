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
        config.websiteDataStore = WKWebsiteDataStore.default()

        let prefs = WKWebpagePreferences()
        prefs.allowsContentJavaScript = true
        config.defaultWebpagePreferences = prefs

        let contentController = WKUserContentController()
        contentController.add(context.coordinator, name: "winampBridge")

        // DSP & Audio Graph Injection Script
        let scriptSource = """
        try {
            Object.defineProperty(document, 'hidden', { value: false, writable: false });
            Object.defineProperty(document, 'visibilityState', { value: 'visible', writable: false });
            document.addEventListener('visibilitychange', function(e) { e.stopImmediatePropagation(); }, true);
        } catch(e) {}
        window.addEventListener('blur', function(e) { e.stopImmediatePropagation(); }, true);

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
                } catch(e) {}
            },

            loadVideo: function(id, crossfadeTime) {
                this.initAudio();
                if (window.ytPlayer && typeof window.ytPlayer.loadVideoById === 'function') {
                    if (this.masterGain && crossfadeTime > 0) {
                        let cur = this.masterGain.gain.value;
                        let now = this.ctx.currentTime;
                        this.masterGain.gain.setValueAtTime(cur, now);
                        this.masterGain.gain.linearRampToValueAtTime(0.001, now + (crossfadeTime / 2));
                        setTimeout(() => {
                            window.ytPlayer.loadVideoById(id);
                            if (window.__winamp && window.__winamp.masterGain) {
                                window.__winamp.masterGain.gain.linearRampToValueAtTime(cur, window.__winamp.ctx.currentTime + (crossfadeTime / 2));
                            }
                        }, crossfadeTime * 450);
                    } else {
                        window.ytPlayer.loadVideoById(id);
                    }
                }
            },

            play: function() {
                if (this.ctx && this.ctx.state === 'suspended') {
                    this.ctx.resume();
                }
                if (window.ytPlayer && typeof window.ytPlayer.playVideo === 'function') {
                    window.ytPlayer.playVideo();
                } else {
                    let v = document.querySelector('video');
                    if (v) v.play();
                }
            },

            pause: function() {
                if (window.ytPlayer && typeof window.ytPlayer.pauseVideo === 'function') {
                    window.ytPlayer.pauseVideo();
                } else {
                    let v = document.querySelector('video');
                    if (v) v.pause();
                }
            },

            stop: function() {
                if (window.ytPlayer && typeof window.ytPlayer.stopVideo === 'function') {
                    window.ytPlayer.stopVideo();
                } else {
                    let v = document.querySelector('video');
                    if (v) { v.pause(); v.currentTime = 0; }
                }
            },

            seek: function(sec) {
                if (window.ytPlayer && typeof window.ytPlayer.seekTo === 'function') {
                    window.ytPlayer.seekTo(sec, true);
                } else {
                    let v = document.querySelector('video');
                    if (v) v.currentTime = sec;
                }
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

        // Load YouTube IFrame Player with Origin set to https://www.youtube.com
        let initialVideoId = engine.currentTrack?.videoId ?? "dQw4w9WgXcQ"
        let html = generatePlayerHTML(videoId: initialVideoId)
        webView.loadHTMLString(html, baseURL: URL(string: "https://www.youtube.com")!)

        return webView
    }

    public func updateUIView(_ uiView: WKWebView, context: Context) {
        if engine.webView != uiView {
            engine.webView = uiView
        }
    }

    private func generatePlayerHTML(videoId: String) -> String {
        return """
        <!DOCTYPE html>
        <html>
        <head>
        <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no, viewport-fit=cover">
        <style>
          * { margin:0; padding:0; box-sizing:border-box; background-color:#000; overflow:hidden; }
          html, body { width:100%; height:100%; }
          #player, iframe { width:100% !important; height:100% !important; border:none; pointer-events:auto; }
          .ytp-chrome-top, .ytp-chrome-bottom, .ytp-watermark { display:none !important; }
        </style>
        </head>
        <body>
        <div id="player"></div>
        <script>
          var tag = document.createElement('script');
          tag.src = "https://www.youtube.com/iframe_api";
          var firstScriptTag = document.getElementsByTagName('script')[0];
          firstScriptTag.parentNode.insertBefore(tag, firstScriptTag);

          window.ytPlayer = null;
          function onYouTubeIframeAPIReady() {
            window.ytPlayer = new YT.Player('player', {
              height: '100%',
              width: '100%',
              videoId: '\(videoId)',
              playerVars: {
                'autoplay': 1,
                'playsinline': 1,
                'controls': 0,
                'rel': 0,
                'modestbranding': 1,
                'enablejsapi': 1,
                'origin': 'https://www.youtube.com'
              },
              events: {
                'onReady': function(e) {
                  e.target.playVideo();
                  window.__winamp?.initAudio();
                },
                'onStateChange': function(e) {
                  if (e.data === YT.PlayerState.ENDED) {
                    window.webkit?.messageHandlers?.winampBridge?.postMessage({ action: 'trackEnded' });
                  }
                },
                'onError': function(e) {
                  console.log('YT player error code:', e.data);
                }
              }
            });
          }
        </script>
        </body>
        </html>
        """
    }

    public class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        var parent: WebPlayerView

        init(_ parent: WebPlayerView) {
            self.parent = parent
        }

        public func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            if message.name == "winampBridge", let dict = message.body as? [String: Any] {
                if let action = dict["action"] as? String {
                    if action == "trackEnded" {
                        DispatchQueue.main.async {
                            self.parent.engine.nextTrack()
                        }
                    }
                }
            }
        }
    }
}
