import SwiftUI
import WebKit

public struct EqualizerView: View {
    @ObservedObject var audioManager = AudioEngineManager.shared
    @Binding var isVocalRemoverActive: Bool
    var webView: WKWebView? = nil
    
    // Formatting frequency display
    private func formatFrequency(_ freq: Float) -> String {
        if freq >= 1000 {
            return "\(Int(freq / 1000))k"
        } else {
            return "\(Int(freq))"
        }
    }

    public var body: some View {
        ZStack {
            // Dark futuristic gradient background
            LinearGradient(
                colors: [Color(red: 0.08, green: 0.09, blue: 0.14), Color(red: 0.03, green: 0.04, blue: 0.07)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {
                    
                    // 1. Header with Title & Reset
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("AUDIO STUDIO")
                                .font(.system(size: 11, weight: .black, design: .monospaced))
                                .foregroundColor(.cyan)
                                .tracking(2)
                            Text("Equalizer & Vocal Remover")
                                .font(.system(size: 19, weight: .bold))
                                .foregroundColor(.white)
                        }

                        Spacer()

                        Button(action: {
                            let gen = UIImpactFeedbackGenerator(style: .rigid)
                            gen.impactOccurred()
                            audioManager.resetEQ()
                            for i in 0..<audioManager.bandFrequencies.count {
                                webView?.evaluateJavaScript("window.__tubeEQ?.setGain(\(i), 0.0);", completionHandler: nil)
                            }
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.counterclockwise")
                                Text("Reset")
                            }
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white.opacity(0.9))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(Color.white.opacity(0.12))
                            .cornerRadius(14)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)

                    // 2. FEATURE: Vocal Remover (ตัดเสียงร้อง Karaoke Mode)
                    Button(action: {
                        let gen = UIImpactFeedbackGenerator(style: .heavy)
                        gen.impactOccurred()
                        isVocalRemoverActive.toggle()
                        webView?.evaluateJavaScript("window.__tubeEQ?.setVocalRemover(\(isVocalRemoverActive));", completionHandler: nil)
                    }) {
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(isVocalRemoverActive ? Color.red : Color.white.opacity(0.12))
                                    .frame(width: 44, height: 44)
                                    .shadow(color: isVocalRemoverActive ? Color.red.opacity(0.6) : .clear, radius: 8)

                                Image(systemName: isVocalRemoverActive ? "mic.slash.fill" : "mic.fill")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(.white)
                            }

                            VStack(alignment: .leading, spacing: 3) {
                                Text("Vocal Remover (ตัดเสียงร้อง)")
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundColor(.white)
                                Text(isVocalRemoverActive ? "โหมดคาราโอเกะ (ตัดเสียงร้องตรงกลาง)" : "แตะเพื่อเปิดโหมดตัดเสียงร้อง")
                                    .font(.system(size: 12))
                                    .foregroundColor(isVocalRemoverActive ? .red.opacity(0.9) : .gray)
                            }

                            Spacer()

                            Toggle("", isOn: Binding(
                                get: { isVocalRemoverActive },
                                set: { val in
                                    isVocalRemoverActive = val
                                    webView?.evaluateJavaScript("window.__tubeEQ?.setVocalRemover(\(val));", completionHandler: nil)
                                }
                            ))
                            .labelsHidden()
                            .tint(.red)
                        }
                        .padding(14)
                        .background(.ultraThinMaterial)
                        .cornerRadius(20)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(isVocalRemoverActive ? Color.red.opacity(0.5) : Color.white.opacity(0.1), lineWidth: 1.2)
                        )
                        .padding(.horizontal, 16)
                    }

                    // 3. Horizontal Preset Pills (Bass, Rock, Pop, Jazz, etc.)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(EqualizerPreset.allCases) { preset in
                                let isSelected = audioManager.currentPreset == preset
                                Button(action: {
                                    let gen = UIImpactFeedbackGenerator(style: .light)
                                    gen.impactOccurred()
                                    audioManager.applyPreset(preset)
                                    // Send gains to WebView
                                    for (i, gain) in preset.gains.enumerated() {
                                        webView?.evaluateJavaScript("window.__tubeEQ?.setGain(\(i), \(gain));", completionHandler: nil)
                                    }
                                }) {
                                    Text(preset.rawValue)
                                        .font(.system(size: 13, weight: isSelected ? .bold : .medium))
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 8)
                                        .background(
                                            isSelected ?
                                                AnyView(LinearGradient(colors: [.cyan, .blue], startPoint: .topLeading, endPoint: .bottomTrailing)) :
                                                AnyView(Color.white.opacity(0.08))
                                        )
                                        .foregroundColor(isSelected ? .black : .white)
                                        .cornerRadius(20)
                                        .shadow(color: isSelected ? .cyan.opacity(0.4) : .clear, radius: 8)
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                    }

                    // 4. 10-Band Sliders Card (Connected to Web Audio Filter Nodes)
                    VStack(alignment: .leading, spacing: 14) {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 16) {
                                ForEach(0..<audioManager.bandFrequencies.count, id: \.self) { index in
                                    VStack(spacing: 6) {
                                        let gain = audioManager.bandGains[index]
                                        Text(String(format: "%+.1f", gain))
                                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                                            .foregroundColor(gain > 0 ? .cyan : (gain < 0 ? .purple : .gray))
                                            .frame(height: 14)

                                        // Vertical slider
                                        Slider(
                                            value: Binding(
                                                get: { Double(audioManager.bandGains[index]) },
                                                set: { newVal in
                                                    audioManager.setGain(forBand: index, gain: Float(newVal))
                                                    webView?.evaluateJavaScript("window.__tubeEQ?.setGain(\(index), \(newVal));", completionHandler: nil)
                                                }
                                            ),
                                            in: -15.0...15.0,
                                            step: 0.5
                                        )
                                        .rotationEffect(.degrees(-90))
                                        .frame(width: 140, height: 40)
                                        .tint(gain >= 0 ? .cyan : .purple)
                                        .padding(.vertical, 50)

                                        // Frequency label
                                        Text(formatFrequency(audioManager.bandFrequencies[index]))
                                            .font(.system(size: 11, weight: .bold))
                                            .foregroundColor(.white)
                                    }
                                    .frame(width: 48)
                                    .padding(.vertical, 8)
                                    .background(Color.black.opacity(0.3))
                                    .cornerRadius(12)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color.white.opacity(0.06), lineWidth: 1)
                                    )
                                }
                            }
                            .padding(.horizontal, 16)
                        }
                    }
                    .padding(.vertical, 16)
                    .background(.ultraThinMaterial)
                    .cornerRadius(24)
                    .padding(.horizontal, 16)

                    Spacer(minLength: 24)
                }
            }
        }
    }
}
