import Foundation

enum PlaybackCompletionAction: Equatable, Sendable {
    case stop
    case playNext
    case restartCurrent
    case restartPlaylist
}

/// Decides the one automatic action allowed after a media item finishes.
/// User-initiated next/previous controls bypass this policy; the auto-play
/// switch controls only actions caused by natural end-of-playback.
func playbackCompletionAction(
    isAudio: Bool,
    autoPlayNextEnabled: Bool,
    repeatMode: RepeatMode,
    hasNext: Bool,
    hasPlaylist: Bool
) -> PlaybackCompletionAction {
    guard autoPlayNextEnabled else { return .stop }

    guard isAudio else {
        return hasNext ? .playNext : .stop
    }

    switch repeatMode {
    case .one:
        return .restartCurrent
    case .all:
        if hasNext { return .playNext }
        return hasPlaylist ? .restartPlaylist : .restartCurrent
    case .off:
        return hasNext ? .playNext : .stop
    }
}
