import XCTest
@testable import AetherPlayer

final class SubtitleLayoutTests: XCTestCase {
    func testReferenceHeightYieldsBaseTimesUserScale() {
        XCTAssertEqual(subtitleFontSize(surfaceHeight: 1080, userScale: 1.0), 24, accuracy: 0.001)
        XCTAssertEqual(subtitleFontSize(surfaceHeight: 1080, userScale: 2.0), 48, accuracy: 0.001)
    }

    func testScalesWithSurfaceHeight() {
        // 4K-ish surface doubles the auto scale.
        XCTAssertEqual(subtitleFontSize(surfaceHeight: 2160, userScale: 1.0), 48, accuracy: 0.001)
    }

    func testClampsTinyAndHugeSurfaces() {
        // Floor at 0.5x auto (very small windows stay legible).
        XCTAssertEqual(subtitleFontSize(surfaceHeight: 360, userScale: 1.0), 12, accuracy: 0.001)
        // Ceiling at 3.0x auto.
        XCTAssertEqual(subtitleFontSize(surfaceHeight: 6000, userScale: 1.0), 72, accuracy: 0.001)
    }

    func testZeroHeightFallsBackToBase() {
        XCTAssertEqual(subtitleFontSize(surfaceHeight: 0, userScale: 1.5), 36, accuracy: 0.001)
    }

    func testSubtitleSizeScalesAndLabels() {
        XCTAssertEqual(SubtitleSize.small.scale, 0.75, accuracy: 0.001)
        XCTAssertEqual(SubtitleSize.normal.scale, 1.0, accuracy: 0.001)
        XCTAssertEqual(SubtitleSize.large.scale, 1.5, accuracy: 0.001)
        XCTAssertEqual(SubtitleSize.extraLarge.scale, 2.0, accuracy: 0.001)
        XCTAssertEqual(SubtitleSize.allCases.count, 4)
        XCTAssertEqual(SubtitleSize.extraLarge.label, "Extra Large")
    }
}
