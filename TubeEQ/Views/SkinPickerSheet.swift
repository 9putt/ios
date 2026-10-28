import SwiftUI

public struct SkinPickerSheet: View {
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject var engine = WinampPlayerEngine.shared

    public var body: some View {
        NavigationView {
            ZStack {
                Color(red: 0.08, green: 0.09, blue: 0.12).ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 12) {
                        Text("Select Winamp Skin Preset")
                            .font(.system(size: 14, weight: .bold, design: .monospaced))
                            .foregroundColor(.white.opacity(0.8))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 16)
                            .padding(.top, 8)

                        ForEach(WinampSkinPreset.allCases) { skin in
                            let isSelected = (engine.currentSkin == skin)

                            Button(action: {
                                let gen = UIImpactFeedbackGenerator(style: .medium)
                                gen.impactOccurred()
                                engine.currentSkin = skin
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                    presentationMode.wrappedValue.dismiss()
                                }
                            }) {
                                HStack(spacing: 14) {
                                    // Skin Color Swatch Preview
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(skin.titleBarGradient)
                                        .frame(width: 48, height: 48)
                                        .overlay(
                                            Circle()
                                                .fill(skin.ledColor)
                                                .frame(width: 14, height: 14)
                                                .shadow(color: skin.ledColor, radius: 4)
                                        )
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 6)
                                                .stroke(skin.borderLight, lineWidth: 1.5)
                                        )

                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(skin.rawValue)
                                            .font(.system(size: 16, weight: .bold))
                                            .foregroundColor(.white)
                                        
                                        Text(skinDescription(skin))
                                            .font(.system(size: 11))
                                            .foregroundColor(.gray)
                                    }

                                    Spacer()

                                    if isSelected {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.title2)
                                            .foregroundColor(skin.ledColor)
                                    }
                                }
                                .padding(12)
                                .background(skin.windowBackground)
                                .cornerRadius(10)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(isSelected ? skin.ledColor : Color.white.opacity(0.1), lineWidth: isSelected ? 2 : 1)
                                )
                            }
                            .padding(.horizontal, 16)
                        }
                    }
                    .padding(.bottom, 24)
                }
            }
            .navigationTitle("Winamp Skins")
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

    private func skinDescription(_ skin: WinampSkinPreset) -> String {
        switch skin {
        case .classicModern: return "Navy brushed steel, cyan/blue highlights, green LED (Modern Lite 1.03)"
        case .classic1998: return "Original 1998 charcoal grey, amber marquee, green LED"
        case .obsidianBento: return "Deep matte black with electric ice-blue glow"
        case .cyberMatrix: return "Terminal green phosphor display on pitch black"
        case .champagneGold: return "Brushed executive gold & champagne titanium hi-fi chassis"
        case .solarFlare: return "Crimson metallic chassis with lava red display"
        }
    }
}
