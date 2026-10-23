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
        VStack(spacing: 14) {
            
            // 1. FEATURE: Vocal Remover (ตัดเสียงร้อง Karaoke Mode)
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
                            .frame(width: 40, height: 40)
                            .shadow(color: isVocalRemoverActive ? Color.red.opacity(0.6) : .clear, radius: 8)

                        Image(systemName: isVocalRemoverActive ? "mic.slash.fill" : "mic.fill")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text("Vocal Remover")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundColor(.white)
                            if isVocalRemoverActive {
                                Text("ON")
                                    .font(.system(size: 9, weight: .black))
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 2)
                                    .background(Color.red)
                                    .foregroundColor(.white)
                                    .cornerRadius(4)
                            }
                        }
                        Text(isVocalRemoverActive ? "โหมดคาราโอเกะ (ตัดเสียงร้องตรงกลาง)" : "แตะเพื่อตัดเสียงร้องของเพลง")
                            .font(.system(size: 11))
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
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color.white.opacity(0.06))
                .cornerRadius(16)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(isVocalRemoverActive ? Color.red.opacity(0.5) : Color.white.opacity(0.1), lineWidth: 1.2)
                )
            }
            .padding(.horizontal, 16)

            // 2. Horizontal Preset Pills (Flat, Bass Boost, Rock, Pop, Jazz, Vocal)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(EqualizerPreset.allCases) { preset in
                        let isSelected = audioManager.currentPreset == preset
                        Button(action: {
                            let gen = UIImpactFeedbackGenerator(style: .light)
                            gen.impactOccurred()
                            audioManager.applyPreset(preset)
                            for (i, gain) in preset.gains.enumerated() {
                                webView?.evaluateJavaScript("window.__tubeEQ?.setGain(\(i), \(gain));", completionHandler: nil)
                            }
                        }) {
                            Text(preset.rawValue)
                                .font(.system(size: 12, weight: isSelected ? .bold : .medium))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 6)
                                .background(
                                    isSelected ?
                                        AnyView(LinearGradient(colors: [.cyan, .blue], startPoint: .topLeading, endPoint: .bottomTrailing)) :
                                        AnyView(Color.white.opacity(0.08))
                                )
                                .foregroundColor(isSelected ? .black : .white)
                                .cornerRadius(16)
                                .shadow(color: isSelected ? .cyan.opacity(0.4) : .clear, radius: 6)
                        }
                    }
                }
                .padding(.horizontal, 16)
            }

            // 3. 10-Band Professional Vertical EQ Sliders Card
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("10-BAND GRAPHIC EQUALIZER")
                        .font(.system(size: 10, weight: .black, design: .monospaced))
                        .foregroundColor(.cyan.opacity(0.8))
                        .tracking(1)

                    Spacer()

                    Button(action: {
                        let gen = UIImpactFeedbackGenerator(style: .rigid)
                        gen.impactOccurred()
                        audioManager.resetEQ()
                        for i in 0..<audioManager.bandFrequencies.count {
                            webView?.evaluateJavaScript("window.__tubeEQ?.setGain(\(i), 0.0);", completionHandler: nil)
                        }
                    }) {
                        HStack(spacing: 3) {
                            Image(systemName: "arrow.counterclockwise")
                            Text("Reset")
                        }
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white.opacity(0.8))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(10)
                    }
                }
                .padding(.horizontal, 16)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(0..<audioManager.bandFrequencies.count, id: \.self) { index in
                            VerticalEQSlider(
                                index: index,
                                gain: Binding(
                                    get: { audioManager.bandGains[index] },
                                    set: { audioManager.setGain(forBand: index, gain: $0) }
                                ),
                                frequencyText: formatFrequency(audioManager.bandFrequencies[index]),
                                onGainChanged: { newGain in
                                    webView?.evaluateJavaScript("window.__tubeEQ?.setGain(\(index), \(newGain));", completionHandler: nil)
                                }
                            )
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }
            .padding(.vertical, 12)
            .background(Color.black.opacity(0.4))
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
            .padding(.horizontal, 14)

            Spacer(minLength: 8)
        }
        .padding(.top, 4)
    }
}

// MARK: - Dedicated Vertical Studio Slider (Zero conflict with sheet gestures!)
public struct VerticalEQSlider: View {
    let index: Int
    @Binding var gain: Float
    let frequencyText: String
    var onGainChanged: (Float) -> Void

    public var body: some View {
        VStack(spacing: 4) {
            // Gain numerical value
            Text(String(format: "%+.1f", gain))
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundColor(gain > 0 ? .cyan : (gain < 0 ? .purple : .gray))
                .frame(height: 12)

            // Slider Track with Touch Interaction
            GeometryReader { geo in
                let trackHeight: CGFloat = geo.size.height
                // Normalize -15dB to +15dB -> 0.0 to 1.0 (0.5 is 0dB)
                let norm = CGFloat((gain + 15.0) / 30.0)
                let clampedNorm = max(0.0, min(1.0, norm))
                let thumbY = trackHeight * (1.0 - clampedNorm)

                ZStack(alignment: .bottom) {
                    // Track background groove
                    Capsule()
                        .fill(Color.white.opacity(0.12))
                        .frame(width: 6)

                    // Fill from center (0dB)
                    let centerNorm: CGFloat = 0.5
                    if clampedNorm >= centerNorm {
                        // Boost (Cyan)
                        let fillHeight = trackHeight * (clampedNorm - centerNorm)
                        Capsule()
                            .fill(LinearGradient(colors: [.cyan, .blue], startPoint: .top, endPoint: .bottom))
                            .frame(width: 6, height: max(0, fillHeight))
                            .offset(y: -trackHeight * (1.0 - clampedNorm))
                    } else {
                        // Cut (Purple)
                        let fillHeight = trackHeight * (centerNorm - clampedNorm)
                        Capsule()
                            .fill(LinearGradient(colors: [.purple, .indigo], startPoint: .top, endPoint: .bottom))
                            .frame(width: 6, height: max(0, fillHeight))
                            .offset(y: -trackHeight * (1.0 - centerNorm))
                    }

                    // Zero level mark
                    Rectangle()
                        .fill(Color.white.opacity(0.4))
                        .frame(width: 14, height: 1.5)
                        .offset(y: -trackHeight * 0.5)

                    // Glowing Slider Thumb Knob
                    Circle()
                        .fill(Color.white)
                        .frame(width: 20, height: 20)
                        .shadow(color: gain >= 0 ? .cyan.opacity(0.9) : .purple.opacity(0.9), radius: 5)
                        .overlay(
                            Circle()
                                .stroke(gain >= 0 ? Color.cyan : Color.purple, lineWidth: 2)
                        )
                        .offset(y: -trackHeight * clampedNorm + 10)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { val in
                            let locY = val.location.y
                            let newNorm = 1.0 - (locY / trackHeight)
                            let newClampedNorm = max(0.0, min(1.0, newNorm))
                            let newGain = Float(newClampedNorm * 30.0 - 15.0)
                            let roundedGain = (newGain * 2.0).rounded() / 2.0
                            if gain != roundedGain {
                                gain = roundedGain
                                onGainChanged(roundedGain)
                            }
                        }
                )
            }
            .frame(width: 34, height: 110)

            // Frequency Label
            Text(frequencyText)
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.white)
        }
        .frame(width: 44)
        .padding(.vertical, 6)
        .background(Color.black.opacity(0.35))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
    }
}
