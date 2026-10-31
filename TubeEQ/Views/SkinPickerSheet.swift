import SwiftUI

public struct SkinPickerSheet: View {
    @ObservedObject var engine = WinampPlayerEngine.shared
    @ObservedObject var dynamicManager = DynamicSkinManager.shared
    @Environment(\.presentationMode) var presentationMode

    private let rgbSkins: [WinampSkinPreset] = [
        .rgbChromaFlow,
        .rgbCyberWave,
        .rgbLavaBlaze,
        .rgbAuroraBorealis,
        .rgbQuantumPulse
    ]

    private let tailoredSkins: [WinampSkinPreset] = [
        .audiophileGold,
        .cyberpunkMatrix,
        .stealthCarbon
    ]

    private let glassSkins: [WinampSkinPreset] = [
        .glassAeroPrism,
        .glassVelvetMidnight,
        .glassCyberShibuya
    ]

    public var body: some View {
        NavigationView {
            ZStack {
                Color(red: 0.08, green: 0.09, blue: 0.12).ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        cloudHeaderSection
                        if !dynamicManager.dynamicSkins.isEmpty {
                            dynamicCloudSection
                        }
                        rgbRunningLightsSection
                        tailoredChassisSection
                        liquidGlassSection
                        classicSkinsSection
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

    // MARK: - 1. Cloud Header Section
    @ViewBuilder
    private var cloudHeaderSection: some View {
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
    }

    // MARK: - 2. Dynamic Cloud Section
    @ViewBuilder
    private var dynamicCloudSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("สกินออนไลน์จากคลาวด์")
                .font(.system(size: 12, weight: .black, design: .monospaced))
                .foregroundColor(.white.opacity(0.7))
                .padding(.horizontal, 16)

            ForEach(dynamicManager.dynamicSkins) { skin in
                dynamicSkinButton(skin: skin)
            }
        }
    }

    @ViewBuilder
    private func dynamicSkinButton(skin: DynamicSkinItem) -> some View {
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
                } else {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(skin.titleBarGradient)
                        .frame(width: 48, height: 48)
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
        }
        .padding(.horizontal, 16)
    }

    // MARK: - 3. RGB Running Lights Section
    @ViewBuilder
    private var rgbRunningLightsSection: some View {
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

            ForEach(rgbSkins) { skin in
                presetSkinButton(skin: skin, tag: "ไฟวิ่ง 60FPS", tagColor: .green)
            }
        }
    }

    // MARK: - 4. Tailored Chassis Section
    @ViewBuilder
    private var tailoredChassisSection: some View {
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

            ForEach(tailoredSkins) { skin in
                presetSkinButton(skin: skin, tag: "CUSTOM-FIT", tagColor: .orange)
            }
        }
    }

    // MARK: - 5. Liquid Glass Section
    @ViewBuilder
    private var liquidGlassSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "sparkles")
                    .foregroundColor(.cyan)
                Text("LIQUID GLASS (กลาสใส ทะลุภาพพื้นหลังหรูหรา 3 สไตล์)")
                    .font(.system(size: 12, weight: .black, design: .monospaced))
                    .foregroundColor(.cyan)
            }
            .padding(.horizontal, 16)
            .padding(.top, 4)

            ForEach(glassSkins) { skin in
                presetSkinButton(skin: skin, tag: "LIQUID GLASS", tagColor: .cyan)
            }
        }
    }

    // MARK: - 6. Classic Skins Section
    @ViewBuilder
    private var classicSkinsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("CLASSIC & HI-FI PRESETS")
                .font(.system(size: 12, weight: .black, design: .monospaced))
                .foregroundColor(.white.opacity(0.7))
                .padding(.horizontal, 16)
                .padding(.top, 4)

            let classicSkins = WinampSkinPreset.allCases.filter { !$0.hasBackgroundImage && !$0.isRGBRunningLight }

            ForEach(classicSkins) { skin in
                presetSkinButton(skin: skin, tag: nil, tagColor: .clear)
            }
        }
    }

    // MARK: - Reusable Preset Button
    @ViewBuilder
    private func presetSkinButton(skin: WinampSkinPreset, tag: String?, tagColor: Color) -> some View {
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
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(skin.borderLight, lineWidth: 1.5)
                        )
                } else if skin.isRGBRunningLight {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(skin.titleBarGradient)
                        .frame(width: 48, height: 48)
                        .overlay(
                            RGBRunningBorderView(colors: skin.rgbLightColors, lineWidth: 2.0, cornerRadius: 6)
                        )
                } else {
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
                }

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(skin.rawValue)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.white)

                        if let tag = tag {
                            Text(tag)
                                .font(.system(size: 8, weight: .black))
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(tagColor)
                                .foregroundColor(.black)
                                .cornerRadius(3)
                        }
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

    private func skinDescription(_ skin: WinampSkinPreset) -> String {
        switch skin {
        case .rgbChromaFlow: return "🌈 RGB Chroma Flow: ไฟวิ่งสีรุ้งเรืองแสง 360° วิ่งรอบกรอบโมดูลเครื่องเล่นพร้อมประกายวิบวับ"
        case .rgbCyberWave: return "⚡ Cyber Neon Pulse: ไฟวิ่งนีออนเลเซอร์ ไซยาน-ฮ็อตพิงก์ พร้อมพื้นหลังกริดเมทริกซ์และหัวข้อวิบวับ"
        case .rgbLavaBlaze: return "🔥 Lava Blaze Chase: ไฟวิ่งเปลวเพลิงแมกม่า เรด-โกลด์ พร้อมประกายไฟเร้าใจ"
        case .rgbAuroraBorealis: return "✨ Aurora Cosmic Shimmer: แสงเหนือออโรร่าพริ้วไหว ดาวระยิบระยับ แสงมรกตเขียวตัดม่วงวิบวับ"
        case .rgbQuantumPulse: return "🔮 Quantum Violet Pulse: คลื่นไฟฟ้าควอนตัมสีม่วง-ไอซ์บลู เรืองแสงวิบวับสไตล์ล้ำยุค"
        case .audiophileGold: return "🎛️ Audiophile Master Chassis: คัสตอมพอดีบล็อก Main, EQ และ Playlist ไททาเนียมรมดำแร็คทองคำ"
        case .cyberpunkMatrix: return "⚡ Cyber Terminal Matrix: คัสตอมตรงบล็อกตัวเครื่อง เมนเฟรมไซเบอร์ วงจรเรืองแสง"
        case .stealthCarbon: return "🏎️ Stealth Carbon Fiber: คัสตอมตรงบล็อกตัวเครื่อง คาร์บอนไฟเบอร์ & สโมคกลาส ลายเส้นสปอร์ต"
        case .glassAeroPrism: return "💎 Liquid Glass Aero: กระจกคริสตัลใสโปร่งแสงระดับพรีเมียม สัมผัสหักเหแสงสีรุ้งอ่อนโยน ทะลุเห็นภาพพื้นหลังงดงาม"
        case .glassVelvetMidnight: return "🌌 Liquid Glass Velvet: กระจกสโมคแซฟไฟร์รมดำหรูหรา ตัดเส้นสายทองคำบริสุทธิ์ ให้ความรู้สึกระดับซูเปอร์ไฮเอนด์"
        case .glassCyberShibuya: return "🌧️ Liquid Glass Tokyo Neon: กระจกใสละอองสายฝน สะท้อนแสงไฟนีออนชิบูย่ายามค่ำคืน โทนชมพู-ม่วง-ไซเบอร์บลู"
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
        }
    }
}
