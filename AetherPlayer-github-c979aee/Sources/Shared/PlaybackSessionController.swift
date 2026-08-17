import Foundation

/// Owns the host-side lifetime of one playback session.
///
/// The player view model mirrors the controller's identity and phase for
/// observation by the UI, while this type owns the mutable rules that decide
/// whether a delayed event still belongs to the active source.
final class PlaybackSessionController {
    private var epoch = PlaybackSessionEpoch()
    private var loadedIdentity: PlaybackIdentity?
    private var handledEndIdentity: PlaybackIdentity?

    var identity: PlaybackIdentity? { epoch.current }
    var phase: PlayerPlaybackPhase { epoch.phase }
    var hasCurrentLoadedMedia: Bool { loadedIdentity == epoch.current }

    func begin() -> PlaybackIdentity {
        let identity = epoch.begin()
        handledEndIdentity = nil
        return identity
    }

    func invalidate() {
        epoch.invalidate()
        loadedIdentity = nil
        handledEndIdentity = nil
    }

    func accepts(_ identity: PlaybackIdentity) -> Bool {
        epoch.accepts(identity)
    }

    @discardableResult
    func transition(_ signal: PlaybackSessionSignal, for identity: PlaybackIdentity) -> Bool {
        epoch.apply(signal, for: identity)
    }

    /// Records the source whose load completed. A replacement in progress
    /// intentionally leaves the previous source out of this current identity.
    @discardableResult
    func markLoaded(_ identity: PlaybackIdentity) -> Bool {
        guard accepts(identity) else { return false }
        loadedIdentity = identity
        return true
    }

    func clearLoadedMedia(for identity: PlaybackIdentity) {
        guard accepts(identity) else { return }
        loadedIdentity = nil
    }

    /// Returns true exactly once for the currently loaded source's natural
    /// end. Repeated engine `.ended` publications must not advance twice.
    func consumeNaturalEnd(for identity: PlaybackIdentity) -> Bool {
        guard accepts(identity), loadedIdentity == identity,
              handledEndIdentity != identity else { return false }
        handledEndIdentity = identity
        return true
    }
}
