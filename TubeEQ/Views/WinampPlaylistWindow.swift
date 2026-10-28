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
            VStack(spacing: 4) {
                
                // 1. INLINE YOUTUBE SEARCH BAR AT THE TOP OF PLAYLIST (AS REQUESTED!)
                HStack(spacing: 4) {
                    HStack(spacing: 4) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(skin.ledColor)

                        TextField("Search YouTube Music...", text: $searchText, onCommit: {
                            performYouTubeSearch()
                        })
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(skin.titleBarTextColor)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)

                        if isSearching {
                            ProgressView()
                                .scaleEffect(0.6)
                        } else if !searchText.isEmpty {
                            Button(action: { searchText = "" }) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 10))
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(skin.lcdBackground)
                    .border(Color(white: 0.25), width: 1)

                    // Search Action Button
                    WinampButton("SEARCH", skin: skin) {
                        performYouTubeSearch()
                    }
                }
                .padding(.horizontal, 2)
                .padding(.top, 1)

                // 2. TRACK LIST TABLE (EXPANDS DOWN TO FILL THE ENTIRE SCREEN!)
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 1) {
                            if engine.playlist.isEmpty {
                                VStack(spacing: 8) {
                                    Image(systemName: "music.note.list")
                                        .font(.system(size: 32))
                                        .foregroundColor(skin.titleBarTextColor.opacity(0.35))
                                    Text("Playlist is Empty\nType in the search bar above or tap '+ ADD' to import music")
                                        .font(.system(size: 11, weight: .bold))
                                        .multilineTextAlignment(.center)
                                        .foregroundColor(skin.titleBarTextColor.opacity(0.6))
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 40)
                            } else {
                                ForEach(Array(engine.playlist.enumerated()), id: \.element.id) { index, track in
                                    let isCurrent = (index == engine.currentIndex)
                                    
                                    Button(action: {
                                        let gen = UIImpactFeedbackGenerator(style: .medium)
                                        gen.impactOccurred()
                                        engine.playTrack(at: index)
                                    }) {
                                        HStack(spacing: 6) {
                                            // Play indicator or track index
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

                                            // Track Title
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

                                            // Track Duration
                                            Text(track.formattedDuration)
                                                .font(.system(size: 11, weight: .bold))
                                                .foregroundColor(isCurrent ? skin.ledColor : skin.titleBarTextColor.opacity(0.75))
                                        }
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 5)
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
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(skin.lcdBackground)
                    .border(Color(white: 0.22), width: 1)
                    .onChange(of: engine.currentIndex) { newIdx in
                        if newIdx < engine.playlist.count {
                            withAnimation {
                                proxy.scrollTo(engine.playlist[newIdx].id, anchor: .center)
                            }
                        }
                    }
                }

                // 3. BOTTOM ACTION TOOLBAR (+ ADD, - REM, SEL, SKINS, FADE, TIME STATS)
                HStack(spacing: 4) {
                    // + ADD BUTTON (Contains YouTube Login & Feed sync)
                    WinampButton("+ ADD", skin: skin) {
                        showAddMenu = true
                    }

                    // - REM BUTTON
                    WinampButton("- REM", skin: skin) {
                        showRemMenu = true
                    }

                    // SKINS BUTTON
                    WinampButton("SKINS", skin: skin) {
                        engine.showSkinPickerSheet = true
                    }

                    // FADE BUTTON
                    WinampButton("FADE", isActive: engine.isCrossfadeEnabled, activeColor: skin.ledColor, skin: skin) {
                        engine.showCrossfadeSheet = true
                    }

                    Spacer()

                    // PLAYLIST STATS (Tracks count / Total Time)
                    HStack(spacing: 2) {
                        let totalSec = engine.playlist.reduce(0) { $0 + $1.duration }
                        let min = Int(totalSec) / 60
                        let sec = Int(totalSec) % 60
                        Text(String(format: "%d trk / %d:%02d", engine.playlist.count, min, sec))
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(skin.ledColor)
                    }
                    .padding(.horizontal, 5)
                    .padding(.vertical, 3)
                    .background(skin.lcdBackground)
                    .border(Color(white: 0.3), width: 0.5)
                }
                .padding(.horizontal, 2)
                .padding(.bottom, 2)
            }
            .frame(maxHeight: .infinity)
        }
        .frame(maxHeight: .infinity)
        // Confirmation Dialog for + ADD
        .confirmationDialog("Add Music & Stream", isPresented: $showAddMenu, titleVisibility: .visible) {
            Button("🔑 YouTube Account Sign-In / Login (Auto-Imports Feed)") {
                engine.showYouTubeLoginSheet = true
            }
            Button("🎵 Sync & Load YouTube Music Feed") {
                engine.showYouTubeLoginSheet = true
            }
            Button("🔍 Search YouTube Track or URL...") {
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
        let trimmed = searchText.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        isSearching = true
        let gen = UIImpactFeedbackGenerator(style: .medium)
        gen.impactOccurred()

        YouTubeSearchManager.shared.search(query: trimmed) { results in
            self.isSearching = false
            if !results.isEmpty {
                // Prepend or add search results
                self.engine.playlist = results
                self.engine.playTrack(at: 0)
                let notif = UINotificationFeedbackGenerator()
                notif.notificationOccurred(.success)
            }
        }
    }
}
