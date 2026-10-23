import SwiftUI

public struct EqualizerView: View {
    @ObservedObject var audioManager = AudioEngineManager.shared
    
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
                colors: [Color(red: 0.07, green: 0.08, blue: 0.12), Color(red: 0.03, green: 0.04, blue: 0.06)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {
                    
                    // 1. Header with Neon Glow
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("STUDIO EQUALIZER")
                                .font(.system(size: 11, weight: .black, design: .monospaced))
                                .foregroundColor(.cyan)
                                .tracking(2)
                            Text("10-Band DSP Core")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.white)
                        }

                        Spacer()

                        Toggle("", isOn: Binding(
                            get: { !audioManager.isEqBypassed },
                            set: { audioManager.isEqBypassed = !$0 }
                        ))
                        .labelsHidden()
                        .tint(.cyan)

                        Button(action: {
                            let gen = UIImpactFeedbackGenerator(style: .rigid)
                            gen.impactOccurred()
                            audioManager.resetEQ()
                        }) {
                            Image(systemName: "arrow.counterclockwise")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundColor(.white)
                                .padding(9)
                                .background(Color.white.opacity(0.1))
                                .clipShape(Circle())
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)

                    // 2. Horizontal Preset Pills (Scrollable with Neon Selection)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(EqualizerPreset.allCases) { preset in
                                let isSelected = audioManager.currentPreset == preset
                                Button(action: {
                                    let gen = UIImpactFeedbackGenerator(style: .light)
                                    gen.impactOccurred()
                                    audioManager.applyPreset(preset)
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

                    // 3. 10-Band Sliders Card (Glassmorphism Studio Console)
                    VStack(alignment: .leading, spacing: 14) {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 16) {
                                ForEach(0..<audioManager.bandFrequencies.count, id: \.self) { index in
                                    VStack(spacing: 6) {
                                        // dB Indicator with color change
                                        let gain = audioManager.bandGains[index]
                                        Text(String(format: "%+.1f", gain))
                                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                                            .foregroundColor(gain > 0 ? .cyan : (gain < 0 ? .purple : .gray))
                                            .frame(height: 14)

                                        // Vertical slider
                                        Slider(
                                            value: Binding(
                                                get: { Double(audioManager.bandGains[index]) },
                                                set: {
                                                    audioManager.setGain(forBand: index, gain: Float($0))
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
                                    .background(Color.black.opacity(0.25))
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

                    // 4. Acoustic Ambience (Reverb & 3D Space)
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Label("3D Ambience / Reverb", systemImage: "sparkles")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.white)
                            Spacer()
                            Text("\(Int(audioManager.reverbWetDryMix))%")
                                .font(.system(size: 13, weight: .bold, design: .monospaced))
                                .foregroundColor(.cyan)
                        }

                        Slider(value: $audioManager.reverbWetDryMix, in: 0.0...100.0, step: 1.0)
                            .tint(LinearGradient(colors: [.cyan, .purple], startPoint: .leading, endPoint: .trailing))
                    }
                    .padding(18)
                    .background(.ultraThinMaterial)
                    .cornerRadius(20)
                    .padding(.horizontal, 16)

                    Spacer(minLength: 24)
                }
            }
        }
    }
}
