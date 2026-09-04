import XCTest
import AetherEngine
@testable import AetherPlayer

final class NowPlayingTextTests: XCTestCase {
    private func meta(_ t: String?, _ a: String?, _ al: String?) -> MediaMetadata {
        MediaMetadata(title: t, artist: a, album: al, artworkData: nil)
    }
    private let url = URL(fileURLWithPath: "/music/My Song.flac")

    func testTitlePrefersMetadataTitle() {
        XCTAssertEqual(nowPlayingTitle(metadata: meta("Song", "A", "B"), url: url), "Song")
    }
    func testTitleFallsBackToFilenameWithoutExtension() {
        XCTAssertEqual(nowPlayingTitle(metadata: meta(nil, "A", nil), url: url), "My Song")
        XCTAssertEqual(nowPlayingTitle(metadata: nil, url: url), "My Song")
        XCTAssertEqual(nowPlayingTitle(metadata: nil, url: nil), "AetherPlayer")
    }
    func testSubtitleJoinsArtistAndAlbum() {
        XCTAssertEqual(nowPlayingSubtitle(metadata: meta("S", "Artist", "Album")), "Artist \u{00B7} Album")
        XCTAssertEqual(nowPlayingSubtitle(metadata: meta("S", "Artist", nil)), "Artist")
        XCTAssertEqual(nowPlayingSubtitle(metadata: meta("S", nil, "Album")), "Album")
        XCTAssertNil(nowPlayingSubtitle(metadata: meta("S", nil, nil)))
        XCTAssertNil(nowPlayingSubtitle(metadata: nil))
    }
    func testWindowTitleForAudioUsesTitleDashArtist() {
        XCTAssertEqual(windowTitle(metadata: meta("Song", "Artist", nil), url: url, isAudio: true), "Song - Artist")
        XCTAssertEqual(windowTitle(metadata: meta("Song", nil, nil), url: url, isAudio: true), "Song")
    }
    func testWindowTitleForVideoUsesFilename() {
        let v = URL(fileURLWithPath: "/v/Movie.mkv")
        XCTAssertEqual(windowTitle(metadata: nil, url: v, isAudio: false), "Movie.mkv")
        XCTAssertEqual(windowTitle(metadata: nil, url: nil, isAudio: false), "AetherPlayer")
    }
}
