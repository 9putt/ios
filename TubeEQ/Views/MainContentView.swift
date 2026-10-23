import SwiftUI
import WebKit

public struct MainContentView: View {
    @State private var currentUrlString: String = "https://m.youtube.com"
    @State private var canGoBack: Bool = false
    @State private var canGoForward: Bool = false
    @State private var webView: WKWebView? = nil
    
    // UI States
    @State private var showEqualizerSheet: Bool = false
    @State private var showPlaylistSheet: Bool = false
    @State private var isBassBoostActive: Bool = false
    @ObservedObject private var audioManager = AudioEngineManager.shared

    public var body: some View {
        ZStack(alignment: .bottom) {
            // 1. FULLSCREEN WEBVIEW: Takes 100% of the screen (Edge-to-Edge)
            WebPlayerView(
                currentUrlString: $currentUrlString,
                canGoBack: $canGoBack,
                canGoForward: $canGoForward,
                webViewRef: { view in
                    self.webView = view
                }
            )
            .edgesIgnoringSafeArea(.all)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.black.edgesIgnoringSafeArea(.all))

            // 2. SLIM, ELEGANT BOTTOM BAR (Height fixed to 50pt, frosted glass)
            HStack(spacing: 0) {
                // Back Button
                Button(action: { webView?.goBack() }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(canGoBack ? .white : .white.opacity(0.3))
                        .frame(width: 44, height: 44)
                }
                .disabled(!canGoBack)
                .frame(maxWidth: .infinity)

                // Forward Button
                Button(action: { webView?.goForward() }) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(canGoForward ? .white : .white.opacity(0.3))
                        .frame(width: 44, height: 44)
                }
                .disabled(!canGoForward)
                .frame(maxWidth: .infinity)

                // Reload Button
                Button(action: { webView?.reload() }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundColor(.white.opacity(0.85))
                        .frame(width: 44, height: 44)
                }
                .frame(maxWidth: .infinity)

                // Equalizer Button (Glowing Cyan Circle with Icon)
                Button(action: {
                    let gen = UIImpactFeedbackGenerator(style: .medium)
                    gen.impactOccurred()
                    showEqualizerSheet.toggle()
                }) {
                    ZStack {
                        Circle()
                            .fill(LinearGradient(colors: [.cyan, .blue], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 42, height: 42)
                            .shadow(color: .cyan.opacity(0.5), radius: 6)

                        Image(systemName: "slider.vertical.3")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.black)
                    }
                }
                .frame(maxWidth: .infinity)

                // Quick Bass Boost Toggle
                Button(action: {
                    let gen = UIImpactFeedbackGenerator(style: .heavy)
                    gen.impactOccurred()
                    isBassBoostActive.toggle()
                    if isBassBoostActive {
                        audioManager.applyPreset(.bassBoost)
                    } else {
                        audioManager.resetEQ()
                    }
                }) {
                    ZStack {
                        Circle()
                            .fill(isBassBoostActive ? Color.purple : Color.white.opacity(0.12))
                            .frame(width: 42, height: 42)
                            .shadow(color: isBassBoostActive ? Color.purple.opacity(0.6) : .clear, radius: 6)

                        Image(systemName: "speaker.wave.3.fill")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(isBassBoostActive ? .white : .white.opacity(0.7))
                    }
                }
                .frame(maxWidth: .infinity)

                // Picture in Picture
                Button(action: {
                    let js = "document.querySelector('video')?.requestPictureInPicture?.();"
                    webView?.evaluateJavaScript(js, completionHandler: nil)
                }) {
                    Image(systemName: "pip.enter")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.white.opacity(0.85))
                        .frame(width: 44, height: 44)
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 12)
            .padding(.top, 8)
            .padding(.bottom, 22)
            .frame(maxWidth: .infinity)
            .frame(height: 72)
            .background(.ultraThinMaterial)
            .overlay(
                Rectangle()
                    .frame(height: 0.5)
                    .foregroundColor(Color.white.opacity(0.2)),
                alignment: .top
            )
        }
        .preferredColorScheme(.dark)
        // Equalizer Bottom Sheet (Half screen overlay, video keeps playing smoothly behind it!)
        .sheet(isPresented: $showEqualizerSheet) {
            EqualizerSheetContainer()
        }
        .sheet(isPresented: $showPlaylistSheet) {
            PlaylistView(onSelectUrl: { selectedUrl in
                if let url = URL(string: selectedUrl) {
                    webView?.load(URLRequest(url: url))
                }
                showPlaylistSheet = false
            })
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
    }
}

// MARK: - Equalizer Sheet Container with iOS 16.4+ Background Interaction
struct EqualizerSheetContainer: View {
    var body: some View {
        if #available(iOS 16.4, *) {
            EqualizerView()
                .presentationDetents([.fraction(0.55), .large])
                .presentationDragIndicator(.visible)
                .presentationBackgroundInteraction(.enabled(upThrough: .fraction(0.55)))
        } else {
            EqualizerView()
                .presentationDetents([.fraction(0.55), .large])
                .presentationDragIndicator(.visible)
        }
    }
}
