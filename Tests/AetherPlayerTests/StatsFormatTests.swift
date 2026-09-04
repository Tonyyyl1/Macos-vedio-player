import XCTest
import AetherEngine
@testable import AetherPlayer

final class StatsFormatTests: XCTestCase {
    func testResolution() {
        XCTAssertEqual(formatResolution(width: 1920, height: 1080), "1920 \u{00D7} 1080")
        XCTAssertEqual(formatResolution(width: 0, height: 0), "\u{2012}")
    }

    func testVideoFormatLabels() {
        XCTAssertEqual(videoFormatLabel(.sdr), "SDR")
        XCTAssertEqual(videoFormatLabel(.hdr10), "HDR10")
        XCTAssertEqual(videoFormatLabel(.hdr10Plus), "HDR10+")
        XCTAssertEqual(videoFormatLabel(.dolbyVision), "Dolby Vision")
        XCTAssertEqual(videoFormatLabel(.hlg), "HLG")
    }

    func testOptionalNumericFormatters() {
        XCTAssertEqual(formatMbps(12.34), "12.3 Mbps")
        XCTAssertEqual(formatMbps(nil), "\u{2012}")
        XCTAssertEqual(formatFps(47.96), "48.0 fps")
        XCTAssertEqual(formatFps(nil), "\u{2012}")
        XCTAssertEqual(formatDroppedFrames(3), "3")
        XCTAssertEqual(formatDroppedFrames(nil), "\u{2012}")
        XCTAssertEqual(formatSeconds(2.5), "2.5 s")
        XCTAssertEqual(formatSeconds(nil), "\u{2012}")
    }

    func testMemoryAndBackend() {
        XCTAssertEqual(formatMemoryMB(340), "340 MB")
        XCTAssertEqual(formatBackend(.native), "Native (AVPlayer)")
        XCTAssertEqual(formatBackend(.software), "Software")
        XCTAssertEqual(formatBackend(.audio), "Audio")
        XCTAssertEqual(formatBackend(.aether), "Aether")
        XCTAssertEqual(formatBackend(.none), "\u{2012}")
    }

    func testFrameRate() {
        XCTAssertEqual(formatFrameRate(23.976), "23.976 fps")
        XCTAssertEqual(formatFrameRate(24.0), "24 fps")
        XCTAssertEqual(formatFrameRate(59.94), "59.940 fps")
        XCTAssertEqual(formatFrameRate(0), "\u{2012}")
        XCTAssertEqual(formatFrameRate(nil), "\u{2012}")
    }

    func testChannels() {
        XCTAssertEqual(formatChannels(2, isAtmos: false), "Stereo")
        XCTAssertEqual(formatChannels(6, isAtmos: false), "5.1")
        XCTAssertEqual(formatChannels(6, isAtmos: true), "5.1 \u{00B7} Atmos")
        XCTAssertEqual(formatChannels(8, isAtmos: false), "7.1")
        XCTAssertEqual(formatChannels(7, isAtmos: false), "7ch")
        XCTAssertEqual(formatChannels(0, isAtmos: false), "\u{2012}")
    }

    func testBitrateBps() {
        XCTAssertEqual(formatBitrateBps(384_000), "384 kbps")
        XCTAssertEqual(formatBitrateBps(1_500_000), "1.5 Mbps")
        XCTAssertEqual(formatBitrateBps(0), "\u{2012}")
    }

    func testDynamicRangeLabel() {
        XCTAssertEqual(dynamicRangeLabel(source: .dolbyVision, effective: .sdr, dvProfile: 5),
                       "Dolby Vision P5 \u{2192} SDR")
        XCTAssertEqual(dynamicRangeLabel(source: .hdr10, effective: .hdr10, dvProfile: nil), "HDR10")
        XCTAssertEqual(dynamicRangeLabel(source: .sdr, effective: .sdr, dvProfile: nil), "SDR")
    }
}
