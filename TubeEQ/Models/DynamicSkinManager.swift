import SwiftUI
import Combine

public struct DynamicSkinItem: Identifiable, Codable, Equatable {
    public var id: String
    public var name: String
    public var description: String
    public var imageUrl: String
    public var titleBarColors: [String]
    public var titleBarTextColorHex: String
    public var ledColorHex: String
    public var marqueeColorHex: String
    public var sliderColorHex: String
    public var isLiquidGlass: Bool
    public var localImageFilename: String?

    public init(
        id: String,
        name: String,
        description: String,
        imageUrl: String,
        titleBarColors: [String],
        titleBarTextColorHex: String,
        ledColorHex: String,
        marqueeColorHex: String,
        sliderColorHex: String,
        isLiquidGlass: Bool = true,
        localImageFilename: String? = nil
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.imageUrl = imageUrl
        self.titleBarColors = titleBarColors
        self.titleBarTextColorHex = titleBarTextColorHex
        self.ledColorHex = ledColorHex
        self.marqueeColorHex = marqueeColorHex
        self.sliderColorHex = sliderColorHex
        self.isLiquidGlass = isLiquidGlass
        self.localImageFilename = localImageFilename
    }
}

public struct DynamicSkinCatalog: Codable {
    public var version: Int
    public var skins: [DynamicSkinItem]
}

public class DynamicSkinManager: ObservableObject {
    public static let shared = DynamicSkinManager()

    @Published public var dynamicSkins: [DynamicSkinItem] = []
    @Published public var isCheckingForUpdates: Bool = false
    @Published public var lastUpdateMessage: String? = nil

    private let catalogURL = URL(string: "https://raw.githubusercontent.com/9putt/ios/main/skins_catalog.json")!
    
