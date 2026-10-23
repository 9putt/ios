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
        NavigationView {
            ZStack {
                Color(red: 0.08, green: 0.09, blue: 0.12).ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        
                        // Header Control Card
                        VStack(spacing: 16) {
                            HStack {
                                Text("Presets")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                Spacer()
                                Picker("Preset", selection: $audioManager.currentPreset) {
                                    ForEach(EqualizerPreset.allCases) { preset in
                                        Text(preset.rawValue).tag(preset)
                                    }
                                }
                                .pickerStyle(MenuPickerStyle())
                                .tint(.cyan)
                                .onChange(of: audioManager.currentPreset) { newPreset in
                                    audioManager.applyPreset(newPreset)
                                }
                            }
                            
                            Divider().background(Color.gray.opacity(0.3))

                            HStack {
                                Toggle("Bypass EQ", isOn: $audioManager.isEqBypassed)
                                    .foregroundColor(.white)
                                    .tint(.cyan)
                                
                                Spacer(minLength: 20)

                                Button(action: {
                                    audioManager.resetEQ()
                                }) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "arrow.counterclockwise")
                                        Text("Reset")
                                    }
                                    .font(.subheadline.bold())
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 8)
                                    .background(Color.white.opacity(0.12))
                                    .foregroundColor(.white)
                                    .cornerRadius(8)
                                }
                            }
                        }
                        .padding()
                        .background(Color(white: 0.14))
                        .cornerRadius(16)
                        .padding(.horizontal)

                        // 10-Band Sliders Card
                        VStack(alignment: .leading, spacing: 14) {
                            Text("10-Band Parametric Equalizer")
                                .font(.headline)
                                .foregroundColor(.white)
                                .padding(.bottom, 4)

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 16) {
                                    ForEach(0..<audioManager.bandFrequencies.count, id: \.self) { index in
                                        VStack(spacing: 8) {
                                            Text(String(format: "%+.1f dB", audioManager.bandGains[index]))
                                                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                                .foregroundColor(audioManager.bandGains[index] == 0 ? .gray : .cyan)

                                            // Vertical Slider Representation
                                            Slider(
                                                value: Binding(
                                                    get: { Double(audioManager.bandGains[index]) },
                                                    set: { audioManager.setGain(forBand: index, gain: Float($0)) }
                                                ),
                                                in: -15.0...15.0,
                                                step: 0.5
                                            )
                                            .rotationEffect(.degrees(-90))
                                            .frame(width: 140, height: 40)
                                            .tint(.cyan)
                                            .padding(.vertical, 50)

                                            Text(formatFrequency(audioManager.bandFrequencies[index]))
                                                .font(.system(size: 12, weight: .bold))
                                                .foregroundColor(.white)
                                        }
                                        .frame(width: 50)
                                        .padding(.vertical, 8)
                                        .background(Color.white.opacity(0.04))
                                        .cornerRadius(10)
                                    }
                                }
                                .padding(.horizontal, 4)
                            }
                        }
                        .padding()
                        .background(Color(white: 0.14))
                        .cornerRadius(16)
                        .padding(.horizontal)

                        // Reverb & Ambience Card
                        VStack(alignment: .leading, spacing: 14) {
                            HStack {
                                Text("Acoustic Ambience (Reverb)")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                Spacer()
                                Text("\(Int(audioManager.reverbWetDryMix))%")
                                    .font(.subheadline.bold())
                                    .foregroundColor(.cyan)
                            }

                            Slider(value: $audioManager.reverbWetDryMix, in: 0.0...100.0, step: 1.0)
                                .tint(.cyan)
                        }
                        .padding()
                        .background(Color(white: 0.14))
                        .cornerRadius(16)
                        .padding(.horizontal)

                    }
                    .padding(.vertical)
                }
            }
            .navigationTitle("Equalizer Pro")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
