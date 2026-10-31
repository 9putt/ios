import Foundation
import WebKit
import Security

public class KeychainCookieManager {
    public static let shared = KeychainCookieManager()
    private let keychainService = "com.winamp.player.pro.cookies"
    private let keychainAccount = "youtube_session_cookies"

    private init() {}

    public func hasSavedSession() -> Bool {
        return loadFromKeychain() != nil
    }

    public func getCookieHeaderString() -> String? {
        guard let data = loadFromKeychain(),
              let cookieDicts = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            return nil
        }
        var parts: [String] = []
        for d in cookieDicts {
            if let name = d["name"] as? String, let val = d["value"] as? String {
                parts.append("\(name)=\(val)")
            }
        }
        return parts.isEmpty ? nil : parts.joined(separator: "; ")
    }

    /// Restores saved Google/YouTube session cookies from iOS Keychain into WKWebsiteDataStore
    /// This ensures login persists across app updates and app reinstalls!
    public func restoreCookies(to cookieStore: WKHTTPCookieStore, completion: (() -> Void)? = nil) {
        guard let data = loadFromKeychain() else {
            completion?()
            return
        }

        do {
            if let cookieDicts = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
                let group = DispatchGroup()
                for dict in cookieDicts {
                    var properties: [HTTPCookiePropertyKey: Any] = [:]
                    if let name = dict["name"] as? String { properties[.name] = name }
                    if let value = dict["value"] as? String { properties[.value] = value }
                    if let domain = dict["domain"] as? String { properties[.domain] = domain }
                    if let path = dict["path"] as? String { properties[.path] = path }
                    if let expires = dict["expires"] as? Double { properties[.expires] = Date(timeIntervalSince1970: expires) }
                    if let secure = dict["secure"] as? Bool { properties[.secure] = secure }

                    if let cookie = HTTPCookie(properties: properties) {
                        group.enter()
                        cookieStore.setCookie(cookie) {
                            group.leave()
                        }
                    }
                }
                group.notify(queue: .main) {
                    print("[Winamp] Restored \(cookieDicts.count) session cookies from Keychain")
                    completion?()
                }
                return
            }
        } catch {
            print("[Winamp] Failed to deserialize cookies from Keychain: \(error)")
        }
        completion?()
    }

    /// Saves all current Google/YouTube cookies from WKWebsiteDataStore into iOS Keychain
    public func persistCookies(from cookieStore: WKHTTPCookieStore, completion: (() -> Void)? = nil) {
        cookieStore.getAllCookies { [weak self] cookies in
            guard let self = self else { return }
            var cookieDicts: [[String: Any]] = []

            for c in cookies {
                // Focus on Google & YouTube auth cookies
                let domain = c.domain.lowercased()
                if domain.contains("youtube.com") || domain.contains("google.com") {
                    var d: [String: Any] = [
                        "name": c.name,
                        "value": c.value,
                        "domain": c.domain,
                        "path": c.path,
                        "secure": c.isSecure
                    ]
                    if let exp = c.expiresDate {
                        d["expires"] = exp.timeIntervalSince1970
                    }
                    cookieDicts.append(d)
                }
            }

            guard !cookieDicts.isEmpty else {
                completion?()
                return
            }

            if let data = try? JSONSerialization.data(withJSONObject: cookieDicts) {
                self.saveToKeychain(data: data)
                print("[Winamp] Persisted \(cookieDicts.count) session cookies to Keychain")
            }
            completion?()
        }
    }

    // MARK: - Low-Level Keychain Access (Persists even when app is deleted and reinstalled)
    private func saveToKeychain(data: Data) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount
        ]

        SecItemDelete(query as CFDictionary)

        var newQuery = query
        newQuery[kSecValueData as String] = data
        newQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock

        let status = SecItemAdd(newQuery as CFDictionary, nil)
        if status != errSecSuccess {
            print("[Winamp] Keychain save status: \(status)")
        }
    }

    private func loadFromKeychain() -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecSuccess, let data = item as? Data {
            return data
        }
        return nil
    }
}
