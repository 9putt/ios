import SwiftUI

public struct MainContentView: View {
    @ObservedObject var engine = WinampPlayerEngine.shared

    public var body: some View {
        let skin = engine.currentSkin

        ZStack(alignment: .top) {
            // Fullscreen dynamic background
            skin.windowBackground.ignoresSafeArea()

            VStack(spacing: 4) {
                
                // 1. MAIN PLAYER WINDOW (Top Module)
                WinampMainWindow()
                
                // 2. EQUALIZER WINDOW (Middle Module)
                if engine.showEqualizerWindow {
                    WinampEqualizerWindow()
                        .transition(.opacity)
                }

                // 3. PLAYLIST WINDOW (Stretches all the way to the bottom edge of the screen!)
                if engine.showPlaylistWindow {
                    WinampPlaylistWindow()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .transition(.opacity)
                }
            }
            .padding(.horizontal, 4)
            .padding(.top, 0)
            .padding(.bottom, 0)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .ignoresSafeArea(edges: .bottom)
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
