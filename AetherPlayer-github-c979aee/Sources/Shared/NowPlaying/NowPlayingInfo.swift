import Foundation
import MediaPlayer
import AetherEngine

/// Build the `MPNowPlayingInfoCenter.nowPlayingInfo` dictionary from the
/// session's metadata and clock. Artwork is attached separately by the
/// controller (it needs an NSImage and is mutated asynchronously), so
/// this stays a pure, testable mapping of the scalar fields.
func nowPlayingInfo(
    metadata: MediaMetadata?,
    fallbackTitle: String,
    duration: Double,
    elapsed: Double,
    rate: Float
) -> [String: Any] {
    var info: [String: Any] = [
        MPMediaItemPropertyTitle: metadata?.title ?? fallbackTitle,
        MPMediaItemPropertyPlaybackDuration: duration,
        MPNowPlayingInfoPropertyElapsedPlaybackTime: elapsed,
        MPNowPlayingInfoPropertyPlaybackRate: Double(rate),
    ]
    if let artist = metadata?.artist { info[MPMediaItemPropertyArtist] = artist }
    if let album = metadata?.album { info[MPMediaItemPropertyAlbumTitle] = album }
    return info
}
