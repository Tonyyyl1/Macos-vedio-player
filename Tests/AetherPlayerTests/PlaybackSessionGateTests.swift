import XCTest
@testable import AetherPlayer

final class PlaybackSessionGateTests: XCTestCase {
    func testTerminalEventDuringLoadIsIgnoredUntilPlaybackStarts() {
        var gate = PlaybackSessionGate()
        let generation = gate.beginLoad()

        XCTAssertFalse(gate.consumeNaturalEnd(hasMedia: true))
        XCTAssertTrue(gate.acceptLoadCompletion(generation))
        XCTAssertFalse(gate.consumeNaturalEnd(hasMedia: true))

        gate.observeActivePlayback()
        XCTAssertTrue(gate.consumeNaturalEnd(hasMedia: true))
    }

    func testExplicitStopInvalidatesInflightLoadAndSuppressesTerminalEvent() {
        var gate = PlaybackSessionGate()
        let generation = gate.beginLoad()

        gate.requestStop()

        XCTAssertFalse(gate.acceptLoadCompletion(generation))
        XCTAssertFalse(gate.consumeNaturalEnd(hasMedia: true))
    }

    func testOnlyNewestLoadCompletionCanChangeSession() {
        var gate = PlaybackSessionGate()
        let firstGeneration = gate.beginLoad()
        let secondGeneration = gate.beginLoad()

        XCTAssertFalse(gate.acceptLoadCompletion(firstGeneration))
        XCTAssertTrue(gate.acceptLoadCompletion(secondGeneration))
    }

    func testNaturalEndIsConsumedOnce() {
        var gate = PlaybackSessionGate()
        let generation = gate.beginLoad()
        XCTAssertTrue(gate.acceptLoadCompletion(generation))
        gate.observeActivePlayback()

        XCTAssertTrue(gate.consumeNaturalEnd(hasMedia: true))
        XCTAssertFalse(gate.consumeNaturalEnd(hasMedia: true))
    }
}
