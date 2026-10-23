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

        // Enable HTML5 Element Fullscreen
        if #available(iOS 15.4, *) {
            configuration.preferences.isElementFullscreenEnabled = true
        }

        // Script to prevent auto-pausing when tab changes / loses focus, and optimize for full width
        let userScriptSource = """
        // 1. Viewport configuration
        let meta = document.createElement('meta');
        meta.name = 'viewport';
        meta.content = 'width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no, viewport-fit=cover';
        document.getElementsByTagName('head')[0]?.appendChild(meta);

        // 2. Prevent background pausing by faking visibilityState
        try {
            Object.defineProperty(document, 'hidden', { value: false, writable: false });
            Object.defineProperty(document, 'visibilityState', { value: 'visible', writable: false });
            document.addEventListener('visibilitychange', function(e) {
                e.stopImmediatePropagation();
            }, true);
        } catch(e) {}

        // 3. Keep video playing even if window blurs
        window.addEventListener('blur', function(e) {
            e.stopImmediatePropagation();
        }, true);

        // 4. Style adjustments for native toolbar padding
        let style = document.createElement('style');
        style.textContent = `
            ytm-pivot-bar-renderer { padding-bottom: 60px !important; }
            ytm-app-promo, .ytm-app-promo-renderer { display: none !important; }
        `;
        document.head.appendChild(style);
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
            }
        }
    }
}
