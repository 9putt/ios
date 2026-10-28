import SwiftUI

public struct WinampPlaylistWindow: View {
    @ObservedObject var engine = WinampPlayerEngine.shared
    @State private var showAddMenu: Bool = false
    @State private var showRemMenu: Bool = false

    public var body: some View {
        let skin = engine.currentSkin

        WinampWindowFrame(
            title: "WINAMP PLAYLIST",
            skin: skin,
            onClose: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    engine.showPlaylistWindow = false
                }
            }
        ) {
            VStack(spacing: 6) {
                // TRACK LIST TABLE
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 1) {
                            if engine.playlist.isEmpty {
                                VStack(spacing: 8) {
                                    Image(systemName: "music.note.list")
                                        .font(.system(size: 28))
                                        .foregroundColor(skin.titleBarTextColor.opacity(0.4))
                                    Text("Playlist is Empty\nTap '+ ADD' to add songs or fetch YouTube music feed")
                                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                                        .multilineTextAlignment(.center)
                                        .foregroundColor(skin.titleBarTextColor.opacity(0.6))
                                }
                                .padding(.vertical, 30)
                            } else {
                                ForEach(Array(engine.playlist.enumerated()), id: \.element.id) { index, track in
                                    let isCurrent = (index == engine.currentIndex)
                                    
                                    Button(action: {
                                        let gen = UIImpactFeedbackGenerator(style: .medium)
                                        gen.impactOccurred()
                                        engine.playTrack(at: index)
                                    }) {
                                        HStack(spacing: 6) {
                                            // Play indicator / track index
                                            if isCurrent && engine.isPlaying {
                                                Image(systemName: "speaker.wave.2.fill")
                                                    .font(.system(size: 9, weight: .bold))
                                                    .foregroundColor(skin.ledColor)
                                            } else {
                                                Text(String(format: "%d.", index + 1))
                                                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                                                    .foregroundColor(isCurrent ? skin.ledColor : skin.titleBarTextColor.opacity(0.8))
                                                    .frame(width: 20, alignment: .leading)
                                            }

                                            // Song Title & Source tag
                                            Text(track.displayTitle)
                                                .font(.system(size: 10, weight: isCurrent ? .black : .bold, design: .monospaced))
                                                .foregroundColor(isCurrent ? Color.white : skin.titleBarTextColor)
                                                .lineLimit(1)

                                            if track.isLocal {
                                                Text("LOCAL")
                                                    .font(.system(size: 7, weight: .black))
                                                    .padding(.horizontal, 3)
                                                    .padding(.vertical, 1)
                                                    .background(Color.blue.opacity(0.6))
                                                    .foregroundColor(.white)
                                                    .cornerRadius(2)
                                            }

                                            Spacer()

                                            // Track Duration
                                            Text(track.formattedDuration)
                                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                                .foregroundColor(isCurrent ? skin.ledColor : skin.titleBarTextColor.opacity(0.7))
                                        }
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 4)
                                        .background(
                                            isCurrent
                                                ? Color(red: 0.12, green: 0.28, blue: 0.45)
                                                : (index % 2 == 0 ? Color.black.opacity(0.4) : Color.black.opacity(0.2))
                                        )
                                        .overlay(
                                            Rectangle()
                                                .stroke(isCurrent ? skin.ledColor.opacity(0.8) : Color.clear, lineWidth: 1)
                                        )
                                    }
                                    .id(track.id)
                                }
                            }
                        }
                    }
                    .frame(maxHeight: 180)
                    .background(skin.lcdBackground)
                    .border(Color(white: 0.25), width: 1)
                    .onChange(of: engine.currentIndex) { newIdx in
                        if newIdx < engine.playlist.count {
                            withAnimation {
                                proxy.scrollTo(engine.playlist[newIdx].id, anchor: .center)
                            }
                        }
                    }
                }

                // BOTTOM ACTION TOOLBAR (+ ADD, - REM, SEL, FADE, TIME STATS)
                HStack(spacing: 4) {
                    // + ADD BUTTON
                    WinampButton("+ ADD", skin: skin) {
                        showAddMenu = true
                    }

                    // - REM BUTTON
                    WinampButton("- REM", skin: skin) {
                        showRemMenu = true
                    }

                    // FADE BUTTON
                    WinampButton("FADE: \(String(format: "%.1fs", engine.crossfadeDuration))", isActive: engine.isCrossfadeEnabled, activeColor: skin.ledColor, skin: skin) {
                        engine.showCrossfadeSheet = true
                    }

                    Spacer()

                    // PLAYLIST STATS (Tracks count / Total Time)
                    HStack(spacing: 2) {
                        let totalSec = engine.playlist.reduce(0) { $0 + $1.duration }
                        let min = Int(totalSec) / 60
                        let sec = Int(totalSec) % 60
                        Text(String(format: "%d trk / %d:%02d", engine.playlist.count, min, sec))
                            .font(.system(size: 8, weight: .bold, design: .monospaced))
                            .foregroundColor(skin.ledColor)
                    }
                    .padding(.horizontal, 4)
                    .padding(.vertical, 3)
                    .background(skin.lcdBackground)
                    .border(Color(white: 0.3), width: 0.5)
                }
                .padding(.horizontal, 2)
            }
        }
        .confirmationDialog("Add Songs", isPresented: $showAddMenu, titleVisibility: .visible) {
            Button("Add Local Audio File(s)...") {
                engine.showAddFilePicker = true
            }
            Button("Add Music Folder...") {
                engine.showAddFolderPicker = true
            }
            Button("Search YouTube Music...") {
                engine.showSearchSheet = true
            }
            Button("Refresh YouTube Music Feed") {
                // Fetch fresh music recommendations from YouTube
                engine.showYouTubeLoginSheet = true
            }
            Button("Cancel", role: .cancel) {}
        }
        .confirmationDialog("Remove", isPresented: $showRemMenu, titleVisibility: .visible) {
            Button("Remove Current Track", role: .destructive) {
                engine.removeTrack(at: engine.currentIndex)
            }
            Button("Clear Entire Playlist", role: .destructive) {
                engine.clearPlaylist()
            }
            Button("Cancel", role: .cancel) {}
        }
    }
}
