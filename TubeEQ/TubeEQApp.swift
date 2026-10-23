import SwiftUI

@main
struct TubeEQApp: App {
    init() {
        // Initialize background audio engine on startup
        _ = AudioEngineManager.shared
    }

    var body: some Scene {
        WindowGroup {
            MainContentView()
        }
    }
}
