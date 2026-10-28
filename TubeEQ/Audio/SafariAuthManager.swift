import Foundation
import UIKit
import AuthenticationServices

public class SafariAuthManager: NSObject, ASWebAuthenticationPresentationContextProviding {
    public static let shared = SafariAuthManager()

    private override init() {
        super.init()
    }

    /// Launches Safari-linked Google Authentication Session sharing Safari cookies, passwords and accounts
    public func startSafariLinkedSignIn(completion: @escaping (Bool) -> Void) {
        guard let authURL = URL(string: "https://accounts.google.com/ServiceLogin?service=youtube&continue=https://m.youtube.com") else {
            completion(false)
            return
        }

        let session = ASWebAuthenticationSession(
            url: authURL,
            callbackURLScheme: "winamp"
        ) { callbackURL, error in
            if error == nil {
                completion(true)
            } else {
                completion(false)
            }
        }

        session.presentationContextProvider = self
        session.prefersEphemeralWebBrowserSession = false // Reuses Safari logged-in sessions!
        session.start()
    }

    public func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first(where: { $0.isKeyWindow }) {
            return window
        }
        return ASPresentationAnchor()
    }
}
