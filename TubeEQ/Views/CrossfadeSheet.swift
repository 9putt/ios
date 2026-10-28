import SwiftUI

public struct CrossfadeSheet: View {
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject var engine = WinampPlayerEngine.shared

    public var body: some View {
        NavigationView {
            ZStack {
                Color(red: 0.08, green: 0.09, blue: 0.12).ignoresSafeArea()

                VStack(spacing: 20) {
                    // Header Card
                    VStack(spacing: 8) {
                        Image(systemName: "waveform.badge.magnifyingglass")
                            .font(.system(size: 40))
                            .foregroundColor(engine.currentSkin.ledColor)
                            .padding(.top, 12)

                        Text("Crossfade Track Transition")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)

                        Text("Simulates classic Winamp DirectSound output fading: smoothly fades out the previous song while blending in the next.")
                            .font(.system(size: 12))
                            .multilineTextAlignment(.center)
                            .foregroundColor(.gray)
                            .padding(.horizontal, 24)
                    }

                    // Enable / Disable Toggle
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Enable Crossfader")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundColor(.white)
                            Text("Blend between songs seamlessly")
                                .font(.system(size: 11))
                                .foregroundColor(.gray)
                        }
                        Spacer()
                        Toggle("", isOn: $engine.isCrossfadeEnabled)
                            .labelsHidden()
                            .tint(engine.currentSkin.ledColor)
                    }
                    .padding(14)
                    .background(Color.white.opacity(0.06))
                    .cornerRadius(12)
                    .padding(.horizontal, 16)

                    // Duration Slider (0.0s to 10.0s)
                    VStack(spacing: 12) {
                        HStack {
                            Text("Crossfade Duration")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.white)
                            Spacer()
                            Text(String(format: "%.1f seconds", engine.crossfadeDuration))
                                .font(.system(size: 14, weight: .heavy, design: .monospaced))
                                .foregroundColor(engine.currentSkin.ledColor)
                        }

                        Slider(value: $engine.crossfadeDuration, in: 0.5...10.0, step: 0.5)
                            .tint(engine.currentSkin.ledColor)

                        // Quick Preset Buttons
                        HStack(spacing: 8) {
                            ForEach([1.0, 2.0, 3.0, 5.0, 8.0, 10.0], id: \.self) { sec in
                                let isSel = (engine.crossfadeDuration == sec)
                                Button(action: {
                                    let gen = UIImpactFeedbackGenerator(style: .light)
                                    gen.impactOccurred()
                                    engine.crossfadeDuration = sec
                                }) {
                                    Text("\(Int(sec))s")
                                        .font(.system(size: 11, weight: isSel ? .black : .medium))
                                        .foregroundColor(isSel ? .black : .white)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 6)
                                        .background(isSel ? engine.currentSkin.ledColor : Color.white.opacity(0.1))
                                        .cornerRadius(6)
                                }
                            }
                        }
                    }
                    .padding(14)
                    .background(Color.white.opacity(0.06))
                    .cornerRadius(12)
                    .padding(.horizontal, 16)

                    Spacer()
                }
                .padding(.top, 16)
            }
            .navigationTitle("Crossfade Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
    }
}
