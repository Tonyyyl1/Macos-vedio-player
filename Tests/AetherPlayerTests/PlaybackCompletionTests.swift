import XCTest
@testable import AetherPlayer

final class PlaybackCompletionTests: XCTestCase {
    func testVideoPlaylistAdvancesOnlyWhenAutoPlayIsEnabled() {
        XCTAssertEqual(
            playbackCompletionAction(
                isAudio: false, autoPlayNextEnabled: true, repeatMode: .off,
                hasNext: true, hasPlaylist: true
            ),
            .playNext
        )
        XCTAssertEqual(
            playbackCompletionAction(
                isAudio: false, autoPlayNextEnabled: false, repeatMode: .off,
                hasNext: true, hasPlaylist: true
            ),
            .stop
        )
    }

    func testSingleVideoStopsAtNaturalEnd() {
        XCTAssertEqual(
            playbackCompletionAction(
                isAudio: false, autoPlayNextEnabled: true, repeatMode: .off,
                hasNext: false, hasPlaylist: false
            ),
            .stop
        )
    }

    func testAudioRepeatActionsRespectAutoPlayToggle() {
        XCTAssertEqual(
            playbackCompletionAction(
                isAudio: true, autoPlayNextEnabled: true, repeatMode: .one,
                hasNext: false, hasPlaylist: true
            ),
            .restartCurrent
        )
        XCTAssertEqual(
            playbackCompletionAction(
                isAudio: true, autoPlayNextEnabled: true, repeatMode: .all,
                hasNext: false, hasPlaylist: true
            ),
            .restartPlaylist
        )
        XCTAssertEqual(
            playbackCompletionAction(
                isAudio: true, autoPlayNextEnabled: false, repeatMode: .all,
                hasNext: true, hasPlaylist: true
            ),
            .stop
        )
    }
}
