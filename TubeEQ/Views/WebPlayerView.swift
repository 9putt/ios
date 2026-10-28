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
        config.mediaTypesRequiringUserActionForPlayback = []
        config.websiteDataStore = WKWebsiteDataStore.default()

        let contentController = WKUserContentController()
        contentController.add(context.coordinator, name: "winampBridge")

        let scriptSource = """
        // Keep video completely muted so all audio is handled 100% by CoreAudio NativeAudioEngine
        setInterval(function() {
            let v = document.querySelector('video');
            if (v) {
                v.muted = true;
                v.volume = 0;
            }
            let p = document.getElementById('movie_player');
            if (p && typeof p.mute === 'function') {
                p.mute();
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
        return webView
    }

    public func updateUIView(_ uiView: WKWebView, context: Context) {}

    public class Coordinator: NSObject, WKScriptMessageHandler {
        var parent: WebPlayerView
        init(_ parent: WebPlayerView) {
            self.parent = parent
        }
        public func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {}
    }
}
