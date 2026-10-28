import SwiftUI

@main
struct TubeEQApp: App {
    init() {
        // Initialize Winamp player engine & background audio session on startup
        _ = WinampPlayerEngine.shared
    }

    var body: some Scene {
        WindowGroup {
            MainContentView()
                .preferredColorScheme(.dark)
        }
    }
}
