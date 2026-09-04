import XCTest
import MediaPlayer
import AetherEngine
@testable import AetherPlayer

final class NowPlayingInfoTests: XCTestCase {
    func testMapsCoreFields() {
        let meta = MediaMetadata(title: "Song", artist: "Artist", album: "Album", artworkData: nil)
        let info = nowPlayingInfo(
            metadata: meta, fallbackTitle: "ignored",
            duration: 200, elapsed: 30, rate: 1.0)
        XCTAssertEqual(info[MPMediaItemPropertyTitle] as? String, "Song")
        XCTAssertEqual(info[MPMediaItemPropertyArtist] as? String, "Artist")
        XCTAssertEqual(info[MPMediaItemPropertyAlbumTitle] as? String, "Album")
        XCTAssertEqual(info[MPMediaItemPropertyPlaybackDuration] as? Double, 200)
        XCTAssertEqual(info[MPNowPlayingInfoPropertyElapsedPlaybackTime] as? Double, 30)
        XCTAssertEqual(info[MPNowPlayingInfoPropertyPlaybackRate] as? Double, 1.0)
    }

    func testFallbackTitleWhenNoMetadataTitle() {
        let info = nowPlayingInfo(
            metadata: nil, fallbackTitle: "My File",
            duration: 0, elapsed: 0, rate: 0)
        XCTAssertEqual(info[MPMediaItemPropertyTitle] as? String, "My File")
        XCTAssertNil(info[MPMediaItemPropertyArtist])
    }

    func testPausedRateIsZero() {
        let info = nowPlayingInfo(
            metadata: nil, fallbackTitle: "x", duration: 10, elapsed: 5, rate: 0)
        XCTAssertEqual(info[MPNowPlayingInfoPropertyPlaybackRate] as? Double, 0)
    }
}
