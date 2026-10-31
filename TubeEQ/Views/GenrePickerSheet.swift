import SwiftUI

public struct GenrePickerSheet: View {
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject var engine = WinampPlayerEngine.shared

    public var body: some View {
        let skin = engine.currentSkin

        NavigationView {
            ZStack {
                Color(red: 0.08, green: 0.09, blue: 0.12).ignoresSafeArea()

                VStack(spacing: 0) {
                    ScrollView {
                        VStack(spacing: 12) {
                            // Header Banner
                            VStack(alignment: .leading, spacing: 4) {
                                Text("CUSTOM GENRE MIXER")
                                    .font(.system(size: 13, weight: .black, design: .monospaced))
                                    .foregroundColor(skin.ledColor)

                                Text("เลือกแนวเพลงที่ต้องการฟังผสมกัน (แตะเลือกได้หลายหมวด เช่น สตริง + ลูกทุ่ง)")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(.white.opacity(0.75))
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 16)
                            .padding(.top, 12)

                            // Quick Presets Bar
                            HStack(spacing: 8) {
                                Button(action: {
                                    let gen = UIImpactFeedbackGenerator(style: .light)
                                    gen.impactOccurred()
                                    engine.selectedGenres = [.string, .lukThung]
                                }) {
                                    Text("สตริง + ลูกทุ่ง")
                                        .font(.system(size: 11, weight: .bold))
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 5)
                                        .background(engine.selectedGenres == [.string, .lukThung] ? skin.ledColor.opacity(0.25) : Color.white.opacity(0.06))
                                        .foregroundColor(engine.selectedGenres == [.string, .lukThung] ? skin.ledColor : .white)
                                        .cornerRadius(6)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 6)
                                                .stroke(engine.selectedGenres == [.string, .lukThung] ? skin.ledColor : Color.white.opacity(0.15), lineWidth: 1)
                                        )
                                }

                                Button(action: {
                                    let gen = UIImpactFeedbackGenerator(style: .light)
                                    gen.impactOccurred()
                                    engine.selectedGenres = [.pueaChiwit, .lukThung]
                                }) {
                                    Text("เพื่อชีวิต + ลูกทุ่ง")
                                        .font(.system(size: 11, weight: .bold))
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 5)
                                        .background(engine.selectedGenres == [.pueaChiwit, .lukThung] ? skin.ledColor.opacity(0.25) : Color.white.opacity(0.06))
                                        .foregroundColor(engine.selectedGenres == [.pueaChiwit, .lukThung] ? skin.ledColor : .white)
                                        .cornerRadius(6)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 6)
                                                .stroke(engine.selectedGenres == [.pueaChiwit, .lukThung] ? skin.ledColor : Color.white.opacity(0.15), lineWidth: 1)
                                        )
                                }

                                Button(action: {
                                    let gen = UIImpactFeedbackGenerator(style: .light)
                                    gen.impactOccurred()
                                    engine.selectedGenres = Set(MusicGenre.allCases)
                                }) {
                                    Text("ผสมทุกแนว (All)")
                                        .font(.system(size: 11, weight: .bold))
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 5)
                                        .background(engine.selectedGenres.count == MusicGenre.allCases.count ? skin.ledColor.opacity(0.25) : Color.white.opacity(0.06))
                                        .foregroundColor(engine.selectedGenres.count == MusicGenre.allCases.count ? skin.ledColor : .white)
                                        .cornerRadius(6)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 6)
                                                .stroke(engine.selectedGenres.count == MusicGenre.allCases.count ? skin.ledColor : Color.white.opacity(0.15), lineWidth: 1)
                                        )
                                }

                                Spacer()
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 4)

                            // Genre Cards
                            ForEach(MusicGenre.allCases) { genre in
                                let isSelected = engine.isGenreSelected(genre)

                                Button(action: {
                                    let gen = UIImpactFeedbackGenerator(style: .medium)
                                    gen.impactOccurred()
                                    engine.toggleGenre(genre)
                                }) {
                                    HStack(spacing: 12) {
                                        // Icon Box
                                        ZStack {
                                            RoundedRectangle(cornerRadius: 8)
                                                .fill(isSelected ? skin.ledColor.opacity(0.2) : Color.white.opacity(0.05))
                                                .frame(width: 44, height: 44)
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 8)
                                                        .stroke(isSelected ? skin.ledColor : Color.white.opacity(0.1), lineWidth: 1)
                                                )

                                            Image(systemName: genre.icon)
                                                .font(.system(size: 20))
                                                .foregroundColor(isSelected ? skin.ledColor : .gray)
                                        }

                                        // Text Info
                                        VStack(alignment: .leading, spacing: 3) {
                                            HStack(spacing: 6) {
                                                Text(genre.rawValue)
                                                    .font(.system(size: 16, weight: .bold))
                                                    .foregroundColor(isSelected ? .white : .gray)

                                                Text("• " + genre.englishTitle)
                                                    .font(.system(size: 11, weight: .medium))
                                                    .foregroundColor(isSelected ? skin.ledColor.opacity(0.9) : .gray.opacity(0.7))
                                            }

                                            Text(artistPreviewFor(genre))
                                                .font(.system(size: 10))
                                                .foregroundColor(.gray)
                                                .lineLimit(1)
                                        }

                                        Spacer()

                                        // Checkbox Indicator
                                        ZStack {
                                            RoundedRectangle(cornerRadius: 6)
                                                .fill(isSelected ? skin.ledColor : Color.clear)
                                                .frame(width: 24, height: 24)
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 6)
                                                        .stroke(isSelected ? skin.ledColor : Color.gray.opacity(0.5), lineWidth: 1.5)
                                                )

                                            if isSelected {
                                                Image(systemName: "checkmark")
                                                    .font(.system(size: 13, weight: .black))
                                                    .foregroundColor(.black)
                                            }
                                        }
                                    }
                                    .padding(12)
                                    .background(isSelected ? skin.lcdBackground : Color.black.opacity(0.3))
                                    .cornerRadius(10)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(isSelected ? skin.ledColor.opacity(0.8) : Color.white.opacity(0.08), lineWidth: isSelected ? 1.5 : 1)
                                    )
                                }
                                .padding(.horizontal, 16)
                            }
                        }
                        .padding(.bottom, 20)
                    }

                    // Bottom Action Bar
                    VStack(spacing: 8) {
                        Divider()
                            .background(Color.white.opacity(0.15))

                        HStack {
                            let selectedNames = engine.selectedGenres.map { $0.rawValue }.joined(separator: " + ")
                            Text("กำลังเลือก: \(selectedNames.isEmpty ? "ไม่มี" : selectedNames)")
                                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                .foregroundColor(skin.ledColor)
                                .lineLimit(1)
                            Spacer()
                        }
                        .padding(.horizontal, 16)

                        Button(action: {
                            let gen = UINotificationFeedbackGenerator()
                            gen.notificationOccurred(.success)
                            engine.loadGenreMix(autoPlay: true)
                            presentationMode.wrappedValue.dismiss()
                        }) {
                            HStack(spacing: 8) {
                                if engine.isFetchingGenreMix {
                                    ProgressView()
                                        .tint(.black)
                                } else {
                                    Image(systemName: "sparkles")
                                        .font(.system(size: 14, weight: .bold))
                                }

                                Text(engine.isFetchingGenreMix ? "กำลังดึงรายการเพลง..." : "⚡ สร้างเพลย์ลิสต์ผสม & เล่นทันที (PLAY MIX)")
                                    .font(.system(size: 13, weight: .black, design: .monospaced))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(skin.ledColor)
                            .foregroundColor(.black)
                            .cornerRadius(10)
                            .shadow(color: skin.ledColor.opacity(0.4), radius: 6, x: 0, y: 2)
                        }
                        .disabled(engine.isFetchingGenreMix || engine.selectedGenres.isEmpty)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 12)
                    }
                    .background(Color(red: 0.05, green: 0.06, blue: 0.09))
                }
            }
            .navigationTitle("Music Genre Mixer")
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

    private func artistPreviewFor(_ genre: MusicGenre) -> String {
        switch genre {
        case .userFeed:
            return "คัดกรองเพลงตรงจากฟีดโปรไฟล์ YouTube ส่วนตัวของคุณ (กรองเฉพาะเพลงจริง 100%)"
        case .string:
            return "Three Man Down, BOWKYLION, NONT TANONT, Billkin, Jeff Satur, 4EVE"
        case .lukThung:
            return "ไผ่ พงศธร, มนต์แคน แก่นคูน, ต่าย อรทัย, เบลล์ นิภาดา, ลำเพลิน วงศกร"
        case .pueaChiwit:
            return "คาราบาว, ปู พงษ์สิทธิ์ คำภีร์, มาลีฮวนน่า, คนด่านเกวียน, คาราวาน"
        case .inter:
            return "Billboard Hot 100, Taylor Swift, Bruno Mars, Ed Sheeran, Billie Eilish"
        case .rock:
            return "BODYSLAM, Potato, Cocktail, Paper Planes, Silly Fools, Lomosonic"
        case .indie:
            return "Safeplanet, Dept, Anatomy Rabbit, Tilly Birds, Television off, Purpeech"
        }
    }
}
