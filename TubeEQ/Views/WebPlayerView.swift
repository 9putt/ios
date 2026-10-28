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
        config.userContentController = contentController

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.isOpaque = false
        webView.backgroundColor = .black
        webView.scrollView.isScrollEnabled = false
        webView.navigationDelegate = context.coordinator

        // Load self-contained YouTube IFrame player with zero-touch autoplay & WebAudio DSP
        let initialVid = engine.currentTrack?.videoId ?? "jfKfPfyJRdk"
        let html = Self.generatePlayerHTML(initialVideoId: initialVid)
        webView.loadHTMLString(html, baseURL: URL(string: "https://www.youtube.com"))

        // Store reference in player engine
        engine.webView = webView
        return webView
    }

    public func updateUIView(_ uiView: WKWebView, context: Context) {}

    private static func generatePlayerHTML(initialVideoId: String) -> String {
        return """
        <!DOCTYPE html>
        <html>
        <head>
        <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
        <style>
          * { margin:0; padding:0; background:#000000; overflow:hidden; }
          html, body, #player { width:100%; height:100%; }
          iframe { width:100% !important; height:100% !important; border:none !important; }
        </style>
        </head>
        <body>
        <div id="player"></div>
        <script>
          var tag = document.createElement('script');
          tag.src = "https://www.youtube.com/iframe_api";
          var firstScriptTag = document.getElementsByTagName('script')[0];
          firstScriptTag.parentNode.insertBefore(tag, firstScriptTag);

          var player = null;
          var isReady = false;
          var pendingVideoId = '\(initialVideoId)';

          function onYouTubeIframeAPIReady() {
            player = new YT.Player('player', {
              height: '100%',
              width: '100%',
              videoId: pendingVideoId || 'jfKfPfyJRdk',
              playerVars: {
                'autoplay': 1,
                'playsinline': 1,
                'controls': 0,
                'rel': 0,
                'fs': 0,
                'modestbranding': 1,
                'iv_load_policy': 3,
                'origin': 'https://www.youtube.com'
              },
              events: {
                'onReady': onPlayerReady,
                'onStateChange': onPlayerStateChange,
                'onError': onPlayerError
              }
            });
          }

          function onPlayerReady(event) {
            isReady = true;
            if (window.__winamp && window.__winamp.targetVolume !== undefined) {
              player.setVolume(window.__winamp.targetVolume);
            }
            if (pendingVideoId) {
              player.loadVideoById({ videoId: pendingVideoId, startSeconds: 0 });
              player.playVideo();
              pendingVideoId = null;
            }
          }

          function onPlayerStateChange(event) {
            if (event.data === 0) { // ENDED
              window.webkit?.messageHandlers?.winampBridge?.postMessage({ action: 'trackEnded' });
            }
          }

          function onPlayerError(event) {
            window.webkit?.messageHandlers?.winampBridge?.postMessage({ action: 'trackError', code: event.data });
          }

          // WebAudio DSP for 10-Band EQ & Stereo Balance
          var audioCtx = null;
          var biquadBands = [];
          var stereoPanner = null;
          var eqFrequencies = [70, 180, 320, 600, 1000, 3000, 6000, 12000, 14000, 16000];

          function setupWebAudio() {
            if (audioCtx) return;
            try {
              var AC = window.AudioContext || window.webkitAudioContext;
              if (!AC) return;
              audioCtx = new AC();
              for (var i = 0; i < 10; i++) {
                var filter = audioCtx.createBiquadFilter();
                filter.frequency.value = eqFrequencies[i];
                filter.gain.value = 0;
                if (i === 0) filter.type = 'lowshelf';
                else if (i === 9) filter.type = 'highshelf';
                else filter.type = 'peaking';
                biquadBands.push(filter);
              }
              for (var i = 0; i < 9; i++) {
                biquadBands[i].connect(biquadBands[i + 1]);
              }
              if (audioCtx.createStereoPanner) {
                stereoPanner = audioCtx.createStereoPanner();
                biquadBands[9].connect(stereoPanner);
                stereoPanner.connect(audioCtx.destination);
              } else {
                biquadBands[9].connect(audioCtx.destination);
              }

              var v = document.querySelector('video');
              if (v) {
                var source = audioCtx.createMediaElementSource(v);
                source.connect(biquadBands[0]);
              }
            } catch(e) {}
          }

          window.__winamp = {
            baseVolume: 0.85,
            preampGain: 0.0,
            targetVolume: 85,
            hasTriggeredOutro: false,

            loadVideo: function(id, fadeTime) {
              this.hasTriggeredOutro = false;
              if (isReady && player && typeof player.loadVideoById === 'function') {
                player.loadVideoById({ videoId: id, startSeconds: 0 });
                player.playVideo();
              } else {
                pendingVideoId = id;
              }
              setupWebAudio();
            },

            play: function() {
              if (player && typeof player.playVideo === 'function') {
                player.playVideo();
              }
              if (audioCtx && audioCtx.state === 'suspended') {
                audioCtx.resume();
              }
            },

            pause: function() {
              if (player && typeof player.pauseVideo === 'function') {
                player.pauseVideo();
              }
            },

            stop: function() {
              if (player && typeof player.stopVideo === 'function') {
                player.stopVideo();
              }
            },

            seek: function(sec) {
              if (player && typeof player.seekTo === 'function') {
                player.seekTo(sec, true);
              }
            },

            setVolume: function(vol) {
              this.baseVolume = Math.max(0.0, Math.min(1.0, vol));
              this.updateEffectiveVolume();
            },

            setPreamp: function(gain) {
              this.preampGain = gain;
              this.updateEffectiveVolume();
            },

            updateEffectiveVolume: function() {
              var mult = Math.pow(10.0, this.preampGain / 20.0);
              var eff = Math.max(0.0, Math.min(1.0, this.baseVolume * mult));
              this.targetVolume = Math.round(eff * 100);
              if (player && typeof player.setVolume === 'function') {
                player.setVolume(this.targetVolume);
                if (this.targetVolume > 0 && typeof player.unMute === 'function') {
                  player.unMute();
                }
              }
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

          // Synchronize time & duration to Winamp 7-Segment display every 150ms
          setInterval(function() {
            if (!player || !isReady) return;
            try {
              var cur = 0;
              var dur = 0;
              var state = -1;

              if (typeof player.getCurrentTime === 'function') cur = player.getCurrentTime() || 0;
              if (typeof player.getDuration === 'function') dur = player.getDuration() || 0;
              if (typeof player.getPlayerState === 'function') state = player.getPlayerState();

              if (cur > 0 || state === 1) {
                window.webkit?.messageHandlers?.winampBridge?.postMessage({
                  action: 'timeUpdate',
                  currentTime: cur,
                  duration: dur,
                  isPlaying: (state === 1)
                });

                // Smart outro credit skip in final 4 seconds
                if (dur > 20 && (dur - cur) <= 4.0 && !window.__winamp.hasTriggeredOutro) {
                  window.__winamp.hasTriggeredOutro = true;
                  window.webkit?.messageHandlers?.winampBridge?.postMessage({ action: 'smartOutro' });
                }
              }
            } catch(e) {}
          }, 150);
        </script>
        </body>
        </html>
        """
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

                case "trackError":
                    print("[WinampBridge] Video playback error. Skipping to next track.")
                    engine.nextTrack()

                default:
                    break
                }
            }
        }
    }
}
