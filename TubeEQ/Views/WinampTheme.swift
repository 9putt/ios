import SwiftUI

// MARK: - Winamp Window Frame (Beveled borders, metallic title bar with screws)
public struct WinampWindowFrame<Content: View>: View {
    public let title: String
    public let skin: WinampSkinPreset
    public var onClose: (() -> Void)? = nil
    public var onMinimize: (() -> Void)? = nil
    public var onWindowshade: (() -> Void)? = nil
    @ViewBuilder public let content: () -> Content

    public init(
        title: String,
        skin: WinampSkinPreset = .classicModern,
        onClose: (() -> Void)? = nil,
        onMinimize: (() -> Void)? = nil,
        onWindowshade: (() -> Void)? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self.skin = skin
        self.onClose = onClose
        self.onMinimize = onMinimize
        self.onWindowshade = onWindowshade
        self.content = content
    }

    public var body: some View {
        VStack(spacing: 0) {
            // TITLE BAR
            HStack(spacing: 4) {
                // Top-left tiny bolt icon
                Image(systemName: "bolt.fill")
                    .font(.system(size: 9, weight: .black))
                    .foregroundColor(skin.titleBarTextColor)
                    .padding(.leading, 6)

                Text(title)
                    .font(.system(size: 10, weight: .heavy))
                    .foregroundColor(skin.titleBarTextColor)
                    .lineLimit(1)

                Spacer()

                // Minimize / Shade / Close buttons
                HStack(spacing: 3) {
                    if let onMinimize = onMinimize {
                        Button(action: onMinimize) {
                            Text("_")
                                .font(.system(size: 9, weight: .black))
                                .frame(width: 13, height: 13)
                                .background(Color.white.opacity(0.15))
                                .foregroundColor(skin.titleBarTextColor)
                                .border(Color.black, width: 0.5)
                        }
                    }

                    if let onWindowshade = onWindowshade {
                        Button(action: onWindowshade) {
                            Text("=")
                                .font(.system(size: 9, weight: .black))
                                .frame(width: 13, height: 13)
                                .background(Color.white.opacity(0.15))
                                .foregroundColor(skin.titleBarTextColor)
                                .border(Color.black, width: 0.5)
                        }
                    }

                    if let onClose = onClose {
                        Button(action: onClose) {
                            Text("X")
                                .font(.system(size: 9, weight: .black))
                                .frame(width: 13, height: 13)
                                .background(Color.red.opacity(0.8))
                                .foregroundColor(.white)
                                .border(Color.black, width: 0.5)
                        }
                    }
                }
                .padding(.trailing, 4)
            }
            .frame(height: 20)
            .background(skin.titleBarGradient)
            .overlay(
                Rectangle()
                    .stroke(skin.borderLight, lineWidth: 0.8)
            )

            // WINDOW CONTENT
            content()
                .padding(6)
                .background(skin.windowBackground)
        }
        .overlay(
            // Beveled outer metallic border
            RoundedRectangle(cornerRadius: 3)
                .strokeBorder(
                    LinearGradient(
                        colors: [skin.borderLight, skin.borderDark],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.5
                )
        )
        .cornerRadius(3)
        .shadow(color: Color.black.opacity(0.6), radius: 5, x: 0, y: 3)
    }
}

// MARK: - Winamp Tactile Button
public struct WinampButton: View {
    public let text: String
    public var icon: String? = nil
    public var isActive: Bool = false
    public var activeColor: Color = .green
    public var skin: WinampSkinPreset = .classicModern
    public var action: () -> Void

    public init(
        _ text: String = "",
        icon: String? = nil,
        isActive: Bool = false,
        activeColor: Color = .green,
        skin: WinampSkinPreset = .classicModern,
        action: @escaping () -> Void
    ) {
        self.text = text
        self.icon = icon
        self.isActive = isActive
        self.activeColor = activeColor
        self.skin = skin
        self.action = action
    }

