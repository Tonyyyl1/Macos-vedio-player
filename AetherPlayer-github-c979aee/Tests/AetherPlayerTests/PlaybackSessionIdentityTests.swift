import Testing
@testable import AetherPlayer

struct PlaybackSessionIdentityTests {
    @Test func beginningANewSessionRejectsThePreviousIdentity() {
        var epoch = PlaybackSessionEpoch()
        let first = epoch.begin()
        let second = epoch.begin()

        #expect(first != second)
        #expect(first.session != second.session)
        #expect(first.generation.value < second.generation.value)
        #expect(!epoch.accepts(first))
        #expect(epoch.accepts(second))
    }

    @Test func invalidationRejectsQueuedWork() {
        var epoch = PlaybackSessionEpoch()
        let identity = epoch.begin()

        epoch.invalidate()

        #expect(epoch.current == nil)
        #expect(!epoch.accepts(identity))
        #expect(epoch.phase == .empty)
    }

    @Test func staleEventsCannotChangeTheReplacementSessionPhase() {
        var epoch = PlaybackSessionEpoch()
        let oldIdentity = epoch.begin()
        let currentIdentity = epoch.begin()

        let appliedStaleEnd = epoch.apply(.ended, for: oldIdentity)
        #expect(!appliedStaleEnd)
        #expect(epoch.phase == .opening)

        let appliedLoadCompletion = epoch.apply(.loadCompleted, for: currentIdentity)
        #expect(appliedLoadCompletion)
        #expect(epoch.phase == .ready)
        let appliedPlaying = epoch.apply(.playing, for: currentIdentity)
        #expect(appliedPlaying)
        #expect(epoch.phase == .playing)
    }

    @Test func terminalAndExplicitStopPhasesAreDistinct() {
        var epoch = PlaybackSessionEpoch()
        let identity = epoch.begin()

        let appliedEnd = epoch.apply(.ended, for: identity)
        #expect(appliedEnd)
        #expect(epoch.phase == .ended)
        let appliedStopping = epoch.apply(.stopping, for: identity)
        #expect(appliedStopping)
        #expect(epoch.phase == .stopping)
    }

    @Test func sessionControllerConsumesOnlyOneNaturalEndForTheCurrentLoad() {
        let controller = PlaybackSessionController()
        let first = controller.begin()
        let markedFirst = controller.markLoaded(first)
        let consumedFirstEnd = controller.consumeNaturalEnd(for: first)
        let repeatedFirstEnd = controller.consumeNaturalEnd(for: first)

        let replacement = controller.begin()
        let staleFirstEnd = controller.consumeNaturalEnd(for: first)
        let markedReplacement = controller.markLoaded(replacement)
        let consumedReplacementEnd = controller.consumeNaturalEnd(for: replacement)

        #expect(markedFirst)
        #expect(consumedFirstEnd)
        #expect(!repeatedFirstEnd)
        #expect(!staleFirstEnd)
        #expect(markedReplacement)
        #expect(consumedReplacementEnd)
    }
}
