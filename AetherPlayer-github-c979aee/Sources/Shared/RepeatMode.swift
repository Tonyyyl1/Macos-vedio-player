import Foundation

/// Repeat behavior for audio playback, cycled by the transport's repeat
/// button. Audio only: the video path always plays through.
enum RepeatMode: String, CaseIterable {
    /// Play through; stop at the end of the folder / single track.
    case off
    /// Repeat the whole folder playlist, wrapping at the end.
    case all
    /// Repeat the current track.
    case one

    /// Next mode in the off -> all -> one -> off cycle.
    var cycled: RepeatMode {
        switch self {
        case .off: return .all
        case .all: return .one
        case .one: return .off
        }
    }
}