    public var body: some View {
        Button(action: {
            let gen = UIImpactFeedbackGenerator(style: .light)
            gen.impactOccurred()
            action()
        }) {
            HStack(spacing: 3) {
                if isActive {
                    Circle()
                        .fill(activeColor)
                        .frame(width: 5, height: 5)
                        .shadow(color: activeColor, radius: 2)
                }

                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 9, weight: .bold))
                }

                if !text.isEmpty {
                    Text(text)
                        .font(.system(size: 9, weight: .bold))
                }
            }
            .foregroundColor(isActive ? activeColor : skin.titleBarTextColor)
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .background(skin.buttonBackground)
            .overlay(
                Rectangle()
                    .stroke(isActive ? activeColor.opacity(0.6) : skin.borderLight, lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.4), radius: 1, x: 0, y: 1)
        }
    }
}

// MARK: - Winamp Marquee Ticker
public struct WinampMarquee: View {
    public let text: String
    public var color: Color = Color(red: 0.0, green: 1.0, blue: 0.35)
    @State private var offset: CGFloat = 0

    public var body: some View {
        GeometryReader { geo in
            let fullText = "\(text)   ***   WINAMP   ***   "
            HStack(spacing: 0) {
                Text(fullText + fullText)
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(color)
                    .offset(x: offset)
                    .fixedSize()
            }
            .onAppear {
                withAnimation(.linear(duration: 12.0).repeatForever(autoreverses: false)) {
                    offset = -geo.size.width * 1.5
                }
            }
        }
        .clipped()
        .frame(height: 15)
    }
}

// MARK: - Winamp 7-Segment Digital Clock
public struct WinampSevenSegmentClock: View {
    public let time: TimeInterval
    public let isRemaining: Bool
    public var color: Color = Color(red: 0.0, green: 1.0, blue: 0.35)

    public var body: some View {
        let total = Int(abs(time))
        let minutes = total / 60
        let seconds = total % 60
        let sign = isRemaining ? "-" : " "
        let formatted = String(format: "%@%02d:%02d", sign, minutes, seconds)

        HStack(spacing: 2) {
            Text(formatted)
                .font(.system(size: 20, weight: .heavy, design: .monospaced))
                .foregroundColor(color)
                .shadow(color: color.opacity(0.6), radius: 3)
                .tracking(1.0)
        }
    }
}

// MARK: - Winamp Spectrum Analyzer Bars (Placed directly beneath the video)
public struct WinampSpectrumView: View {
    public let magnitudes: [Float]
    public var colors: [Color] = [.green, .yellow, .red]
    public var height: CGFloat = 36

    public var body: some View {
        HStack(alignment: .bottom, spacing: 2) {
            ForEach(0..<magnitudes.count, id: \.self) { i in
                let mag = CGFloat(max(0.05, min(1.0, magnitudes[i])))
                VStack(spacing: 1) {
                    Spacer(minLength: 0)
                    // Peak hold line
                    Rectangle()
                        .fill(colors.last ?? .red)
                        .frame(height: 1.5)
                        .opacity(mag > 0.1 ? 1.0 : 0.0)

                    // Vertical Bar with Green -> Yellow -> Red gradient
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: colors,
                                startPoint: .bottom,
                                endPoint: .top
                            )
                        )
                        .frame(height: max(2, (height - 3) * mag))
                }
                .frame(maxWidth: .infinity, maxHeight: height)
                .background(Color.black.opacity(0.3))
            }
        }
        .frame(height: height)
        .padding(2)
        .background(Color(red: 0.02, green: 0.03, blue: 0.05))
        .border(Color(white: 0.18), width: 1)
    }
}

// MARK: - Winamp Horizontal Slider (Volume & Balance)
public struct WinampHorizontalSlider: View {
    @Binding var value: Double
    public let range: ClosedRange<Double>
    public let title: String
    public var accentColor: Color = .cyan
    public var skin: WinampSkinPreset = .classicModern

