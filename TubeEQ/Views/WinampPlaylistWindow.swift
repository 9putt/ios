import SwiftUI

public struct WinampPlaylistWindow: View {
    @ObservedObject var engine = WinampPlayerEngine.shared
    @State private var searchText: String = ""
    @State private var isSearching: Bool = false
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
            VStack(spacing: 2) {
                
                // 1. INLINE YOUTUBE SEARCH BAR AT THE TOP OF PLAYLIST
                HStack(spacing: 4) {
                    HStack(spacing: 4) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(skin.ledColor)

                        TextField("Search single music tracks...", text: $searchText, onCommit: {
                            performYouTubeSearch()
                        })
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(skin.titleBarTextColor)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)

                        if isSearching {
                            ProgressView()
                                .scaleEffect(0.6)
                        } else if !searchText.isEmpty {
                            Button(action: {
                                searchText = ""
                                dismissKeyboard()
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 10))
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(skin.isLiquidGlass ? Color.white.opacity(0.12) : skin.lcdBackground)
                    .border(skin.isLiquidGlass ? Color.white.opacity(0.35) : Color(white: 0.25), width: 1)

                    // Search Action Button
                    WinampButton("SEARCH", skin: skin) {
                        performYouTubeSearch()
                    }
                }
                .padding(.horizontal, 2)
                .padding(.top, 1)

                // 1.5 INLINE GENRE SELECTOR & MIX BAR
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 5) {
                        // Mix / Play button
                        Button(action: {
                            dismissKeyboard()
                            let gen = UIImpactFeedbackGenerator(style: .medium)
                            gen.impactOccurred()
                            engine.loadGenreMix(autoPlay: true)
                        }) {
                            HStack(spacing: 3) {
                                if engine.isFetchingGenreMix {
                                    ProgressView()
                                        .scaleEffect(0.6)
                                        .tint(skin.lcdBackground)
                                } else {
                                    Image(systemName: "sparkles")
                                        .font(.system(size: 9, weight: .bold))
                                }
                                Text(engine.isFetchingGenreMix ? "MIXING..." : "⚡ MIX (\(engine.selectedGenres.count))")
                                    .font(.system(size: 10, weight: .black, design: .monospaced))
                            }
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3.5)
                            .background(skin.ledColor)
                            .foregroundColor(skin.lcdBackground)
                            .cornerRadius(3)
                        }
                        .disabled(engine.isFetchingGenreMix || engine.selectedGenres.isEmpty)

