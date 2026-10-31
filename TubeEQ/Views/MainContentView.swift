import SwiftUI

public struct MainContentView: View {
    @ObservedObject var engine = WinampPlayerEngine.shared

    public var body: some View {
        let skin = engine.currentSkin

        ZStack(alignment: .top) {
            // Fullscreen dynamic background strictly constrained to screen bounds (never overflows)
            if let dynImg = engine.activeDynamicWallpaperImage {
                GeometryReader { geo in
                    Image(uiImage: dynImg)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: geo.size.width, height: geo.size.height)
                        .clipped()
                }
                .ignoresSafeArea()
            } else if let dynamicSkin = engine.activeDynamicSkin, let uiImg = DynamicSkinManager.shared.imageFor(skin: dynamicSkin) {
                GeometryReader { geo in
                    Image(uiImage: uiImg)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: geo.size.width, height: geo.size.height)
                        .clipped()
                }
                .ignoresSafeArea()
            } else if let bgName = skin.backgroundImageName {
                GeometryReader { geo in
                    Image(bgName)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: geo.size.width, height: geo.size.height)
                        .clipped()
                }
                .ignoresSafeArea()
            } else {
                skin.windowBackground.ignoresSafeArea()
            }

            VStack(spacing: 4) {
                
                // 1. MAIN PLAYER WINDOW (Top Module)
                WinampMainWindow()
                
                // 2. EQUALIZER WINDOW (Middle Module)
                if engine.showEqualizerWindow {
                    WinampEqualizerWindow()
                        .transition(.opacity)
                }

                // 3. PLAYLIST WINDOW (Stretches down to fill remaining height)
                if engine.showPlaylistWindow {
                    WinampPlaylistWindow()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .transition(.opacity)
                }
            }
            .padding(.horizontal, 4)
            .padding(.top, 0)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
        // Modal Sheets
        .sheet(isPresented: $engine.showYouTubeLoginSheet) {
            YouTubeLoginSheet()
        }
        .sheet(isPresented: $engine.showSkinPickerSheet) {
            SkinPickerSheet()
        }
        .sheet(isPresented: $engine.showGenrePickerSheet) {
            GenrePickerSheet()
        }
        .sheet(isPresented: $engine.showCrossfadeSheet) {
            CrossfadeSheet()
        }
        .sheet(isPresented: $engine.showUpdateSheet) {
            AppUpdateSheet()
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
