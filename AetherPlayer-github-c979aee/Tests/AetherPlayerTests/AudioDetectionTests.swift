import XCTest
import AetherEngine
@testable import AetherPlayer

final class AudioDetectionTests: XCTestCase {
    func testBackendAudioIsAuthoritative() {
        let url = URL(fileURLWithPath: "/m/clip.mp4") // video extension
        XCTAssertTrue(isAudioPlayback(backend: .audio, url: url))
    }

    func testVideoBackendIsNotAudioEvenForAudioExtension() {
        let url = URL(fileURLWithPath: "/m/song.mp3")
        XCTAssertFalse(isAudioPlayback(backend: .native, url: url))
        XCTAssertFalse(isAudioPlayback(backend: .software, url: url))
    }

    func testDuringLoadFallsBackToExtension() {
        XCTAssertTrue(isAudioPlayback(backend: .none, url: URL(fileURLWithPath: "/m/song.flac")))
        XCTAssertFalse(isAudioPlayback(backend: .none, url: URL(fileURLWithPath: "/m/clip.mkv")))
    }

    func testNoURLIsNotAudio() {
        XCTAssertFalse(isAudioPlayback(backend: .none, url: nil))
    }

    func testIsAudioExtension() {
        XCTAssertTrue(isAudioExtension(URL(fileURLWithPath: "/m/x.FLAC")))  // case-insensitive
        XCTAssertFalse(isAudioExtension(URL(fileURLWithPath: "/m/x.mkv")))
        XCTAssertFalse(isAudioExtension(nil))
    }
}
