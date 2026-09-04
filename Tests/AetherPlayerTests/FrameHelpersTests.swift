import XCTest
@testable import AetherPlayer

@MainActor
final class FrameHelpersTests: XCTestCase {
    private func temporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("AetherPlayerFrameHelpers-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: url) }
        return url
    }

    @discardableResult
    private func cacheFile(_ name: String, date: Date, in directory: URL) throws -> URL {
        let url = directory.appendingPathComponent(name)
        try Data(name.utf8).write(to: url)
        try FileManager.default.setAttributes([.modificationDate: date], ofItemAtPath: url.path)
        return url
    }
    func testRecentsThumbnailTime() {
        XCTAssertEqual(recentsThumbnailTime(duration: 0), 0)
        XCTAssertEqual(recentsThumbnailTime(duration: -10), 0)
        XCTAssertEqual(recentsThumbnailTime(duration: .nan), 0)
        XCTAssertEqual(recentsThumbnailTime(duration: 100), 10, accuracy: 0.0001)
    }

    func testSnapshotFilename() {
        XCTAssertEqual(snapshotFilename(movieName: "MyMovie.mkv", at: 754), "MyMovie @ 12.34.png")
        XCTAssertEqual(snapshotFilename(movieName: "Clip.mp4", at: 3661), "Clip @ 1.01.01.png")
        XCTAssertEqual(snapshotFilename(movieName: "", at: 0), "Frame @ 0.00.png")
    }

    func testScrubThumbX() {
        XCTAssertEqual(scrubThumbX(fraction: 0, width: 200, thumbWidth: 160), 0)
        XCTAssertEqual(scrubThumbX(fraction: 0.5, width: 200, thumbWidth: 160), 20)
        XCTAssertEqual(scrubThumbX(fraction: 1, width: 200, thumbWidth: 160), 40)
        XCTAssertEqual(scrubThumbX(fraction: 0.5, width: 0, thumbWidth: 160), 0)
    }

    func testFractionForX() {
        XCTAssertEqual(fraction(forX: 0, width: 200), 0)
        XCTAssertEqual(fraction(forX: 100, width: 200), 0.5, accuracy: 0.0001)
        XCTAssertEqual(fraction(forX: 200, width: 200), 1)
        XCTAssertEqual(fraction(forX: 250, width: 200), 1)
        XCTAssertEqual(fraction(forX: -10, width: 200), 0)
        XCTAssertEqual(fraction(forX: 50, width: 0), 0)
    }

    func testThumbnailCachePrunesExpiredEntries() throws {
        let directory = try temporaryDirectory()
        let now = Date(timeIntervalSinceReferenceDate: 1_000_000)
        let expired = try cacheFile("expired.jpg", date: now.addingTimeInterval(-RecentsThumbnailProvider.maximumDiskAge - 1), in: directory)
        let current = try cacheFile("current.jpg", date: now, in: directory)

        RecentsThumbnailProvider.pruneCache(at: directory, now: now)

        XCTAssertFalse(FileManager.default.fileExists(atPath: expired.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: current.path))
    }

    func testThumbnailCacheKeepsNewestEntriesWithinLimit() throws {
        let directory = try temporaryDirectory()
        let now = Date(timeIntervalSinceReferenceDate: 1_000_000)
        for index in 0..<(RecentsThumbnailProvider.maximumDiskEntryCount + 2) {
            try cacheFile("\(index).jpg", date: now.addingTimeInterval(TimeInterval(-100 + index)), in: directory)
        }

        RecentsThumbnailProvider.pruneCache(at: directory, now: now)

        let names = try FileManager.default.contentsOfDirectory(atPath: directory.path)
        XCTAssertEqual(names.count, RecentsThumbnailProvider.maximumDiskEntryCount)
        XCTAssertFalse(names.contains("0.jpg"))
        XCTAssertFalse(names.contains("1.jpg"))
        XCTAssertTrue(names.contains("61.jpg"))
    }

    func testClearingThumbnailProviderRemovesDiskEntries() throws {
        let directory = try temporaryDirectory()
        try cacheFile("thumbnail.jpg", date: Date(), in: directory)
        let provider = RecentsThumbnailProvider(cacheDirectory: directory)

        provider.clear()

        XCTAssertTrue(FileManager.default.fileExists(atPath: directory.path))
        XCTAssertTrue(try FileManager.default.contentsOfDirectory(atPath: directory.path).isEmpty)
    }
}
