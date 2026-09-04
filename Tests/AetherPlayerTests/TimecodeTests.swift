import XCTest
@testable import AetherPlayer

final class TimecodeTests: XCTestCase {
    func testUnderOneHour() {
        XCTAssertEqual(formatTimecode(0), "0:00")
        XCTAssertEqual(formatTimecode(5), "0:05")
        XCTAssertEqual(formatTimecode(65), "1:05")
        XCTAssertEqual(formatTimecode(599), "9:59")
    }
    func testOverOneHour() {
        XCTAssertEqual(formatTimecode(3600), "1:00:00")
        XCTAssertEqual(formatTimecode(3661), "1:01:01")
    }
    func testNegativeAndNaNClampToZero() {
        XCTAssertEqual(formatTimecode(-5), "0:00")
        XCTAssertEqual(formatTimecode(.nan), "0:00")
        XCTAssertEqual(formatTimecode(.infinity), "0:00")
    }
    func testRateLabel() {
        XCTAssertEqual(rateLabel(1.0), "1x")
        XCTAssertEqual(rateLabel(2.0), "2x")
        XCTAssertEqual(rateLabel(0.5), "0.5x")
        XCTAssertEqual(rateLabel(0.75), "0.75x")
        XCTAssertEqual(rateLabel(1.25), "1.25x")
        XCTAssertEqual(rateLabel(1.5), "1.5x")
    }
}
