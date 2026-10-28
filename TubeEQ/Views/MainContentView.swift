import SwiftUI

public struct MainContentView: View {
    @ObservedObject var engine = WinampPlayerEngine.shared

    public var body: some View {
        let skin = engine.currentSkin

        ZStack {
            // Fullscreen dynamic background based on current skin
            skin.windowBackground.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 8) {
                    
                    // 1. MAIN PLAYER WINDOW (Top Module)
                    WinampMainWindow()
                    
                    // 2. EQUALIZER WINDOW (Middle Module)
                    if engine.showEqualizerWindow {
                        WinampEqualizerWindow()
                            .transition(.asymmetric(
                                insertion: .opacity.combined(with: .scale(scale: 0.95)),
                                removal: .opacity.combined(with: .scale(scale: 0.95))
                            ))
                    }

                    // 3. PLAYLIST WINDOW (Bottom Module)
                    if engine.showPlaylistWindow {
                        WinampPlaylistWindow()
                            .transition(.asymmetric(
                                insertion: .opacity.combined(with: .scale(scale: 0.95)),
                                removal: .opacity.combined(with: .scale(scale: 0.95))
                            ))
                    }

                    Spacer(minLength: 20)
                }
                .padding(.horizontal, 8)
                .padding(.top, 40) // Clears Dynamic Island / Notch
                .padding(.bottom, 20)
            }
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
