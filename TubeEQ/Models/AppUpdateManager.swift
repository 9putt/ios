import SwiftUI
import Combine

public class AppUpdateManager: ObservableObject {
    public static let shared = AppUpdateManager()

    @Published public var isChecking: Bool = false
    @Published public var hasUpdate: Bool = false
    @Published public var latestVersionTag: String = ""
    @Published public var currentVersion: String = "3.24.0"
    @Published public var releaseTitle: String = ""
    @Published public var releaseNotes: String = ""
    @Published public var ipaDownloadURL: String = ""
    @Published public var isDownloading: Bool = false
    @Published public var downloadProgress: Double = 0.0
    @Published public var downloadedFileURL: URL? = nil
    @Published public var showShareSheet: Bool = false
    @Published public var showUpdateSheet: Bool = false
    @Published public var statusMessage: String = ""

    private let repo = "9putt/ios"
    private var downloadTask: URLSessionDownloadTask?

    private init() {
        if let ver = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
            self.currentVersion = ver
        }
        // Auto check in background on startup
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
            self?.checkForUpdates(silent: true)
        }
    }

    public func checkForUpdates(silent: Bool = false) {
        guard !isChecking else { return }
        isChecking = true
        statusMessage = "กำลังตรวจสอบเวอร์ชันล่าสุดจากเซิร์ฟเวอร์..."

        guard let url = URL(string: "https://api.github.com/repos/\(repo)/releases/latest?t=\(Int(Date().timeIntervalSince1970))") else {
            isChecking = false
            return
        }

        var request = URLRequest(url: url)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("Winamp-Update-Checker/1.0", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 10.0

        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }
            DispatchQueue.main.async {
                self.isChecking = false
            }

            guard let data = data, error == nil,
                  let release = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                DispatchQueue.main.async {
                    if !silent {
                        self.statusMessage = "ไม่สามารถเชื่อมต่อเซิร์ฟเวอร์อัปเดตได้"
                    }
                }
                return
            }

            let tagName = release["tag_name"] as? String ?? ""
            let name = release["name"] as? String ?? tagName
            let body = release["body"] as? String ?? ""
            let assets = release["assets"] as? [[String: Any]] ?? []

            var ipaUrl = ""
            for a in assets {
                if let aName = a["name"] as? String, aName.hasSuffix(".ipa"),
                   let dl = a["browser_download_url"] as? String {
                    ipaUrl = dl
                    break
                }
            }

            let cleanTag = tagName.replacingOccurrences(of: "v", with: "")
            let isNewer = self.isVersion(cleanTag, newerThan: self.currentVersion)

            DispatchQueue.main.async {
                self.latestVersionTag = tagName
                self.releaseTitle = name
                self.releaseNotes = body
                self.ipaDownloadURL = ipaUrl
                self.hasUpdate = isNewer

                if isNewer {
                    self.statusMessage = "พบอัปเดตใหม่: \(tagName)"
                    if !silent {
                        self.showUpdateSheet = true
                    }
                } else {
                    self.statusMessage = "คุณใช้เวอร์ชันล่าสุดแล้ว (\(self.currentVersion))"
                }
            }
        }.resume()
    }

    private func isVersion(_ v1: String, newerThan v2: String) -> Bool {
        let parts1 = v1.split(separator: ".").compactMap { Int($0) }
        let parts2 = v2.split(separator: ".").compactMap { Int($0) }
        let maxCount = max(parts1.count, parts2.count)
        for i in 0..<maxCount {
            let num1 = i < parts1.count ? parts1[i] : 0
            let num2 = i < parts2.count ? parts2[i] : 0
            if num1 > num2 { return true }
            if num1 < num2 { return false }
        }
        return false
    }

    /// One-click direct in-place update using TrollStore URL schemes
    public func installViaTrollStore() {
        guard !ipaDownloadURL.isEmpty else { return }
        let rawUrl = ipaDownloadURL
        guard let encoded = rawUrl.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else { return }

        let trollStoreSchemes = [
            "trollstore://install?url=\(encoded)",
            "apple-magnifier://install?url=\(encoded)"
        ]

        for s in trollStoreSchemes {
            if let u = URL(string: s), UIApplication.shared.canOpenURL(u) {
                UIApplication.shared.open(u)
                return
            }
        }

        // Fallback to in-app direct download
        startInAppDownload()
    }

    public func startInAppDownload() {
        guard !ipaDownloadURL.isEmpty, let url = URL(string: ipaDownloadURL) else { return }
        guard !isDownloading else { return }
        isDownloading = true
        downloadProgress = 0.0
        statusMessage = "กำลังดาวน์โหลดไฟล์อัปเดต Winamp.ipa..."

        let config = URLSessionConfiguration.default
        let session = URLSession(configuration: config, delegate: DownloadDelegate(manager: self), delegateQueue: nil)
        downloadTask = session.downloadTask(with: url)
        downloadTask?.resume()
    }

    private class DownloadDelegate: NSObject, URLSessionDownloadDelegate {
        weak var manager: AppUpdateManager?
        init(manager: AppUpdateManager) { self.manager = manager }

        func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
            if totalBytesExpectedToWrite > 0 {
                let prog = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
                DispatchQueue.main.async {
                    self.manager?.downloadProgress = prog
                }
            }
        }

        func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
            let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let dest = docs.appendingPathComponent("Winamp-Update.ipa")
            try? FileManager.default.removeItem(at: dest)
            try? FileManager.default.moveItem(at: location, to: dest)

            DispatchQueue.main.async {
                self.manager?.isDownloading = false
                self.manager?.downloadProgress = 1.0
                self.manager?.downloadedFileURL = dest
                self.manager?.statusMessage = "ดาวน์โหลดเสร็จสมบูรณ์! พร้อมติดตั้ง"
                self.manager?.showShareSheet = true
            }
        }

        func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
            if let error = error {
                DispatchQueue.main.async {
                    self.manager?.isDownloading = false
                    self.manager?.statusMessage = "การดาวน์โหลดล้มเหลว: \(error.localizedDescription)"
                }
            }
        }
    }
}
