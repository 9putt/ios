import SwiftUI
import WebKit

public struct MainContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var currentUrlString: String = "https://m.youtube.com"
    @State private var canGoBack: Bool = false
    @State private var canGoForward: Bool = false
    @State private var webView: WKWebView? = nil
    
    // UI & Audio States
    @State private var showEqualizerDrawer: Bool = false
    @State private var drawerDragOffset: CGFloat = 0
    @State private var showPlaylistSheet: Bool = false
    @State private var isBassBoostActive: Bool = false
    @State private var isVocalRemoverActive: Bool = false
    @ObservedObject private var audioManager = AudioEngineManager.shared

    public var body: some View {
        ZStack(alignment: .bottom) {
            
            // 1. MAIN VIEWPORT (Top bar, Fullscreen WebPlayer, Bottom controls)
            VStack(spacing: 0) {
                
                // TOP APP BAR: "Tube EQ Pro" brand header
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

                // FULLSCREEN YOUTUBE WEBVIEW
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

                // SLIM NATIVE BOTTOM CONTROLS
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

                    // Equalizer Button (Toggles Custom Slide-Over Drawer)
                    Button(action: {
                        let gen = UIImpactFeedbackGenerator(style: .medium)
                        gen.impactOccurred()
                        webView?.evaluateJavaScript("window.__tubeEQ?.userGestureInit();", completionHandler: nil)
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                            showEqualizerDrawer.toggle()
                        }
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

            // 2. DIMMED BACKDROP (Tap to close)
            if showEqualizerDrawer {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                    .transition(.opacity)
                    .onTapGesture {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                            showEqualizerDrawer = false
                        }
                    }

                // 3. CUSTOM EQUALIZER BOTTOM DRAWER
                VStack(spacing: 0) {
                    
                    // TOP DRAG HANDLE & HEADER BAR (The ONLY area that accepts vertical drag to dismiss!)
                    VStack(spacing: 8) {
                        Capsule()
                            .fill(Color.white.opacity(0.35))
                            .frame(width: 42, height: 5)
                            .padding(.top, 10)

                        HStack {
                            HStack(spacing: 6) {
                                Image(systemName: "slider.vertical.3")
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundColor(.cyan)
                                Text("TubeEQ Audio Studio")
                                    .font(.system(size: 15, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)
                            }

                            Spacer()

                            Button(action: {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                                    showEqualizerDrawer = false
                                }
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 22))
                                    .foregroundColor(.white.opacity(0.6))
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 6)
                    }
                    .frame(maxWidth: .infinity)
                    .background(Color(red: 0.12, green: 0.12, blue: 0.16))
                    .contentShape(Rectangle())
                    // Attach DragGesture STRICTLY to the top bar!
                    .gesture(
                        DragGesture()
                            .onChanged { val in
                                if val.translation.height > 0 {
                                    drawerDragOffset = val.translation.height
                                }
                            }
                            .onEnded { val in
                                if val.translation.height > 80 {
                                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                                        showEqualizerDrawer = false
                                    }
                                }
                                drawerDragOffset = 0
                            }
                    )

                    Divider().background(Color.white.opacity(0.1))

                    // DRAWER BODY (Sliders, Vocal Remover, Presets)
                    // Sliders can be dragged freely without the drawer sliding up/down!
                    EqualizerView(isVocalRemoverActive: $isVocalRemoverActive, webView: webView)
                        .padding(.bottom, 24)
                }
                .frame(maxWidth: .infinity)
                .background(Color(red: 0.08, green: 0.08, blue: 0.12))
                .cornerRadius(24, corners: [.topLeft, .topRight])
                .offset(y: max(0, drawerDragOffset))
                .transition(.move(edge: .bottom))
            }
        }
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

// MARK: - Extension for Corner Radius
extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(roundedRect: rect, byRoundingCorners: corners, cornerRadii: CGSize(width: radius, height: radius))
        return Path(path.cgPath)
    }
}
