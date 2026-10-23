import SwiftUI
import WebKit

public struct MainContentView: View {
    @State private var currentUrlString: String = "https://m.youtube.com"
    @State private var urlInput: String = "https://m.youtube.com"
    @State private var canGoBack: Bool = false
    @State private var canGoForward: Bool = false
    @State private var webView: WKWebView? = nil
    
    // UI States
    @State private var showEqualizerSheet: Bool = false
    @State private var showPlaylistSheet: Bool = false
    @State private var isFullScreenMode: Bool = false
    @State private var showTopBar: Bool = true
    
    // Quick Bass Boost State
    @State private var isBassBoostActive: Bool = false
    @ObservedObject private var audioManager = AudioEngineManager.shared

    public var body: some View {
        ZStack {
            // 1. BASE: Fullscreen Web Player (Edge to Edge)
            WebPlayerView(
                currentUrlString: $currentUrlString,
                canGoBack: $canGoBack,
                canGoForward: $canGoForward,
                webViewRef: { view in
                    self.webView = view
                }
            )
            .ignoresSafeArea()
            .background(Color.black)

            // 2. OVERLAYS (Floating Controls)
            VStack {
                // Top Floating Search / Address Bar
                if showTopBar && !isFullScreenMode {
                    topFloatingBar
                        .transition(.move(edge: .top).combined(with: .opacity))
                }

                Spacer()

                // Bottom Floating Control Island (Frosted Glass & Neon)
                if !isFullScreenMode {
                    bottomFloatingIsland
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)

            // Fullscreen Exit Floating Button
            if isFullScreenMode {
                VStack {
                    HStack {
                        Spacer()
                        Button(action: {
                            withAnimation(.spring()) {
                                isFullScreenMode = false
                            }
                        }) {
                            Image(systemName: "arrow.down.right.and.arrow.up.left")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.white)
                                .padding(12)
                                .background(.ultraThinMaterial)
                                .clipShape(Circle())
                                .shadow(color: .black.opacity(0.4), radius: 8)
                        }
                        .padding(.top, 44)
                        .padding(.trailing, 16)
                    }
                    Spacer()
                }
            }
        }
        .preferredColorScheme(.dark)
        // SHEET 1: Equalizer Pro (Half-Sheet / Bottom Sheet - Video NEVER pauses!)
        .sheet(isPresented: $showEqualizerSheet) {
            EqualizerSheetContainer()
        }
        // SHEET 2: Playlists & Bookmarks
        .sheet(isPresented: $showPlaylistSheet) {
            PlaylistView(onSelectUrl: { selectedUrl in
                navigateToUrl(selectedUrl)
                showPlaylistSheet = false
            })
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
    }

    // MARK: - Top Floating Address Bar
    private var topFloatingBar: some View {
        HStack(spacing: 10) {
            Button(action: { webView?.goBack() }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(canGoBack ? .cyan : .gray.opacity(0.6))
            }
            .disabled(!canGoBack)

            Button(action: { webView?.goForward() }) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(canGoForward ? .cyan : .gray.opacity(0.6))
            }
            .disabled(!canGoForward)

            Button(action: { webView?.reload() }) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.white.opacity(0.9))
            }

            // Search Field
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.gray)
                    .font(.system(size: 13))

                TextField("Search or URL...", text: $urlInput, onCommit: {
                    navigateToUrl(urlInput)
                })
                .font(.system(size: 14))
                .foregroundColor(.white)
                .keyboardType(.URL)
                .autocapitalization(.none)
                .disableAutocorrection(true)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(Color.white.opacity(0.1))
            .cornerRadius(20)

            // Fullscreen Button
            Button(action: {
                withAnimation(.spring()) {
                    isFullScreenMode = true
                }
            }) {
                Image(systemName: "arrow.up.left.and.arrow.down.right")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.cyan)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
        .cornerRadius(28)
        .overlay(
            RoundedRectangle(cornerRadius: 28)
                .stroke(Color.white.opacity(0.15), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.35), radius: 10, y: 4)
    }

    // MARK: - Bottom Floating Island Control Bar
    private var bottomFloatingIsland: some View {
        HStack(spacing: 20) {
            
            // 1. Equalizer Studio Trigger (with Animated Spectrum icon)
            Button(action: {
                showEqualizerSheet.toggle()
            }) {
                HStack(spacing: 8) {
                    AnimatedSpectrumBars()
                        .frame(width: 20, height: 16)
                    
                    Text("Equalizer")
                        .font(.system(size: 14, weight: .bold))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    LinearGradient(
                        colors: [Color.cyan.opacity(0.85), Color.blue.opacity(0.85)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .foregroundColor(.black)
                .cornerRadius(20)
                .shadow(color: .cyan.opacity(0.4), radius: 8)
            }

            // 2. Quick Bass Boost Toggle
            Button(action: {
                let generator = UIImpactFeedbackGenerator(style: .medium)
                generator.impactOccurred()
                isBassBoostActive.toggle()
                if isBassBoostActive {
                    audioManager.applyPreset(.bassBoost)
                } else {
                    audioManager.resetEQ()
                }
            }) {
                HStack(spacing: 5) {
                    Image(systemName: "speaker.wave.3.fill")
                        .font(.system(size: 13))
                    Text("Bass")
                        .font(.system(size: 12, weight: .semibold))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(isBassBoostActive ? Color.purple : Color.white.opacity(0.12))
                .foregroundColor(.white)
                .cornerRadius(18)
                .shadow(color: isBassBoostActive ? Color.purple.opacity(0.5) : Color.clear, radius: 6)
            }

            // 3. Playlists Drawer
            Button(action: {
                showPlaylistSheet = true
            }) {
                Image(systemName: "music.note.list")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(10)
                    .background(Color.white.opacity(0.12))
                    .clipShape(Circle())
            }

            // 4. Picture-in-Picture Trigger
            Button(action: {
                // Trigger PiP in web video via JS
                let js = "document.querySelector('video')?.requestPictureInPicture?.();"
                webView?.evaluateJavaScript(js, completionHandler: nil)
            }) {
                Image(systemName: "pip.enter")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(10)
                    .background(Color.white.opacity(0.12))
                    .clipShape(Circle())
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
        .cornerRadius(32)
        .overlay(
            RoundedRectangle(cornerRadius: 32)
                .stroke(
                    LinearGradient(
                        colors: [.white.opacity(0.3), .clear, .cyan.opacity(0.3)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.2
                )
        )
        .shadow(color: .black.opacity(0.5), radius: 16, y: 6)
        .padding(.bottom, 6)
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

// MARK: - Animated Soundwave Spectrum Visualizer (ลูกเล่นไฟเสียงเต้น)
struct AnimatedSpectrumBars: View {
    @State private var barHeights: [CGFloat] = [0.3, 0.7, 0.5, 0.9, 0.4]
    let timer = Timer.publish(every: 0.22, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(spacing: 2.5) {
            ForEach(0..<barHeights.count, id: \.self) { i in
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(Color.black)
                    .scaleEffect(y: barHeights[i], anchor: .bottom)
                    .animation(.easeInOut(duration: 0.2), value: barHeights[i])
            }
        }
        .onReceive(timer) { _ in
            barHeights = (0..<5).map { _ in CGFloat.random(in: 0.25...1.0) }
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
