import SwiftUI

public struct SkinPickerSheet: View {
    @ObservedObject var engine = WinampPlayerEngine.shared
    @ObservedObject var dynamicManager = DynamicSkinManager.shared
    @Environment(\.presentationMode) var presentationMode

    public var body: some View {
        NavigationView {
            ZStack {
                Color(red: 0.08, green: 0.09, blue: 0.12).ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {

                        // 1. CLOUD SKINS UPDATE & REFRESH BAR
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "icloud.and.arrow.down.fill")
                                    .foregroundColor(.cyan)
                                Text("CLOUD SKINS (อัปเดตสกินออนไลน์อัตโนมัติ)")
                                    .font(.system(size: 12, weight: .black, design: .monospaced))
                                    .foregroundColor(.cyan)

                                Spacer()

                                Button(action: {
                                    let gen = UIImpactFeedbackGenerator(style: .medium)
                                    gen.impactOccurred()
                                    dynamicManager.checkForUpdates(force: true)
                                }) {
                                    HStack(spacing: 4) {
                                        if dynamicManager.isCheckingForUpdates {
                                            ProgressView()
                                                .scaleEffect(0.6)
                                                .tint(.white)
                                        } else {
                                            Image(systemName: "arrow.clockwise")
                                                .font(.system(size: 11, weight: .bold))
                                        }
                                        Text(dynamicManager.isCheckingForUpdates ? "กำลังโหลด..." : "อัปเดตสกิน")
                                            .font(.system(size: 10, weight: .bold))
                                    }
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.cyan.opacity(0.2))
                                    .foregroundColor(.cyan)
                                    .cornerRadius(6)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 6)
                                            .stroke(Color.cyan.opacity(0.5), lineWidth: 1)
                                    )
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 12)

