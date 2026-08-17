import XCTest
@testable import AetherPlayer

final class PlaylistTests: XCTestCase {
    private func u(_ s: String) -> URL { URL(fileURLWithPath: "/m/\(s)") }

    func testFilterAndNaturalSort() {
        let input = [u("ep10.mkv"), u("readme.txt"), u("ep2.mp4"), u("ep1.MKV"), u("cover.jpg")]
        let result = playableFiles(in: input)
        XCTAssertEqual(result.map { $0.lastPathComponent }, ["ep1.MKV", "ep2.mp4", "ep10.mkv"])
    }
    func testNextAndPrev() {
        var p = Playlist(items: [u("a.mkv"), u("b.mkv"), u("c.mkv")], currentIndex: 0)
        XCTAssertEqual(p.next()?.lastPathComponent, "b.mkv")
        XCTAssertEqual(p.currentIndex, 1)
        XCTAssertEqual(p.previous()?.lastPathComponent, "a.mkv")
        XCTAssertEqual(p.currentIndex, 0)
    }
    func testNextAtEndReturnsNil() {
        var p = Playlist(items: [u("a.mkv"), u("b.mkv")], currentIndex: 1)
        XCTAssertNil(p.next())
        XCTAssertEqual(p.currentIndex, 1)
    }
    func testIndexOf() {
        let p = Playlist(items: [u("a.mkv"), u("b.mkv")], currentIndex: 0)
        XCTAssertEqual(p.index(of: u("b.mkv")), 1)
        XCTAssertNil(p.index(of: u("z.mkv")))
    }

    func testPlayableFilesIncludesAudioFormats() {
        let urls = [
            URL(fileURLWithPath: "/m/track.flac"),
            URL(fileURLWithPath: "/m/song.mp3"),
            URL(fileURLWithPath: "/m/clip.mp4"),
            URL(fileURLWithPath: "/m/notes.txt"),
            URL(fileURLWithPath: "/m/audio.opus"),
        ]
        let names = playableFiles(in: urls).map { $0.lastPathComponent }
        XCTAssertEqual(names, ["audio.opus", "clip.mp4", "song.mp3", "track.flac"])
    }

    func testAudioExtensionsAreLowercasedSet() {
        XCTAssertTrue(audioExtensions.contains("flac"))
        XCTAssertTrue(audioExtensions.contains("mp3"))
        XCTAssertFalse(audioExtensions.contains("FLAC"))
    }

    func testShuffleKeepsCurrentFirstAndPermutesTheRest() {
        let files = (1...8).map { u("t\($0).mp3") }
        var p = Playlist(items: files, currentIndex: 3) // current = t4
        let current = p.current
        p.setShuffled(true)
        XCTAssertTrue(p.isShuffled)
        XCTAssertEqual(p.currentIndex, 0)
        XCTAssertEqual(p.current, current)                 // current stays the cursor
        XCTAssertEqual(Set(p.items), Set(files))           // same set, no loss/dupe
        XCTAssertEqual(p.items.count, files.count)
    }

    func testUnshuffleRestoresSortedOrderKeepingCursorOnCurrent() {
        let files = (1...8).map { u("t\($0).mp3") }
        var p = Playlist(items: files, currentIndex: 0)
        p.setShuffled(true)
        let playing = p.current
        p.setShuffled(false)
        XCTAssertFalse(p.isShuffled)
        XCTAssertEqual(p.items, files)                     // original order back
        XCTAssertEqual(p.current, playing)                 // cursor still on same item
    }

    func testInitWithShuffleProducesShuffledList() {
        let files = (1...6).map { u("t\($0).mp3") }
        let p = Playlist(items: files, currentIndex: 0, isShuffled: true)
        XCTAssertTrue(p.isShuffled)
        XCTAssertEqual(Set(p.items), Set(files))
        XCTAssertEqual(p.current, files[0])                // current preserved at front
    }
}
