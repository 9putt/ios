import SwiftUI

public struct WinampMainWindow: View {
    @ObservedObject var engine = WinampPlayerEngine.shared

    public var body: some View {
        let skin = engine.currentSkin

        WinampWindowFrame(
            title: "WINAMP CLASSIC MODERN lite version 1.03",
            skin: skin,
            onClose: {},
            onMinimize: {},
            onWindowshade: {}
        ) {
            VStack(spacing: 6) {
                
                // MAIN LCD DISPLAY AREA (Deep black with authentic glowing elements)
                VStack(spacing: 4) {
                    
                    // 1. TOP MARQUEE: SCROLLING SONG TITLE OR STATUS
                    HStack(spacing: 6) {
                        Button(action: { engine.showSkinPickerSheet = true }) {
                            Image(systemName: "bolt.fill")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(skin.ledColor)
                        }

                        let titleText = engine.customStatusMessage ?? (engine.currentTrack != nil ? engine.currentTrack!.displayTitle : "WINAMP - SEARCH YOUTUBE OR ADD FILES TO PLAY")
                        WinampMarquee(text: titleText, color: skin.marqueeColor)
                    }
                    .padding(.horizontal, 4)
                    .padding(.top, 2)

                    // 2. MIDDLE SPLIT: 50/50 SPLIT (EXPANDED VIDEO BOX + COMPACT SCRUBBER & TIME)
                    HStack(alignment: .top, spacing: 6) {
                        
                        // LEFT COLUMN (50% WIDTH): ALBUM / THUMBNAIL DISPLAY WITH SPECTRUM DIRECTLY UNDERNEATH
                        VStack(spacing: 3) {
                            ZStack {
                                Color.black

                                if let track = engine.currentTrack, let vid = track.videoId, !vid.isEmpty {
                                    AsyncImage(url: URL(string: "https://img.youtube.com/vi/\(vid)/hqdefault.jpg")) { phase in
                                        switch phase {
                                        case .success(let image):
                                            image
                                                .resizable()
                                                .aspectRatio(contentMode: .fill)
                                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                                .clipped()
                                        default:
                                            albumPlaceholderView(skin: skin)
                                        }
                                    }
                                    .overlay(
                                        Image(systemName: "opticaldisc.fill")
                                            .font(.system(size: 16))
                                            .foregroundColor(skin.ledColor.opacity(0.9))
                                            .rotationEffect(.degrees(engine.isPlaying ? 360 : 0))
                                            .animation(engine.isPlaying ? .linear(duration: 3).repeatForever(autoreverses: false) : .default, value: engine.isPlaying)
                                            .padding(4),
                                        alignment: .topTrailing
                                    )
                                } else {
                                    albumPlaceholderView(skin: skin)
                                }
                            }
                            .frame(height: 96)
                            .frame(maxWidth: .infinity)
                            .cornerRadius(2)
                            .overlay(
                                Rectangle()
                                    .stroke(Color(white: 0.25), lineWidth: 1)
                            )

                            // REAL-TIME SPECTRUM ANALYZER (EXPANDED TO MATCH 50% VIDEO WIDTH)
                            WinampSpectrumView(
                                magnitudes: engine.spectrumBars,
                                colors: skin.spectrumColors,
                                height: 26,
                                isTransparent: skin.isLiquidGlass
                            )
                            .frame(height: 26)
                            .frame(maxWidth: .infinity)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)

                        // RIGHT COLUMN (50% WIDTH): 7-SEGMENT LED TIME + BITRATE + STEREO INDICATORS + COMPACT SCRUBBER
                        VStack(alignment: .leading, spacing: 0) {
                            // 7-SEGMENT LED CLOCK
                            Button(action: {
                                engine.isTimeRemaining.toggle()
                            }) {
                                HStack(spacing: 4) {
                                    let displayTime = engine.isTimeRemaining ? (engine.duration - engine.currentTime) : engine.currentTime
                                    WinampSevenSegmentClock(time: displayTime, isRemaining: engine.isTimeRemaining, color: skin.ledColor)
                                    
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(engine.isTimeRemaining ? "REM" : "ELAP")
                                            .font(.system(size: 7, weight: .bold, design: .monospaced))
                                            .foregroundColor(skin.ledColor.opacity(0.8))
                                        Text(engine.isPlaying ? "PLAY" : "PAUSE")
                                            .font(.system(size: 7, weight: .bold, design: .monospaced))
                                            .foregroundColor(engine.isPlaying ? skin.ledColor : Color.orange)
                                    }
                                }
                            }

                            // TECHNICAL SPECS: kbps, kHz, STEREO/MONO
                            HStack(spacing: 8) {
                                VStack(alignment: .leading, spacing: 1) {
                                    Text("320 kbps")
                                        .font(.system(size: 9, weight: .black, design: .monospaced))
                                        .foregroundColor(skin.ledColor)
                                    Text("44 kHz")
                                        .font(.system(size: 9, weight: .black, design: .monospaced))
                                        .foregroundColor(skin.ledColor)
                                }

                                VStack(alignment: .leading, spacing: 1) {
                                    Text("STEREO")
                                        .font(.system(size: 8, weight: .heavy, design: .monospaced))
                                        .foregroundColor(skin.ledColor)
                                    Text("MONO")
                                        .font(.system(size: 8, weight: .heavy, design: .monospaced))
                                        .foregroundColor(Color.white.opacity(0.15))
                                }
                            }
                            .padding(.top, 4)

                            Spacer(minLength: 0)

                            // TRACK PROGRESS SCRUBBER (LEVEL WITH SPECTRUM ANALYZER, EXACT 26PT HEIGHT)
                            VStack(spacing: 3) {
                                GeometryReader { geo in
                                    let w = geo.size.width
                                    let progress = engine.duration > 0 ? CGFloat(engine.currentTime / engine.duration) : 0.0
                                    let clamped = max(0.0, min(1.0, progress))

                                    ZStack(alignment: .leading) {
                                        Rectangle()
                                            .fill(skin.isLiquidGlass ? Color.white.opacity(0.15) : Color.black)
                                            .border(skin.isLiquidGlass ? Color.white.opacity(0.35) : Color(white: 0.3), width: 0.5)

                                        Rectangle()
                                            .fill(skin.sliderAccentColor)
                                            .frame(width: w * clamped)
                                    }
                                    .contentShape(Rectangle())
                                    .gesture(
                                        DragGesture(minimumDistance: 0)
                                            .onChanged { g in
                                                let frac = Double(g.location.x / w)
                                                let target = max(0.0, min(engine.duration, frac * engine.duration))
                                                engine.seek(to: target)
                                            }
                                    )
                                }
                                .frame(height: 9)

                                HStack {
                                    Text(formatTime(engine.currentTime))
                                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                                        .foregroundColor(skin.ledColor)
                                    Spacer()
                                    Text(formatTime(engine.duration))
                                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                                        .foregroundColor(skin.ledColor)
                                }
                            }
                            .frame(height: 26)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                    }
                    .frame(height: 125)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                }
                .padding(4)
                .background(
                    Group {
                        if skin.isLiquidGlass {
                            Color.clear
                        } else {
                            skin.lcdBackground
                        }
                    }
                )
                .overlay(
                    Rectangle()
                        .stroke(skin.isLiquidGlass ? Color.white.opacity(0.30) : Color(white: 0.2), lineWidth: 1)
                )

                // SLIDERS: VOLUME & BALANCE (Guaranteed Direct Hardware Control)
                HStack(spacing: 12) {
                    WinampHorizontalSlider(
                        value: Binding(
                            get: { engine.volume },
                            set: { engine.setVolume($0) }
                        ),
                        range: 0.0...1.0,
                        title: "Volume",
                        accentColor: skin.sliderAccentColor,
                        skin: skin
                    )

                    WinampHorizontalSlider(
                        value: Binding(
                            get: { engine.balance },
                            set: { engine.setBalance($0) }
                        ),
                        range: -1.0...1.0,
                        title: "Balance",
                        accentColor: skin.sliderAccentColor,
                        skin: skin
                    )

                    // EQ & PL Toggle Buttons
                    HStack(spacing: 4) {
                        WinampButton("EQ", isActive: engine.showEqualizerWindow, activeColor: skin.ledColor, skin: skin) {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                engine.showEqualizerWindow.toggle()
                            }
                        }

                        WinampButton("PL", isActive: engine.showPlaylistWindow, activeColor: skin.ledColor, skin: skin) {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                engine.showPlaylistWindow.toggle()
                            }
                        }
                    }
                }
                .padding(.horizontal, 2)

                // TRANSPORT CONTROLS (PREV, PLAY, PAUSE, STOP, NEXT, EJECT) + FADE, SHUFFLE & REPEAT
                HStack(spacing: 5) {
                    // Previous
                    WinampButton(icon: "backward.fill", skin: skin) {
                        engine.previousTrack()
                    }

                    // Play
                    WinampButton(icon: "play.fill", isActive: engine.isPlaying, activeColor: skin.ledColor, skin: skin) {
                        engine.resume()
                    }

                    // Pause
                    WinampButton(icon: "pause.fill", isActive: !engine.isPlaying && engine.currentTime > 0, activeColor: .orange, skin: skin) {
                        engine.pause()
                    }

                    // Stop
                    WinampButton(icon: "stop.fill", skin: skin) {
                        engine.stop()
                    }

                    // Next
                    WinampButton(icon: "forward.fill", skin: skin) {
                        engine.nextTrack()
                    }

                    // Eject / Open
                    WinampButton(icon: "eject.fill", skin: skin) {
                        engine.showAddFilePicker = true
                    }

                    Spacer()

                    // Crossfade Toggle
                    WinampButton("FADE", isActive: engine.isCrossfadeEnabled, activeColor: skin.ledColor, skin: skin) {
                        engine.showCrossfadeSheet = true
                    }

                    // Shuffle
                    WinampButton("SHUFFLE", isActive: engine.isShuffle, activeColor: skin.ledColor, skin: skin) {
                        engine.isShuffle.toggle()
                    }

                    // Repeat
                    WinampButton("REPEAT", isActive: engine.isRepeat, activeColor: skin.ledColor, skin: skin) {
                        engine.isRepeat.toggle()
                    }
                }
                .padding(.horizontal, 2)
            }
        }
    }

    private func formatTime(_ sec: TimeInterval) -> String {
        let t = Int(abs(sec))
        return String(format: "%d:%02d", t / 60, t % 60)
    }

    private func extractVideoID(from url: String) -> String? {
        if url.contains("v=") {
            let parts = url.components(separatedBy: "v=")
            if let idPart = parts.last?.components(separatedBy: "&").first {
                return idPart
            }
        } else if url.contains("youtu.be/") {
            let parts = url.components(separatedBy: "youtu.be/")
            if let idPart = parts.last?.components(separatedBy: "?").first {
                return idPart
            }
        }
        return nil
    }

    @ViewBuilder
    private func albumPlaceholderView(skin: WinampSkinPreset) -> some View {
        VStack(spacing: 3) {
            Image(systemName: "opticaldisc.fill")
                .font(.system(size: 26))
                .foregroundColor(skin.ledColor.opacity(0.85))
                .rotationEffect(.degrees(engine.isPlaying ? 360 : 0))
                .animation(engine.isPlaying ? .linear(duration: 3).repeatForever(autoreverses: false) : .default, value: engine.isPlaying)
            Text(engine.currentTrack?.artist ?? "WINAMP PRO")
                .font(.system(size: 7, weight: .bold, design: .monospaced))
                .foregroundColor(skin.ledColor)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
    }
}