    public var body: some View {
        VStack(spacing: 2) {
            HStack {
                Text(title.uppercased())
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .foregroundColor(skin.titleBarTextColor)
                Spacer()
                Text(String(format: "%.0f%%", (value - range.lowerBound) / (range.upperBound - range.lowerBound) * 100))
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .foregroundColor(skin.ledColor)
            }

            GeometryReader { geo in
                let width = geo.size.width
                let progress = CGFloat((value - range.lowerBound) / (range.upperBound - range.lowerBound))
                let clampedProgress = max(0, min(1, progress))

                ZStack(alignment: .leading) {
                    // Track Groove
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.black)
                        .frame(height: 7)
                        .overlay(
                            RoundedRectangle(cornerRadius: 2)
                                .stroke(Color(white: 0.25), lineWidth: 0.8)
                        )

                    // Progress fill
                    RoundedRectangle(cornerRadius: 2)
                        .fill(accentColor)
                        .frame(width: max(0, width * clampedProgress), height: 5)
                        .padding(.horizontal, 1)

                    // Metallic Thumb Knob
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(
                            LinearGradient(
                                colors: [Color(white: 0.85), Color(white: 0.45)],
                                startPoint: .top, endPoint: .bottom
                            )
                        )
                        .frame(width: 14, height: 12)
                        .overlay(
                            Rectangle()
                                .fill(Color.red)
                                .frame(width: 2, height: 6)
                        )
                        .border(Color.black, width: 0.8)
                        .offset(x: max(0, min(width - 14, (width - 14) * clampedProgress)))
                }
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { gesture in
                            let normalized = Double(gesture.location.x / width)
                            let clamped = max(0.0, min(1.0, normalized))
                            value = range.lowerBound + clamped * (range.upperBound - range.lowerBound)
                        }
                )
            }
            .frame(height: 14)
        }
    }
}

// MARK: - Winamp Vertical Slider (Preamp & 10 EQ Bands)
public struct WinampVerticalSlider: View {
    @Binding var value: Float
    public let label: String
    public var skin: WinampSkinPreset = .classicModern

    public var body: some View {
        VStack(spacing: 3) {
            Text(label)
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .foregroundColor(skin.titleBarTextColor)
                .lineLimit(1)
                .fixedSize()

            GeometryReader { geo in
                let height = geo.size.height
                // value is between -12 and +12 dB
                let progress = CGFloat((value + 12.0) / 24.0)
                let clampedProgress = max(0.0, min(1.0, progress))
                let knobY = (1.0 - clampedProgress) * (height - 18)

                ZStack(alignment: .top) {
                    // Track Groove with Center Detent
                    Rectangle()
                        .fill(Color.black)
                        .frame(width: 4)
                        .overlay(
                            Rectangle().stroke(Color(white: 0.25), lineWidth: 0.5)
                        )
                        .frame(maxWidth: .infinity)

                    // Center 0dB mark line
                    Rectangle()
                        .fill(Color.white.opacity(0.4))
                        .frame(width: 10, height: 1)
                        .offset(y: height / 2)

                    // Metallic Grooved Thumb Knob
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(
                            LinearGradient(
                                colors: [Color(white: 0.88), Color(white: 0.40)],
                                startPoint: .top, endPoint: .bottom
                            )
                        )
                        .frame(width: 18, height: 14)
                        .overlay(
                            Rectangle()
                                .fill(value > 0.5 ? Color.green : (value < -0.5 ? Color.orange : Color.white))
                                .frame(width: 8, height: 1.5)
                        )
                        .border(Color.black, width: 0.8)
                        .shadow(color: .black.opacity(0.5), radius: 1, x: 0, y: 1)
                        .offset(y: knobY)
                }
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { gesture in
                            let normalized = 1.0 - (gesture.location.y / height)
                            let clamped = max(0.0, min(1.0, normalized))
                            value = Float(-12.0 + clamped * 24.0)
                        }
                )
            }
            .frame(width: 24, height: 95)

            // Value text
            Text(String(format: "%+.0fdB", value))
                .font(.system(size: 7, weight: .bold, design: .monospaced))
                .foregroundColor(value == 0 ? skin.titleBarTextColor : skin.ledColor)
        }
    }
}
