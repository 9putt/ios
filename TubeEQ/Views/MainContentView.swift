import SwiftUI
import WebKit

public struct MainContentView: View {
    @State private var selectedTab: Int = 0
    @State private var currentUrlString: String = "https://m.youtube.com"
    @State private var urlInput: String = "https://m.youtube.com"
    @State private var canGoBack: Bool = false
    @State private var canGoForward: Bool = false
    @State private var webView: WKWebView? = nil

    public var body: some View {
        TabView(selection: $selectedTab) {
            
            // Tab 1: Web Player
            VStack(spacing: 0) {
                // Top Navigation Bar
                HStack(spacing: 12) {
                    Button(action: { webView?.goBack() }) {
                        Image(systemName: "chevron.left")
                            .foregroundColor(canGoBack ? .white : .gray)
                    }
                    .disabled(!canGoBack)

                    Button(action: { webView?.goForward() }) {
                        Image(systemName: "chevron.right")
                            .foregroundColor(canGoForward ? .white : .gray)
                    }
                    .disabled(!canGoForward)

                    Button(action: { webView?.reload() }) {
                        Image(systemName: "arrow.clockwise")
                            .foregroundColor(.white)
                    }

                    TextField("Search or Enter URL", text: $urlInput, onCommit: {
                        navigateToUrl(urlInput)
                    })
                    .padding(8)
                    .background(Color(white: 0.18))
                    .foregroundColor(.white)
                    .cornerRadius(8)
                    .keyboardType(.URL)
                    .autocapitalization(.none)
                }
                .padding()
                .background(Color(red: 0.1, green: 0.11, blue: 0.15))

                // Embedded WebKit Player
                WebPlayerView(
                    currentUrlString: $currentUrlString,
                    canGoBack: $canGoBack,
                    canGoForward: $canGoForward,
                    webViewRef: { view in
                        self.webView = view
                    }
                )
            }
            .tabItem {
                Label("Player", systemImage: "play.tv")
            }
            .tag(0)

            // Tab 2: Equalizer Pro
            EqualizerView()
                .tabItem {
                    Label("Equalizer", systemImage: "waveform")
                }
                .tag(1)

            // Tab 3: Playlists
            PlaylistView(onSelectUrl: { selectedUrl in
                navigateToUrl(selectedUrl)
                selectedTab = 0
            })
            .tabItem {
                Label("Playlists", systemImage: "list.bullet.rectangle")
            }
            .tag(2)
        }
        .accentColor(.cyan)
        .preferredColorScheme(.dark)
    }

    private func navigateToUrl(_ input: String) {
        var formatted = input.trimmingCharacters(in: .whitespacesAndNewlines)
        if !formatted.lowercased().hasPrefix("http://") && !formatted.lowercased().hasPrefix("https://") {
            if formatted.contains(".") && !formatted.contains(" ") {
                formatted = "https://" + formatted
            } else {
                formatted = "https://www.google.com/search?q=" + formatted.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!
            }
        }
        currentUrlString = formatted
        urlInput = formatted
        if let url = URL(string: formatted) {
            webView?.load(URLRequest(url: url))
        }
    }
}
