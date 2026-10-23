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
        configuration.mediaTypesRequiringUserActionForPlayback = []
        
        let preferences = WKWebpagePreferences()
        preferences.allowsContentJavaScript = true
        configuration.defaultWebpagePreferences = preferences

        // Inject script to ensure viewport & responsive layout
        let userScriptSource = """
        let meta = document.createElement('meta');
        meta.name = 'viewport';
        meta.content = 'width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no';
        document.getElementsByTagName('head')[0]?.appendChild(meta);
        """
        let userScript = WKUserScript(source: userScriptSource, injectionTime: .atDocumentEnd, forMainFrameOnly: true)
        configuration.userContentController.addUserScript(userScript)

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true
        webView.scrollView.isScrollEnabled = true

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
        // Sync back/forward capabilities
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
