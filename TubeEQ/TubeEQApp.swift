import SwiftUI
import WebKit

@main
struct TubeEQApp: App {
    init() {
        // Initialize Winamp player engine & background audio session on startup
        _ = WinampPlayerEngine.shared
        _ = AppUpdateManager.shared

        // Restore Google/YouTube authentication session from iOS Keychain into WebKit
        KeychainCookieManager.shared.restoreCookies(to: WKWebsiteDataStore.default().httpCookieStore)
    }

    var body: some Scene {
        WindowGroup {
            MainContentView()
                .preferredColorScheme(.dark)
        }
    }
}
