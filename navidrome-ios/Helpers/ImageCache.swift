import SwiftUI

@MainActor
final class ImageCache {
    static let shared = ImageCache()

    private let memoryCache = NSCache<NSString, UIImage>()
    private let fileManager = FileManager.default
    private let cacheDirectory: URL

    private init() {
        let caches = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        cacheDirectory = caches.appendingPathComponent("CoverArt", isDirectory: true)
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        memoryCache.countLimit = 200
    }

    func image(for id: String, size: Int) async -> UIImage? {
        let key = "\(id)_\(size)" as NSString

        // 1. Memory cache
        if let cached = memoryCache.object(forKey: key) {
            return cached
        }

        // 2. Disk cache
        let fileURL = cacheDirectory.appendingPathComponent(String(key))
        if let data = try? Data(contentsOf: fileURL), let image = UIImage(data: data) {
            memoryCache.setObject(image, forKey: key)
            return image
        }

        // 3. Network fetch
        guard let url = NavidromeClient.shared.coverArtURL(id: id, size: size) else { return nil }
        guard let (data, _) = try? await URLSession.shared.data(from: url) else { return nil }
        guard let image = UIImage(data: data) else { return nil }

        // Store in both caches
        memoryCache.setObject(image, forKey: key)
        try? data.write(to: fileURL)

        return image
    }
}
