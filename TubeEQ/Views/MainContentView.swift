import SwiftUI
import WebKit

public struct MainContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var currentUrlString: String = "https://m.youtube.com"
    @State private var canGoBack: Bool = false
    @State private var canGoForward: Bool = false
    @State private var webView: WKWebView? = nil
    
    // UI & Audio States
    @State private var showEqualizerSheet: Bool = false
    @State private var showPlaylistSheet: Bool = false
    @State private var isBassBoostActive: Bool = false
    @State private var isVocalRemoverActive: Bool = false
    @ObservedObject private var audioManager = AudioEngineManager.shared

    public var body: some View {
        VStack(spacing: 0) {
            
            // 1. TOP APP BAR: "Tube EQ Pro" brand header (Pushes content down safely below the notch!)
            HStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(LinearGradient(colors: [.cyan, .blue], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 26, height: 26)
                    Image(systemName: "waveform")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.black)
                }

                Text("Tube EQ Pro")
                    .font(.system(size: 16, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                    .tracking(0.5)

                if isVocalRemoverActive {
                    Text("KARAOKE")
                        .font(.system(size: 9, weight: .black))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.red)
                        .foregroundColor(.white)
                        .cornerRadius(6)
                }

                if isBassBoostActive {
                    Text("BASS")
                        .font(.system(size: 9, weight: .black))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.purple)
                        .foregroundColor(.white)
                        .cornerRadius(6)
                }

                Spacer()

                // Reload button on top right
                Button(action: { webView?.reload() }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white.opacity(0.8))
                        .padding(6)
                        .background(Color.white.opacity(0.08))
                        .clipShape(Circle())
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 46) // Clears iPhone Dynamic Island / Notch
            .padding(.bottom, 8)
            .background(Color(red: 0.06, green: 0.06, blue: 0.08))

            // 2. FULLSCREEN YOUTUBE WEBVIEW
            WebPlayerView(
                currentUrlString: $currentUrlString,
                canGoBack: $canGoBack,
                canGoForward: $canGoForward,
                webViewRef: { view in
                    self.webView = view
                }
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.black)

            // 3. SLIM NATIVE BOTTOM CONTROLS
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

                // Equalizer Button (Opens Bottom Sheet over YouTube)
                Button(action: {
                    let gen = UIImpactFeedbackGenerator(style: .medium)
                    gen.impactOccurred()
                    // Unlock audio context via direct user gesture
                    webView?.evaluateJavaScript("window.__tubeEQ?.userGestureInit();", completionHandler: nil)
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
                    webView?.evaluateJavaScript("window.__tubeEQ?.setBassBoost(\(isBassBoostActive));", completionHandler: nil)
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

                // Picture-in-Picture (Enables 100% Background & Lock Screen Playback on iOS)
                Button(action: {
                    let gen = UIImpactFeedbackGenerator(style: .light)
                    gen.impactOccurred()
                    let js = """
                    let v = document.querySelector('video');
                    if (v) {
                        if (document.pictureInPictureElement) {
                            document.exitPictureInPicture?.();
                        } else if (v.requestPictureInPicture) {
                            v.requestPictureInPicture().catch(() => {});
                        } else if (v.webkitSetPresentationMode) {
                            v.webkitSetPresentationMode('picture-in-picture');
                        }
                    }
                    """
                    webView?.evaluateJavaScript(js, completionHandler: nil)
                }) {
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.12))
                            .frame(width: 42, height: 42)

                        Image(systemName: "pip.enter")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.cyan)
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 12)
            .padding(.top, 6)
            .padding(.bottom, 20)
            .frame(maxWidth: .infinity)
            .frame(height: 70)
            .background(Color(red: 0.08, green: 0.08, blue: 0.11))
            .overlay(
                Rectangle()
                    .frame(height: 0.5)
                    .foregroundColor(Color.white.opacity(0.15)),
                alignment: .top
            )
        }
        .ignoresSafeArea(.all, edges: [.top, .bottom])
        .preferredColorScheme(.dark)
        // Automatic Background Playback Trigger (Only if video is currently playing)
        .onChange(of: scenePhase) { newPhase in
            if newPhase == .background || newPhase == .inactive {
                let js = """
                let v = document.querySelector('video');
                if (v && !v.paused && !v.ended) {
                    if (!document.pictureInPictureElement && v.webkitSetPresentationMode) {
                        v.webkitSetPresentationMode('picture-in-picture');
                    }
                }
                """
                webView?.evaluateJavaScript(js, completionHandler: nil)
            }
        }
        .sheet(isPresented: $showEqualizerSheet) {
            EqualizerSheetContainer(isVocalRemoverActive: $isVocalRemoverActive, webView: webView)
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
    @Binding var isVocalRemoverActive: Bool
    var webView: WKWebView? = nil

    var body: some View {
        if #available(iOS 16.4, *) {
            EqualizerView(isVocalRemoverActive: $isVocalRemoverActive, webView: webView)
                .presentationDetents([.fraction(0.6), .large])
                .presentationDragIndicator(.visible)
                .presentationBackgroundInteraction(.enabled(upThrough: .fraction(0.6)))
        } else {
            EqualizerView(isVocalRemoverActive: $isVocalRemoverActive, webView: webView)
                .presentationDetents([.fraction(0.6), .large])
                .presentationDragIndicator(.visible)
        }
    }
}