                        // Genre Pills
                        ForEach(MusicGenre.allCases) { genre in
                            let isSelected = engine.isGenreSelected(genre)
                            Button(action: {
                                dismissKeyboard()
                                let gen = UIImpactFeedbackGenerator(style: .light)
                                gen.impactOccurred()
                                engine.toggleGenre(genre)
                            }) {
                                HStack(spacing: 3) {
                                    Image(systemName: genre.icon)
                                        .font(.system(size: 8))
                                    Text(genre.rawValue)
                                        .font(.system(size: 10, weight: isSelected ? .bold : .medium))
                                }
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3.5)
                                .background(isSelected ? skin.ledColor.opacity(0.25) : skin.lcdBackground)
                                .foregroundColor(isSelected ? skin.ledColor : skin.titleBarTextColor.opacity(0.8))
                                .border(isSelected ? skin.ledColor : Color(white: 0.25), width: 1)
                            }
                        }

                        // Customize button
                        Button(action: {
                            dismissKeyboard()
                            engine.showGenrePickerSheet = true
                        }) {
                            HStack(spacing: 3) {
                                Image(systemName: "slider.horizontal.3")
                                    .font(.system(size: 9))
                                Text("CUSTOM")
                                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                            }
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3.5)
                            .background(Color.white.opacity(0.08))
                            .foregroundColor(skin.titleBarTextColor)
                            .border(Color(white: 0.3), width: 0.8)
                        }
                    }
                    .padding(.horizontal, 2)
                    .padding(.vertical, 2)
                }

                // 2. TRACK LIST TABLE (EXPANDS DOWN TO FILL VERTICAL SPACE + INFINITE SCROLL)
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 1) {
                            if engine.playlist.isEmpty {
                                VStack(spacing: 8) {
                                    Image(systemName: "music.note.list")
                                        .font(.system(size: 30))
                                        .foregroundColor(skin.titleBarTextColor.opacity(0.35))
                                    Text("Playlist is Empty\nSearch YouTube above or tap '+ ADD' to import music")
                                        .font(.system(size: 11, weight: .bold))
                                        .multilineTextAlignment(.center)
                                        .foregroundColor(skin.titleBarTextColor.opacity(0.6))
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 35)
                            } else {
                                ForEach(Array(engine.playlist.enumerated()), id: \.element.id) { index, track in
                                    let isCurrent = (index == engine.currentIndex)
                                    
                                    Button(action: {
                                        dismissKeyboard()
                                        let gen = UIImpactFeedbackGenerator(style: .medium)
                                        gen.impactOccurred()
                                        engine.playTrack(at: index)
                                    }) {
                                        HStack(spacing: 6) {
                                            if isCurrent && engine.isPlaying {
                                                Image(systemName: "speaker.wave.2.fill")
                                                    .font(.system(size: 10, weight: .bold))
                                                    .foregroundColor(skin.ledColor)
                                                    .frame(width: 22, alignment: .leading)
                                            } else {
                                                Text(String(format: "%d.", index + 1))
                                                    .font(.system(size: 11, weight: .bold))
                                                    .foregroundColor(isCurrent ? skin.ledColor : skin.titleBarTextColor.opacity(0.75))
                                                    .frame(width: 22, alignment: .leading)
                                            }

                                            Text(track.displayTitle)
                                                .font(.system(size: 11, weight: isCurrent ? .heavy : .semibold))
                                                .foregroundColor(isCurrent ? Color.white : skin.titleBarTextColor)
                                                .lineLimit(1)

                                            if track.isLocal {
                                                Text("LOCAL")
                                                    .font(.system(size: 8, weight: .black))
                                                    .padding(.horizontal, 4)
                                                    .padding(.vertical, 1)
                                                    .background(Color.blue.opacity(0.6))
                                                    .foregroundColor(.white)
                                                    .cornerRadius(2)
                                            }

                                            Spacer()

                                            Text(track.formattedDuration)
                                                .font(.system(size: 11, weight: .bold))
                                                .foregroundColor(isCurrent ? skin.ledColor : skin.titleBarTextColor.opacity(0.75))
                                        }
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(
                                            isCurrent
                                                ? Color(red: 0.10, green: 0.28, blue: 0.48)
                                                : (index % 2 == 0 ? Color.black.opacity(0.4) : Color.black.opacity(0.2))
                                        )
                                        .overlay(
                                            Rectangle()
                                                .stroke(isCurrent ? skin.ledColor.opacity(0.75) : Color.clear, lineWidth: 1)
                                        )
                                    }
                                    .id(track.id)
                                    // INFINITE SCROLL TRIGGER: When scrolling near bottom, fetch more music!
                                    .onAppear {
                                        if index >= engine.playlist.count - 3 {
                                            engine.loadMoreYouTubeSongs()
                                        }
                                    }
                                }

                                if engine.isLoadingMore {
                                    HStack(spacing: 6) {
                                        ProgressView()
                                            .scaleEffect(0.7)
                                            .tint(skin.ledColor)
                                        Text("Fetching 20 new tracks from YouTube...")
                                            .font(.system(size: 10, weight: .bold))
                                            .foregroundColor(skin.ledColor)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8)
                                } else {
                                    Button(action: {
                                        let gen = UIImpactFeedbackGenerator(style: .medium)
                                        gen.impactOccurred()
                                        engine.loadMoreYouTubeSongs()
                                    }) {
                                        HStack(spacing: 6) {
                                            Image(systemName: "arrow.down.circle.fill")
                                                .font(.system(size: 11))
                                                .foregroundColor(skin.ledColor)
                                            Text("⬇️ LOAD MORE SONGS (ดึงเพลงเพิ่ม)")
                                                .font(.system(size: 10, weight: .heavy, design: .monospaced))
                                                .foregroundColor(skin.ledColor)
                                        }
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 7)
                                        .background(Color.white.opacity(0.06))
                                        .border(skin.borderLight, width: 0.5)
                                    }
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 4)
                                }
                            }
                        }
                    }
                    .refreshable {
                        await engine.refreshWithNewRandomSongs()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(skin.isLiquidGlass ? Color.black.opacity(0.25).background(.ultraThinMaterial) : skin.lcdBackground)
                    .border(skin.isLiquidGlass ? Color.white.opacity(0.35) : Color(white: 0.22), width: 1)
                    .onTapGesture {
                        dismissKeyboard()
                    }
                    .onChange(of: engine.currentIndex) { newIdx in
                        if newIdx < engine.playlist.count {
                            withAnimation {
                                proxy.scrollTo(engine.playlist[newIdx].id, anchor: .center)
                            }
                        }
                    }
                }

                // 3. BOTTOM METALLIC TOOLBAR (AUTHENTIC WINAMP MODERN CHASSIS)
                HStack(spacing: 4) {
                    // + ADD
                    WinampButton("+ ADD", skin: skin) {
                        dismissKeyboard()
                        showAddMenu = true
                    }

                    // - REM
                    WinampButton("- REM", skin: skin) {
                        dismissKeyboard()
                        showRemMenu = true
                    }

                    // GENRE (Custom Mix)
                    WinampButton("GENRE", isActive: !engine.selectedGenres.isEmpty, activeColor: skin.ledColor, skin: skin) {
                        dismissKeyboard()
                        engine.showGenrePickerSheet = true
                    }

                    // MISC (Skins)
                    WinampButton("MISC", skin: skin) {
                        dismissKeyboard()
                        engine.showSkinPickerSheet = true
                    }

                    // FADE
                    WinampButton("FADE", isActive: engine.isCrossfadeEnabled, activeColor: skin.ledColor, skin: skin) {
                        dismissKeyboard()
                        engine.showCrossfadeSheet = true
                    }

                    Spacer()

                    // PLAYLIST STATS (Tracks count / Total Time)
                    HStack(spacing: 2) {
                        let totalSec = engine.playlist.reduce(0) { $0 + $1.duration }
                        let min = Int(totalSec) / 60
                        let sec = Int(totalSec) % 60
                        Text(String(format: "%d trk / %d:%02d", engine.playlist.count, min, sec))
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundColor(skin.ledColor)
                    }
                    .padding(.horizontal, 5)
                    .padding(.vertical, 3)
                    .background(skin.isLiquidGlass ? Color.white.opacity(0.12) : skin.lcdBackground)
                    .border(skin.isLiquidGlass ? Color.white.opacity(0.35) : Color(white: 0.3), width: 0.5)
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 4)
                .background(skin.titleBarGradient)
                .overlay(
                    Rectangle()
                        .stroke(skin.borderLight, lineWidth: 0.8)
                )
                .padding(.bottom, 2)
            }
            .frame(maxHeight: .infinity)
        }
        .frame(maxHeight: .infinity)
        .confirmationDialog("Add Music & Stream", isPresented: $showAddMenu, titleVisibility: .visible) {
            Button("🔑 Sign In to YouTube (Safari-Linked)") {
                engine.showYouTubeLoginSheet = true
            }
            Button("🎵 Import / Sync My YouTube Feed") {
                engine.showYouTubeLoginSheet = true
            }
            Button("🔍 Search YouTube Track...") {
                engine.showSearchSheet = true
            }
            Button("📁 Add Local Audio File(s)...") {
                engine.showAddFilePicker = true
            }
            Button("📂 Add Music Folder...") {
                engine.showAddFolderPicker = true
            }
            Button("Cancel", role: .cancel) {}
        }
        .confirmationDialog("Remove Tracks", isPresented: $showRemMenu, titleVisibility: .visible) {
            Button("Remove Current Track", role: .destructive) {
                engine.removeTrack(at: engine.currentIndex)
            }
            Button("Clear Entire Playlist", role: .destructive) {
                engine.clearPlaylist()
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    private func performYouTubeSearch() {
        dismissKeyboard()
        let trimmed = searchText.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        isSearching = true
        let gen = UIImpactFeedbackGenerator(style: .medium)
        gen.impactOccurred()

        YouTubeSearchManager.shared.search(query: trimmed, filterCompilations: true) { results in
            self.isSearching = false
            if !results.isEmpty {
                self.engine.playlist = results
                self.engine.playTrack(at: 0)
                let notif = UINotificationFeedbackGenerator()
                notif.notificationOccurred(.success)
            }
        }
    }

    private func dismissKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}
