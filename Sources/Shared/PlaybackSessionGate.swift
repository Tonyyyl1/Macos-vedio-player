import Foundation

/// Keeps terminal playback events tied to the current load session.
///
/// A player engine can publish `.idle` while replacing a source or after an
/// explicit stop. Those states must not be interpreted as a file reaching its
/// natural end, otherwise a playlist can advance unexpectedly. The view model
/// owns one gate and asks it whether a terminal event may trigger automatic
/// completion handling.
struct PlaybackSessionGate: Equatable, Sendable {
    private(set) var activeGeneration = 0
    private var isLoading = false
    private var stopRequested = false
    private var hasObservedActivePlayback = false
    private var terminalEventConsumed = false

    /// Starts a replacement session and invalidates every older completion.
    mutating func beginLoad() -> Int {
        activeGeneration &+= 1
        isLoading = true
        stopRequested = false
        hasObservedActivePlayback = false
        terminalEventConsumed = false
        return activeGeneration
    }

    /// Accepts the current load's completion. A stale load must not mutate the
    /// model that has already moved on to a newer generation.
    mutating func acceptLoadCompletion(_ generation: Int) -> Bool {
        guard generation == activeGeneration, !stopRequested else { return false }
        isLoading = false
        return true
    }

    /// Records a current load failure without allowing its later terminal
    /// engine notification to be treated as natural playback completion.
    mutating func rejectLoadCompletion(_ generation: Int) -> Bool {
        guard generation == activeGeneration else { return false }
        isLoading = false
        hasObservedActivePlayback = false
        terminalEventConsumed = true
        return true
    }

    /// Invalidates an in-flight load and suppresses terminal events caused by
    /// the user's explicit stop action.
    mutating func requestStop() {
        activeGeneration &+= 1
        isLoading = false
        stopRequested = true
        hasObservedActivePlayback = false
        terminalEventConsumed = true
    }

    /// The engine has entered a state in which the current item was genuinely
    /// active. A preceding `.idle` from teardown or replacement remains
    /// ignored until this happens.
    mutating func observeActivePlayback() {
        guard !isLoading, !stopRequested else { return }
        hasObservedActivePlayback = true
    }

    /// Returns true exactly once for a natural terminal event of the current
    /// session. Callers supply `hasMedia` so a cleared session cannot finish.
    mutating func consumeNaturalEnd(hasMedia: Bool) -> Bool {
        guard hasMedia,
              !isLoading,
              !stopRequested,
              hasObservedActivePlayback,
              !terminalEventConsumed else {
            return false
        }
        terminalEventConsumed = true
        return true
    }
}