                            if let status = dynamicManager.lastUpdateMessage {
                                Text(status)
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundColor(.gray)
                                    .padding(.horizontal, 16)
                            }
                        }

                        // 2. DYNAMIC CLOUD SKINS (IF DOWNLOADED)
                        if !dynamicManager.dynamicSkins.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("สกินออนไลน์จากคลาวด์")
                                    .font(.system(size: 12, weight: .black, design: .monospaced))
                                    .foregroundColor(.white.opacity(0.7))
                                    .padding(.horizontal, 16)

                                ForEach(dynamicManager.dynamicSkins) { skin in
                                    let isSelected = (engine.activeDynamicSkin?.id == skin.id)

                                    Button(action: {
                                        let gen = UIImpactFeedbackGenerator(style: .medium)
                                        gen.impactOccurred()
                                        engine.applyDynamicSkin(skin)
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                            presentationMode.wrappedValue.dismiss()
                                        }
                                    }) {
                                        HStack(spacing: 12) {
                                            if let img = dynamicManager.imageFor(skin: skin) {
                                                Image(uiImage: img)
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
                                                            .stroke(Color.cyan, lineWidth: 1.5)
                                                    )
                                            } else {
                                                RoundedRectangle(cornerRadius: 6)
                                                    .fill(skin.titleBarGradient)
                                                    .frame(width: 48, height: 48)
                                                    .overlay(
                                                        ProgressView()
                                                            .scaleEffect(0.6)
                                                            .tint(.white)
                                                    )
                                            }

                                            VStack(alignment: .leading, spacing: 3) {
                                                HStack(spacing: 6) {
                                                    Text(skin.name)
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

                                                Text(skin.description)
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

                        // 3. DYNAMIC ANIMATED RGB RUNNING LIGHTS (ไฟวิ่ง)
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "rays")
                                    .foregroundColor(.green)
                                Text("RGB RUNNING LIGHTS (ไฟวิ่งนีออนเรืองแสงรอบตัวเครื่อง)")
                                    .font(.system(size: 12, weight: .black, design: .monospaced))
                                    .foregroundColor(.green)
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 4)

                            let rgbSkins: [WinampSkinPreset] = [
                                .rgbChromaFlow,
                                .rgbCyberWave,
                                .rgbLavaBlaze
                            ]

                            ForEach(rgbSkins) { skin in
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
                                                RGBRunningBorderView(colors: skin.rgbLightColors, lineWidth: 2.0, cornerRadius: 6)
                                            )

                                        VStack(alignment: .leading, spacing: 3) {
                                            HStack(spacing: 6) {
                                                Text(skin.rawValue)
                                                    .font(.system(size: 15, weight: .bold))
                                                    .foregroundColor(.white)

                                                Text("ไฟวิ่ง 60FPS")
                                                    .font(.system(size: 8, weight: .black))
                                                    .padding(.horizontal, 4)
                                                    .padding(.vertical, 1)
                                                    .background(Color.green)
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

                        // 4. CUSTOM APP-FITTED MASTER CHASSIS (สกินคัสตอมตรงบล็อกตัวเครื่อง)
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "square.split.bottomrightquarter.fill")
                                    .foregroundColor(.orange)
                                Text("APP-FITTED CHASSIS (ออกแบบตรงบล็อก Main, EQ, Playlist)")
                                    .font(.system(size: 12, weight: .black, design: .monospaced))
                                    .foregroundColor(.orange)
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 4)

                            let tailoredSkins: [WinampSkinPreset] = [
                                .audiophileGold,
                                .cyberpunkMatrix,
                                .stealthCarbon
                            ]

                            ForEach(tailoredSkins) { skin in
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

                                                Text("CUSTOM-FIT")
                                                    .font(.system(size: 8, weight: .black))
                                                    .padding(.horizontal, 4)
                                                    .padding(.vertical, 1)
                                                    .background(Color.orange)
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

                        // 5. PRESET HIGH-RES WALLPAPERS (LIQUID GLASS)
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "sparkles")
                                    .foregroundColor(.yellow)
                                Text("STANDOUT IMAGE SKINS (กลาสใส ทะลุภาพพื้นหลัง)")
                                    .font(.system(size: 12, weight: .black, design: .monospaced))
                                    .foregroundColor(.yellow)
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 4)

                            let wallpaperSkins: [WinampSkinPreset] = [
                                .cyberdeckHUD,
                                .cosmosNebula,
                                .neonSynthwave,
                                .obsidianGlass,
                                .mechaTactical
                            ]

                            ForEach(wallpaperSkins) { skin in
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

                        // 6. CLASSIC & MODERN PRESETS
                        VStack(alignment: .leading, spacing: 8) {
                            Text("CLASSIC & HI-FI PRESETS")
                                .font(.system(size: 12, weight: .black, design: .monospaced))
                                .foregroundColor(.white.opacity(0.7))
                                .padding(.horizontal, 16)
                                .padding(.top, 4)

                            let classicSkins = WinampSkinPreset.allCases.filter { !$0.hasBackgroundImage && !$0.isRGBRunningLight }

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
        case .rgbChromaFlow: return "🌈 RGB Chroma Flow: ไฟวิ่งสีรุ้งเรืองแสง 360° วิ่งรอบกรอบโมดูลเครื่องเล่นตลอดเวลา"
        case .rgbCyberWave: return "⚡ Cyber Neon Pulse: ไฟวิ่งนีออนเลเซอร์ ไซยาน-ฮ็อตพิงก์ วิ่งรอบกรอบโมดูล สไตล์เกมมิ่ง"
        case .rgbLavaBlaze: return "🔥 Lava Blaze Chase: ไฟวิ่งเปลวเพลิงแมกม่า เรด-โกลด์ วิ่งรอบกรอบโมดูล ทรงพลังเร้าใจ"
        case .audiophileGold: return "🎛️ Audiophile Master Chassis: คัสตอมพอดีบล็อก Main, EQ และ Playlist ไททาเนียมรมดำแร็คทองคำ"
        case .cyberpunkMatrix: return "⚡ Cyber Terminal Matrix: คัสตอมตรงบล็อกตัวเครื่อง เมนเฟรมไซเบอร์ วงจรเรืองแสง"
        case .stealthCarbon: return "🏎️ Stealth Carbon Fiber: คัสตอมตรงบล็อกตัวเครื่อง คาร์บอนไฟเบอร์ & สโมคกลาส ลายเส้นสปอร์ต"
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
        case .cyberdeckHUD: return "🎛️ CyberDeck HUD 2077: โครงสร้างไซไฟเทอร์มินัลไฮเทค วงจรดิจิทัลเรืองแสง โทนฟ้านีออน"
        case .cosmosNebula: return "🌌 Deep Cosmos Nebula: ห้วงอวกาศลึก กาแล็กซีเนบิวลาดาวล้านดวง กลาสใสประกายดาว"
        case .neonSynthwave: return "🌆 Neon Synthwave 80s: ดิจิทัลกริดซันเซ็ต เรโทรฮอไรซอน นีออนโครเมียมสุดล้ำ"
        case .obsidianGlass: return "💎 Obsidian Crystal Hi-Fi: ออบซิเดียนรมดำ คริสตัลสะท้อนแสง ทรงคุณค่าระดับ Audiophile"
        case .mechaTactical: return "⚡ Mecha Tactical Console: คอนโซลห้องนักบินหุ่นรบ เกราะไททาเนียม สไตล์ Cockpit ทหาร"
        }
    }
}
