import SwiftUI

public struct SkinPickerSheet: View {
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject var engine = WinampPlayerEngine.shared
    @ObservedObject var skinManager = DynamicSkinManager.shared

    public var body: some View {
        NavigationView {
            ZStack {
                Color(red: 0.08, green: 0.09, blue: 0.12).ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 14) {
                        
                        // 1. CLOUD OTA AUTO-UPDATE BUTTON BAR
                        VStack(spacing: 6) {
                            Button(action: {
                                let gen = UIImpactFeedbackGenerator(style: .medium)
                                gen.impactOccurred()
                                skinManager.checkForUpdates(force: true, autoApplyLatest: true)
                            }) {
                                HStack(spacing: 8) {
                                    if skinManager.isCheckingForUpdates {
                                        ProgressView()
                                            .tint(.white)
                                            .scaleEffect(0.8)
                                    } else {
                                        Image(systemName: "arrow.triangle.2.circlepath")
                                            .font(.system(size: 13, weight: .bold))
                                    }

                                    Text(skinManager.isCheckingForUpdates ? "กำลังตรวจหาสกินใหม่จาก GitHub..." : "🔄 ตรวจหาและอัปเดตสกินใหม่ (ไม่ต้องลงแอพใหม่)")
                                        .font(.system(size: 12, weight: .bold))
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(Color(red: 0.15, green: 0.35, blue: 0.65))
                                .foregroundColor(.white)
                                .cornerRadius(8)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                                )
                            }
                            .disabled(skinManager.isCheckingForUpdates)

                            if let msg = skinManager.lastUpdateMessage {
                                Text(msg)
                                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                                    .foregroundColor(.green)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 10)

                        // 2. DYNAMIC DOWNLOADED SKINS (FROM CLOUD)
                        if !skinManager.dynamicSkins.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Image(systemName: "icloud.fill")
                                        .foregroundColor(.cyan)
                                    Text("CLOUD SKINS (อัปเดตออนไลน์)")
                                        .font(.system(size: 12, weight: .black, design: .monospaced))
                                        .foregroundColor(.cyan)
                                }
                                .padding(.horizontal, 16)

                                ForEach(skinManager.dynamicSkins) { dynSkin in
                                    let isSelected = (engine.activeDynamicSkin?.id == dynSkin.id)

                                    Button(action: {
                                        let gen = UIImpactFeedbackGenerator(style: .medium)
                                        gen.impactOccurred()
                                        engine.applyDynamicSkin(dynSkin)
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                            presentationMode.wrappedValue.dismiss()
                                        }
                                    }) {
                                        HStack(spacing: 12) {
                                            // Image thumbnail from documents
                                            if let uiImg = skinManager.imageFor(skin: dynSkin) {
                                                Image(uiImage: uiImg)
                                                    .resizable()
                                                    .aspectRatio(contentMode: .fill)
                                                    .frame(width: 48, height: 48)
                                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                                                    .overlay(
                                                        RoundedRectangle(cornerRadius: 6)
                                                            .stroke(Color.cyan, lineWidth: 1.5)
                                                    )
                                            } else {
                                                RoundedRectangle(cornerRadius: 6)
                                                    .fill(Color.cyan.opacity(0.3))
                                                    .frame(width: 48, height: 48)
                                            }

                                            VStack(alignment: .leading, spacing: 3) {
                                                HStack(spacing: 6) {
                                                    Text(dynSkin.name)
                                                        .font(.system(size: 15, weight: .bold))
                                                        .foregroundColor(.white)

                                                    Text("CLOUD")
                                                        .font(.system(size: 8, weight: .black))
                                                        .padding(.horizontal, 4)
                                                        .padding(.vertical, 1)
                                                        .background(Color.cyan)
                                                        .foregroundColor(.black)
                                                        .cornerRadius(3)
                                                }

                                                Text(dynSkin.description)
                                                    .font(.system(size: 11))
                                                    .foregroundColor(.gray)
                                                    .lineLimit(2)
                                            }

                                            Spacer()

                                            if isSelected {
                                                Image(systemName: "checkmark.circle.fill")
                                                    .font(.title2)
                                                    .foregroundColor(.cyan)
                                            }
                                        }
                                        .padding(12)
                                        .background(Color.white.opacity(0.06))
                                        .cornerRadius(10)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 10)
                                                .stroke(isSelected ? Color.cyan : Color.white.opacity(0.1), lineWidth: isSelected ? 2 : 1)
                                        )
                                    }
                                    .padding(.horizontal, 16)
                                }
                            }
                        }

                        // 3. PRESET CARTOON ANIME SKINS (LIQUID GLASS)
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "sparkles")
                                    .foregroundColor(.yellow)
                                Text("CARTOON ANIME SKINS (กลาสใส ทะลุภาพพื้นหลัง)")
                                    .font(.system(size: 12, weight: .black, design: .monospaced))
                                    .foregroundColor(.yellow)
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 4)

                            let cartoonSkins: [WinampSkinPreset] = [
                                .cartoonOnePiece,
                                .cartoonDragonBall,
                                .cartoonNaruto,
                                .cartoonDemonSlayer
                            ]

                            ForEach(cartoonSkins) { skin in
                                let isSelected = (engine.currentSkin == skin && engine.activeDynamicSkin == nil)

                                Button(action: {
                                    let gen = UIImpactFeedbackGenerator(style: .medium)
                                    gen.impactOccurred()
                                    engine.resetToPresetSkin(skin)
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                        presentationMode.wrappedValue.dismiss()
                                    }
                                }) {
                                    HStack(spacing: 12) {
                                        if let bgName = skin.backgroundImageName {
                                            Image(bgName)
                                                .resizable()
                                                .aspectRatio(contentMode: .fill)
                                                .frame(width: 48, height: 48)
                                                .clipShape(RoundedRectangle(cornerRadius: 6))
                                                .overlay(
                                                    Circle()
                                                        .fill(skin.ledColor)
                                                        .frame(width: 12, height: 12)
                                                        .shadow(color: skin.ledColor, radius: 4)
                                                        .padding(3),
                                                    alignment: .bottomTrailing
                                                )
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 6)
                                                        .stroke(skin.borderLight, lineWidth: 1.5)
                                                )
                                        }

                                        VStack(alignment: .leading, spacing: 3) {
                                            HStack(spacing: 6) {
                                                Text(skin.rawValue)
                                                    .font(.system(size: 15, weight: .bold))
                                                    .foregroundColor(.white)

                                                Text("GLASS")
                                                    .font(.system(size: 8, weight: .black))
                                                    .padding(.horizontal, 4)
                                                    .padding(.vertical, 1)
                                                    .background(Color.yellow)
                                                    .foregroundColor(.black)
                                                    .cornerRadius(3)
                                            }

                                            Text(skinDescription(skin))
                                                .font(.system(size: 11))
                                                .foregroundColor(.gray)
                                                .lineLimit(2)
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

                        // 4. CLASSIC & MODERN PRESETS
                        VStack(alignment: .leading, spacing: 8) {
                            Text("CLASSIC & HI-FI PRESETS")
                                .font(.system(size: 12, weight: .black, design: .monospaced))
                                .foregroundColor(.white.opacity(0.7))
                                .padding(.horizontal, 16)
                                .padding(.top, 4)

                            let classicSkins = WinampSkinPreset.allCases.filter { !$0.hasBackgroundImage }

                            ForEach(classicSkins) { skin in
                                let isSelected = (engine.currentSkin == skin && engine.activeDynamicSkin == nil)

                                Button(action: {
                                    let gen = UIImpactFeedbackGenerator(style: .medium)
                                    gen.impactOccurred()
                                    engine.resetToPresetSkin(skin)
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                        presentationMode.wrappedValue.dismiss()
                                    }
                                }) {
                                    HStack(spacing: 12) {
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
                                                .font(.system(size: 15, weight: .bold))
                                                .foregroundColor(.white)

                                            Text(skinDescription(skin))
                                                .font(.system(size: 11))
                                                .foregroundColor(.gray)
                                                .lineLimit(2)
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
        case .rgbNeon: return "🌈 RGB Neon Cyber: Dual-tone cyan to neon magenta gaming glow"
        case .animeKawaii: return "🌸 Anime Pastel: Dreamy sakura pink, lavender and mint anime palette"
        case .auroraGradient: return "🌌 Aurora Cosmic: Flowing polar northern lights & emerald display"
        case .sunsetVaporwave: return "🌅 Sunset Vaporwave: Miami dusk orange-violet gradient & coral LED"
        case .graphicBauhaus: return "🎨 Graphic Bold Art: High-contrast cobalt, canary yellow & red accent"
        case .retroSynthwave: return "⚡ Retrowave 80s: Outrun grid purple, neon cyan and hot magenta"
        case .cartoonOnePiece: return "🏴‍☠️ วันพีซ ลูฟี่หมวกฟาง: บอดี้ลิควิดกลาสใส ทะลุเห็นรูป โทนแดงทองโจรสลัด"
        case .cartoonDragonBall: return "⚡ ดราก้อนบอล โกคู: ซูเปอร์ไซย่า อัลตร้าอินสติงค์ ออร่าประกายแสงสีฟ้าคราม"
        case .cartoonNaruto: return "🍃 นารูโตะ & ซาสึเกะ: นินจาโคโนฮะ กลาสใสสะท้อนลายเส้น โทนส้มเพลิง-น้ำเงินเข้ม"
        case .cartoonDemonSlayer: return "⚔️ ดาบพิฆาตอสูร: เซ็นอิทซึ & ทันจิโร่ ปราณอัสนีบาตและปราณวารีเรืองแสง"
        }
    }
}
