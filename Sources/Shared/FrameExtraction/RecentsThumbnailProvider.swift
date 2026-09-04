import Foundation
import CoreGraphics
import ImageIO
import CryptoKit
import UniformTypeIdentifiers
import OSLog
import AetherEngine

/// Decodes and caches keyframe thumbnails for recents entries. Each entry is
/// an arbitrary file (not the playing item), so we resolve its security-scoped
/// bookmark, build a one-off `FrameExtractor`, decode, then shut it down. A
/// disk cache (keyed by path + size/mtime) makes thumbnails instant across
/// launches; an in-memory map short-circuits repeats within a session.
@MainActor
final class RecentsThumbnailProvider {
    static let maximumDiskEntryCount = 60
    static let maximumDiskAge: TimeInterval = 30 * 24 * 60 * 60
    private static let cacheLogger = Logger(subsystem: "de.superuser404.AetherPlayer", category: "RecentsThumbnails")
    private var memory: [String: CGImage] = [:]
    private let cacheDir: URL

    init(cacheDirectory: URL? = nil) {
        if let cacheDirectory {
            cacheDir = cacheDirectory
        } else {
            let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
                ?? FileManager.default.temporaryDirectory
            cacheDir = base.appendingPathComponent("RecentsThumbnails", isDirectory: true)
        }
        Self.createCacheDirectory(cacheDir)
        Self.pruneCache(at: cacheDir)
    }

    /// Clears both memory and disk state. Called with Clear All so stale
    /// thumbnails do not survive after the associated recent entries vanish.
    func clear() {
        memory.removeAll()
        do {
            if FileManager.default.fileExists(atPath: cacheDir.path) {
                try FileManager.default.removeItem(at: cacheDir)
            }
        } catch {
            Self.cacheLogger.error("Could not clear recent thumbnail cache: \(error.localizedDescription, privacy: .public)")
        }
        Self.createCacheDirectory(cacheDir)
    }

    /// Thumbnail for a recents entry, or nil if the file is offline or decode
    /// fails. Safe to call repeatedly (memory + disk cached).
    func thumbnail(for item: RecentItem) async -> CGImage? {
        if let cached = memory[item.id] { return cached }

        guard let scoped = ScopedResource(bookmark: item.bookmarkData) else { return nil }
        defer { scoped.stop() }

        let cacheURL = cacheFile(id: item.id, stamp: Self.validityStamp(for: scoped.url))
        if let disk = Self.loadImage(cacheURL) {
            memory[item.id] = disk
            return disk
        }

        let ext = scoped.url.pathExtension.lowercased()
        let image: CGImage?
        if audioExtensions.contains(ext) {
            image = await Self.coverArtImage(for: scoped.url)
        } else {
            let extractor = FrameExtractor(url: scoped.url)
            image = await extractor.thumbnail(
                at: recentsThumbnailTime(duration: item.duration), maxWidth: 320)
            await extractor.shutdown()
        }

        if let image {
            memory[item.id] = image
            Self.writeJPEG(image, to: cacheURL)
            Self.pruneCache(at: cacheDir)
        }
        return image
    }

    /// Decode embedded cover art for an audio file via a one-shot engine
    /// probe, run off the main actor so the recents list stays responsive.
    /// Returns nil when the file has no attached picture (the recents row
    /// then shows its generic placeholder, unchanged).
    private static func coverArtImage(for url: URL) async -> CGImage? {
        let data = await Task.detached(priority: .utility) {
            guard let probe = try? AetherEngine.probe(url: url),
                  let artwork = probe.metadata.artworkData else { return nil as Data? }
            return artwork
        }.value
        guard let data,
              let src = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        return CGImageSourceCreateImageAtIndex(src, 0, nil)
    }

    // MARK: - Cache file naming

    private func cacheFile(id: String, stamp: String) -> URL {
        let digest = SHA256.hash(data: Data("\(id)|\(stamp)".utf8))
        let hex = digest.map { String(format: "%02x", $0) }.joined()
        return cacheDir.appendingPathComponent("\(hex).jpg")
    }

    private static func validityStamp(for url: URL) -> String {
        let attrs = try? FileManager.default.attributesOfItem(atPath: url.path)
        let size = (attrs?[.size] as? NSNumber)?.uint64Value ?? 0
        let mtime = (attrs?[.modificationDate] as? Date)?.timeIntervalSince1970 ?? 0
        return "\(size)-\(Int(mtime))"
    }

    // MARK: - Image IO

    private static func loadImage(_ url: URL) -> CGImage? {
        guard let src = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        return CGImageSourceCreateImageAtIndex(src, 0, nil)
    }

    private static func writeJPEG(_ image: CGImage, to url: URL) {
        guard let dest = CGImageDestinationCreateWithURL(
            url as CFURL, UTType.jpeg.identifier as CFString, 1, nil) else {
            cacheLogger.error("Could not create recent thumbnail destination")
            return
        }
        CGImageDestinationAddImage(
            dest, image,
            [kCGImageDestinationLossyCompressionQuality: 0.8] as CFDictionary)
        if !CGImageDestinationFinalize(dest) {
            cacheLogger.error("Could not finalize recent thumbnail JPEG")
        }
    }

    static func pruneCache(at directory: URL, now: Date = Date()) {
        let fm = FileManager.default
        let keys: Set<URLResourceKey> = [.isRegularFileKey, .contentModificationDateKey]
        guard let files = try? fm.contentsOfDirectory(at: directory, includingPropertiesForKeys: Array(keys)) else { return }
        let records = files.compactMap { url -> (URL, Date)? in
            guard let values = try? url.resourceValues(forKeys: keys), values.isRegularFile == true else { return nil }
            return (url, values.contentModificationDate ?? .distantPast)
        }
        let cutoff = now.addingTimeInterval(-maximumDiskAge)
        var survivors: [(URL, Date)] = []
        for record in records {
            if record.1 < cutoff {
                removeCacheFile(record.0)
            } else {
                survivors.append(record)
            }
        }
        for record in survivors.sorted(by: { $0.1 < $1.1 }).dropLast(maximumDiskEntryCount) {
            removeCacheFile(record.0)
        }
    }

    private static func createCacheDirectory(_ directory: URL) {
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        } catch {
            cacheLogger.error("Could not create recent thumbnail cache directory: \(error.localizedDescription, privacy: .public)")
        }
    }

    private static func removeCacheFile(_ url: URL) {
        do {
            try FileManager.default.removeItem(at: url)
        } catch {
            cacheLogger.error("Could not remove expired recent thumbnail: \(error.localizedDescription, privacy: .public)")
        }
    }
}
