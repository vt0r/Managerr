import UIKit
import os
import CryptoKit

actor ImageLoader {
    static let shared = ImageLoader()

    private static let logger = Logger(subsystem: "app.managerr", category: "ImageLoader")

    private var memoryCache: [String: UIImage] = [:]
    private let session: URLSession
    private var activeTasks: [String: Task<UIImage?, Never>] = [:]
    private var cacheKeys: [String] = []
    private let maxCacheCount = 400
    private let diskCacheDir: URL
    private var activePrefetchCount = 0
    private let maxConcurrentPrefetches = 10

    init() {
        let config = URLSessionConfiguration.default
        config.urlCache = nil
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        config.httpMaximumConnectionsPerHost = 8
        session = URLSession(configuration: config)

        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        diskCacheDir = caches.appending(path: "ManagerrImages")
        try? FileManager.default.createDirectory(at: diskCacheDir, withIntermediateDirectories: true)
    }

    func image(for url: URL, headers: [String: String] = [:]) async -> UIImage? {
        let key = cacheKey(for: url)

        // L1: memory
        if let cached = memoryCache[key] { return cached }

        // L2+L3: dedup in-flight task, or start new (loadImage handles disk + network)
        if let existing = activeTasks[key] {
            return await existing.value
        }

        let task = Task<UIImage?, Never> {
            await self.loadImage(url: url, key: key, headers: headers)
        }
        activeTasks[key] = task
        let result = await task.value
        activeTasks[key] = nil
        return result
    }

    func prefetch(urls: [URL]) {
        for url in urls {
            guard activePrefetchCount < maxConcurrentPrefetches else { break }
            let key = cacheKey(for: url)
            guard memoryCache[key] == nil, activeTasks[key] == nil else { continue }
            activePrefetchCount += 1
            let task = Task<UIImage?, Never> {
                await self.loadImage(url: url, key: key, headers: [:])
            }
            activeTasks[key] = task
            Task {
                _ = await task.value
                self.onPrefetchComplete(key: key)
            }
        }
    }

    private func onPrefetchComplete(key: String) {
        activeTasks[key] = nil
        activePrefetchCount -= 1
    }

    private func cacheKey(for url: URL) -> String {
        let data = Data(url.absoluteString.utf8)
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }

    private func readFromDisk(key: String) async -> UIImage? {
        let fileURL = diskCacheDir.appending(path: key)
        guard let data = try? Data(contentsOf: fileURL),
              let raw = UIImage(data: data),
              let decoded = await raw.byPreparingForDisplay() else { return nil }
        return decoded
    }

    private func writeToDisk(key: String, data: Data) {
        let fileURL = diskCacheDir.appending(path: key)
        try? data.write(to: fileURL, options: .atomic)
    }

    private func loadImage(url: URL, key: String, headers: [String: String]) async -> UIImage? {
        // L2: disk cache
        if let diskImage = await readFromDisk(key: key) {
            storeInMemory(diskImage, forKey: key)
            return diskImage
        }

        // L3: network
        var request = URLRequest(url: url)
        for (headerKey, headerValue) in headers {
            request.setValue(headerValue, forHTTPHeaderField: headerKey)
        }

        for attempt in 0..<3 {
            if attempt > 0 {
                try? await Task.sleep(for: .milliseconds(500 * (attempt + 1)))
            }
            do {
                let (data, response) = try await session.data(for: request)
                guard let httpResponse = response as? HTTPURLResponse,
                      (200...299).contains(httpResponse.statusCode) else {
                    if let httpResponse = response as? HTTPURLResponse {
                        let contentType = httpResponse.value(forHTTPHeaderField: "Content-Type") ?? "unknown"
                        Self.logger.debug("Image load attempt \(attempt + 1) failed for \(url.absoluteString) — HTTP \(httpResponse.statusCode), Content-Type: \(contentType), \(data.count) bytes")
                        if httpResponse.statusCode == 404 {
                            break
                        }
                    }
                    continue
                }
                guard let raw = UIImage(data: data),
                      let image = await raw.byPreparingForDisplay() else { continue }
                writeToDisk(key: key, data: data)
                storeInMemory(image, forKey: key)
                return image
            } catch {
                Self.logger.debug("Image load attempt \(attempt + 1) error for \(url.absoluteString): \(error.localizedDescription)")
                continue
            }
        }
        Self.logger.debug("Image load failed after all retries: \(url.absoluteString)")
        return nil
    }

    private func storeInMemory(_ image: UIImage, forKey key: String) {
        if cacheKeys.count >= maxCacheCount {
            let removeKey = cacheKeys.removeFirst()
            memoryCache.removeValue(forKey: removeKey)
        }
        memoryCache[key] = image
        cacheKeys.append(key)
    }
}
