import XCTest
@testable import AetherPlayer

final class AutoHideTests: XCTestCase {
    func testHidesAfterInterval() {
        XCTAssertTrue(shouldHideControls(now: 100, lastActivity: 96, interval: 3))
    }
    func testStaysVisibleWithinInterval() {
        XCTAssertFalse(shouldHideControls(now: 100, lastActivity: 98, interval: 3))
    }
    func testBoundaryStaysVisible() {
        XCTAssertFalse(shouldHideControls(now: 100, lastActivity: 97, interval: 3))
    }
}
