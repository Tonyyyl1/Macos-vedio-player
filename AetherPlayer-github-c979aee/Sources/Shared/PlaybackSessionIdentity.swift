import Foundation

/// Stable identity for one host-visible media session.
///
/// A new value is created for every open so delayed work from a previous
/// source can never be applied to the source that replaced it.
struct PlaybackSessionID: Hashable, Sendable {
    let value: UUID

    init(value: UUID = UUID()) {
        self.value = value
    }
}

/// Monotonic host-side epoch. This supplements AetherEngine's internal load
/// generation at the application boundary, where UI tasks and side services
/// also need to reject stale completions.
struct PlaybackGeneration: Hashable, Sendable {
    let value: UInt64
}

/// The token every asynchronous Player operation must capture before it
/// awaits. It remains valid only while it is the epoch's current identity.
struct PlaybackIdentity: Hashable, Sendable {
    let session: PlaybackSessionID
    let generation: PlaybackGeneration
}

/// Application-level lifecycle exposed to the rest of the player. It is
/// intentionally distinct from AetherEngine's implementation-level state so
/// the UI can later depend on a stable macOS playback contract.
enum PlayerPlaybackPhase: Equatable, Sendable {
    case empty
    case opening
    case ready
    case playing
    case paused
    case seeking
    case buffering
    case ended
    case stopping
    case failed(String)
}

/// A normalized event from the playback backend or host command path.
/// Every event belongs to the identity captured by its asynchronous work.
enum PlaybackSessionSignal: Equatable, Sendable {
    case opening
    case loadCompleted
    case playing
    case paused
    case seeking
    case buffering
    case ended
    case stopping
    case stopped
    case failed(String)
}

/// Main-actor-owned identity gate and lifecycle reducer for host-visible
/// playback work.
///
/// `AetherEngine` protects its own asynchronous pipeline with a generation.
/// This gate covers the application's async work around it (load completion,
/// seek tasks, frame extraction and subtitle activation).
struct PlaybackSessionEpoch: Sendable {
    private(set) var current: PlaybackIdentity?
    private(set) var phase: PlayerPlaybackPhase = .empty
    private var nextGeneration: UInt64 = 0

    mutating func begin() -> PlaybackIdentity {
        nextGeneration &+= 1
        let identity = PlaybackIdentity(
            session: PlaybackSessionID(),
            generation: PlaybackGeneration(value: nextGeneration)
        )
        current = identity
        phase = .opening
        return identity
    }

    mutating func invalidate() {
        nextGeneration &+= 1
        current = nil
        phase = .empty
    }

    func accepts(_ identity: PlaybackIdentity) -> Bool {
        current == identity
    }

    /// Applies only events belonging to the currently active session. Returns
    /// false for delayed events from a source that has been replaced or stopped.
    @discardableResult
    mutating func apply(_ signal: PlaybackSessionSignal, for identity: PlaybackIdentity) -> Bool {
        guard accepts(identity) else { return false }
        switch signal {
        case .opening:
            phase = .opening
        case .loadCompleted:
            phase = .ready
        case .playing:
            phase = .playing
        case .paused:
            phase = .paused
        case .seeking:
            phase = .seeking
        case .buffering:
            phase = .buffering
        case .ended:
            phase = .ended
        case .stopping:
            phase = .stopping
        case .stopped:
            phase = .empty
        case .failed(let message):
            phase = .failed(message)
        }
        return true
    }
}