    public var skinsDir: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir = docs.appendingPathComponent("DynamicSkins", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    private var catalogFile: URL {
        return skinsDir.appendingPathComponent("dynamic_skins.json")
    }

    private init() {
        loadCachedSkins()
        // Auto-check for updates on startup in background
        DispatchQueue.global(qos: .background).asyncAfter(deadline: .now() + 2.0) { [weak self] in
            self?.checkForUpdates()
        }
    }

    public func loadCachedSkins() {
        if FileManager.default.fileExists(atPath: catalogFile.path) {
            do {
                let data = try Data(contentsOf: catalogFile)
                let loaded = try JSONDecoder().decode([DynamicSkinItem].self, from: data)
                DispatchQueue.main.async {
                    self.dynamicSkins = loaded
                }
                return
            } catch {
                print("[DynamicSkinManager] Load cache error: \(error)")
            }
        }

        // Bundled fallback catalog
        if let bundleUrl = Bundle.main.url(forResource: "skins_catalog", withExtension: "json") {
            do {
                let data = try Data(contentsOf: bundleUrl)
                let catalog = try JSONDecoder().decode(DynamicSkinCatalog.self, from: data)
                DispatchQueue.main.async {
                    self.dynamicSkins = catalog.skins
                }
            } catch {
                print("[DynamicSkinManager] Load bundled catalog error: \(error)")
            }
        }
    }

    public func checkForUpdates(force: Bool = false, autoApplyLatest: Bool = false, completion: ((Bool, String) -> Void)? = nil) {
        guard !isCheckingForUpdates else { return }
        DispatchQueue.main.async {
            self.isCheckingForUpdates = true
        }

        let cacheBusterUrl = URL(string: "\(catalogURL.absoluteString)?t=\(Int(Date().timeIntervalSince1970))") ?? catalogURL
        var request = URLRequest(url: cacheBusterUrl, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 12)
        request.setValue("Antigravity-Winamp/1.0", forHTTPHeaderField: "User-Agent")

        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }

            DispatchQueue.main.async {
                self.isCheckingForUpdates = false
            }

            guard let data = data, error == nil else {
                let msg = "ไม่สามารถเชื่อมต่อคลังสกินออนไลน์ได้ในขณะนี้"
                DispatchQueue.main.async {
                    self.lastUpdateMessage = msg
                    completion?(false, msg)
                }
                return
            }

            do {
                let catalog = try JSONDecoder().decode(DynamicSkinCatalog.self, from: data)
                self.processDownloadedCatalog(catalog.skins, autoApplyLatest: autoApplyLatest, completion: completion)
            } catch {
                let msg = "ข้อผิดพลาดในการอ่านข้อมูลสกิน: \(error.localizedDescription)"
                DispatchQueue.main.async {
                    self.lastUpdateMessage = msg
                    completion?(false, msg)
                }
            }
        }.resume()
    }

    private func processDownloadedCatalog(_ remoteSkins: [DynamicSkinItem], autoApplyLatest: Bool = false, completion: ((Bool, String) -> Void)?) {
        var updatedSkins: [DynamicSkinItem] = []
        let dispatchGroup = DispatchGroup()

        for var skin in remoteSkins {
            let localFileName = "\(skin.id).jpg"
            let localFilePath = self.skinsDir.appendingPathComponent(localFileName)
            skin.localImageFilename = localFileName

            // If image is not downloaded yet, download it
            if !FileManager.default.fileExists(atPath: localFilePath.path), let imgUrl = URL(string: skin.imageUrl) {
                dispatchGroup.enter()
                URLSession.shared.dataTask(with: imgUrl) { imgData, _, _ in
                    if let imgData = imgData {
                        try? imgData.write(to: localFilePath, options: .atomic)
                    }
                    dispatchGroup.leave()
                }.resume()
            }
            updatedSkins.append(skin)
        }

        dispatchGroup.notify(queue: .main) { [weak self] in
            guard let self = self else { return }
            self.dynamicSkins = updatedSkins
            if let enc = try? JSONEncoder().encode(updatedSkins) {
                try? enc.write(to: self.catalogFile, options: .atomic)
            }
            let successMsg = "อัปเดตสกินใหม่เรียบร้อยแล้ว (\(updatedSkins.count) สกิน)"
            self.lastUpdateMessage = successMsg

            if autoApplyLatest {
                let candidate = updatedSkins.first(where: { $0.id != WinampPlayerEngine.shared.activeDynamicSkin?.id }) ?? updatedSkins.first
                if let target = candidate {
                    WinampPlayerEngine.shared.applyDynamicSkin(target)
                }
            } else if let activeId = WinampPlayerEngine.shared.activeDynamicSkin?.id,
                      let currentActive = updatedSkins.first(where: { $0.id == activeId }) {
                WinampPlayerEngine.shared.applyDynamicSkin(currentActive)
            }

            self.objectWillChange.send()
            completion?(true, successMsg)
            let notif = UINotificationFeedbackGenerator()
            notif.notificationOccurred(.success)
        }
    }

    public func fetchImageDirectly(for skin: DynamicSkinItem, completion: @escaping (UIImage?) -> Void) {
        if let existing = imageFor(skin: skin) {
            completion(existing)
            return
        }
        guard let url = URL(string: skin.imageUrl) else {
            completion(nil)
            return
        }
        let fn = skin.localImageFilename ?? "\(skin.id).jpg"
        let localPath = skinsDir.appendingPathComponent(fn)

        URLSession.shared.dataTask(with: url) { [weak self] data, _, error in
            guard let data = data, let img = UIImage(data: data) else {
                completion(nil)
                return
            }
            try? data.write(to: localPath, options: .atomic)
            DispatchQueue.main.async {
                self?.objectWillChange.send()
                completion(img)
            }
        }.resume()
    }

    public func imageFor(skin: DynamicSkinItem) -> UIImage? {
        let fn = skin.localImageFilename ?? "\(skin.id).jpg"
        let path = skinsDir.appendingPathComponent(fn).path
        if FileManager.default.fileExists(atPath: path), let img = UIImage(contentsOfFile: path) {
            return img
        }
        // Check bundled cloud_skins directory or main bundle
        let baseName = (fn as NSString).deletingPathExtension
        let ext = (fn as NSString).pathExtension.isEmpty ? "jpg" : (fn as NSString).pathExtension
        if let bundlePath = Bundle.main.path(forResource: baseName, ofType: ext), let img = UIImage(contentsOfFile: bundlePath) {
            return img
        }
        if let subPath = Bundle.main.path(forResource: baseName, ofType: ext, inDirectory: "cloud_skins"), let img = UIImage(contentsOfFile: subPath) {
            return img
        }
        // Auto trigger download if missing
        ensureImageDownloaded(for: skin)
        return nil
    }

    public func ensureImageDownloaded(for skin: DynamicSkinItem) {
        let fn = skin.localImageFilename ?? "\(skin.id).jpg"
        let localPath = skinsDir.appendingPathComponent(fn)
        if !FileManager.default.fileExists(atPath: localPath.path), let url = URL(string: skin.imageUrl) {
            URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
                if let data = data {
                    try? data.write(to: localPath, options: .atomic)
                    DispatchQueue.main.async {
                        self?.objectWillChange.send()
                    }
                }
            }.resume()
        }
    }
}
