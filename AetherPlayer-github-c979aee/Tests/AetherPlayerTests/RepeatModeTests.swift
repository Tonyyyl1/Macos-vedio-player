import XCTest
@testable import AetherPlayer

final class RepeatModeTests: XCTestCase {
    func testCycleOrder() {
        XCTAssertEqual(RepeatMode.off.cycled, .all)
        XCTAssertEqual(RepeatMode.all.cycled, .one)
        XCTAssertEqual(RepeatMode.one.cycled, .off)
    }

    func testRawValueRoundTrips() {
        for mode in RepeatMode.allCases {
            XCTAssertEqual(RepeatMode(rawValue: mode.rawValue), mode)
        }
    }
}
