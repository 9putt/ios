import SwiftUI

public struct MainContentView: View {
    @ObservedObject var engine = WinampPlayerEngine.shared

    public var body: some View {
        let skin = engine.currentSkin

        ZStack {
            // Fullscreen dynamic background based on current skin (stretches to every screen corner)
            skin.windowBackground.ignoresSafeArea()

            VStack(spacing: 5) {
                
                // 1. MAIN PLAYER WINDOW (Top Module - flush against top safe area)
                WinampMainWindow()
                
                // 2. EQUALIZER WINDOW (Middle Module)
                if engine.showEqualizerWindow {
                    WinampEqualizerWindow()
                        .transition(.opacity)
                }

                // 3. PLAYLIST WINDOW (Bottom Module - Stretches all the way to bottom of screen!)
                if engine.showPlaylistWindow {
                    WinampPlaylistWindow()
                        .frame(maxHeight: .infinity)
                        .transition(.opacity)
                }
            }
            .padding(.horizontal, 6)
            .padding(.bottom, 4)
        }
        // Modal Sheets
        .sheet(isPresented: $engine.showYouTubeLoginSheet) {
            YouTubeLoginSheet()
        }
        .sheet(isPresented: $engine.showSkinPickerSheet) {
            SkinPickerSheet()
        }
        .sheet(isPresented: $engine.showCrossfadeSheet) {
            CrossfadeSheet()
        }
        .sheet(isPresented: $engine.showSearchSheet) {
            YouTubeSearchSheet()
        }
        .sheet(isPresented: $engine.showAddFilePicker) {
            DocumentPicker(forFolder: false) { urls in
                engine.addLocalFiles(urls: urls)
            }
        }
        .sheet(isPresented: $engine.showAddFolderPicker) {
            DocumentPicker(forFolder: true) { urls in
                if let folderUrl = urls.first {
                    engine.addFolder(url: folderUrl)
                }
            }
        }
    }
}
