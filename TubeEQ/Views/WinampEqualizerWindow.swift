import SwiftUI

public struct WinampEqualizerWindow: View {
    @ObservedObject var engine = WinampPlayerEngine.shared
    @State private var showPresetsMenu: Bool = false

    public var body: some View {
        let skin = engine.currentSkin

        WinampWindowFrame(
            title: "WINAMP EQUALIZER",
            skin: skin,
            onClose: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    engine.showEqualizerWindow = false
                }
            }
        ) {
            VStack(spacing: 8) {
                // TOP SECTION: ON/AUTO TOGGLES + EQ CURVE DISPLAY + PRESETS BUTTON + RESET
                HStack(spacing: 8) {
                    // ON & AUTO BUTTONS
                    VStack(spacing: 4) {
                        WinampButton("ON", isActive: engine.isEqEnabled, activeColor: skin.ledColor, skin: skin) {
                            engine.isEqEnabled.toggle()
                        }

                        WinampButton("AUTO", isActive: engine.isEqAuto, activeColor: skin.ledColor, skin: skin) {
                            engine.isEqAuto.toggle()
                        }
                    }

                    // REAL-TIME EQ CURVE GRAPH DISPLAY
                    GeometryReader { geo in
                        let w = geo.size.width
                        let h = geo.size.height

                        ZStack {
                            // Dark LCD Graph Background
                            skin.lcdBackground

                            // Grid Lines
                            Path { path in
                                // Center 0dB line
                                path.move(to: CGPoint(x: 0, y: h / 2))
                                path.addLine(to: CGPoint(x: w, y: h / 2))

                                // Vertical band guides
                                for i in 1..<10 {
                                    let x = (w / 10.0) * CGFloat(i)
                                    path.move(to: CGPoint(x: x, y: 0))
                                    path.addLine(to: CGPoint(x: x, y: h))
                                }
                            }
                            .stroke(Color.white.opacity(0.12), style: StrokeStyle(lineWidth: 0.5, dash: [2, 2]))

                            // EQ Response Curve
                            Path { path in
                                let count = engine.bandGains.count
                                guard count > 0 else { return }

                                for i in 0..<count {
                                    let x = (w / CGFloat(count - 1)) * CGFloat(i)
                                    let gain = engine.bandGains[i]
                                    // gain is -12 to +12
                                    let normalized = CGFloat((gain + 12.0) / 24.0)
                                    let y = h - (normalized * h)

                                    if i == 0 {
                                        path.move(to: CGPoint(x: x, y: y))
                                    } else {
                                        path.addLine(to: CGPoint(x: x, y: y))
                                    }
                                }
                            }
                            .stroke(skin.ledColor, lineWidth: 1.5)
                            .shadow(color: skin.ledColor.opacity(0.5), radius: 2)
                        }
                        .border(Color(white: 0.25), width: 1)
                    }
                    .frame(height: 38)

                    // PRESETS & RESET EQ
                    VStack(spacing: 4) {
                        WinampButton("PRESETS", skin: skin) {
                            showPresetsMenu = true
                        }

                        WinampButton("RESET", skin: skin) {
                            engine.resetEQ()
                        }
                    }
                }
                .padding(.horizontal, 2)

                // BOTTOM SLIDERS: PREAMP + 10 FREQUENCY BANDS
                HStack(spacing: 4) {
                    // Preamp Slider (Synchronous Direct Hardware Control)
                    WinampVerticalSlider(
                        value: Binding(
                            get: { engine.preampGain },
                            set: { engine.setPreamp($0) }
                        ),
                        label: "PREAMP",
                        skin: skin
                    )

                    // Divider bar
                    Rectangle()
                        .fill(Color.white.opacity(0.15))
                        .frame(width: 1, height: 110)
                        .padding(.horizontal, 2)

                    // 10 Frequency Band Sliders (70Hz - 16kHz) with Guaranteed Hardware Gain Callbacks
                    ForEach(0..<engine.bandGains.count, id: \.self) { i in
                        WinampVerticalSlider(
                            value: Binding(
                                get: { engine.bandGains[i] },
                                set: { engine.setGain(forBand: i, gain: $0) }
                            ),
                            label: engine.bandFrequencies[i],
                            skin: skin
                        )
                    }
                }
                .padding(.horizontal, 2)
            }
        }
        .confirmationDialog("Choose EQ Preset", isPresented: $showPresetsMenu, titleVisibility: .visible) {
            ForEach(EqualizerPreset.allCases) { preset in
                Button(preset.rawValue) {
                    engine.applyPreset(preset)
                }
            }
            Button("Reset EQ", role: .destructive) {
                engine.resetEQ()
            }
            Button("Cancel", role: .cancel) {}
        }
    }
}
