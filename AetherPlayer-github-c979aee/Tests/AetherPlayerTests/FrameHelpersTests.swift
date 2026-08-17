import XCTest
@testable import AetherPlayer

final class FrameHelpersTests: XCTestCase {
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
}
