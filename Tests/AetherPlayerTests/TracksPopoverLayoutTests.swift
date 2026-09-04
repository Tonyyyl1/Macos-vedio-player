import XCTest
@testable import AetherPlayer

final class TracksPopoverLayoutTests: XCTestCase {
    func testLeavesInsetBelowScreenHeight() {
        XCTAssertEqual(tracksPopoverMaxHeight(screenHeight: 1080), 920, accuracy: 0.001)
    }

    func testNeverBelowMinimumOnSmallScreens() {
        XCTAssertEqual(tracksPopoverMaxHeight(screenHeight: 300), 200, accuracy: 0.001)
    }

    func testGrowsOnLargeDisplays() {
        XCTAssertEqual(tracksPopoverMaxHeight(screenHeight: 2160), 2000, accuracy: 0.001)
    }
}
