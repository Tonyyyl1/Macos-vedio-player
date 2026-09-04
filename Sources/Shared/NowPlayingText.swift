import Foundation
import AetherEngine

/// Primary line: the tag title, else the filename without extension,
/// else the app name.
func nowPlayingTitle(metadata: MediaMetadata?, url: URL?) -> String {
    if let t = metadata?.title { return t }
    if let url { return url.deletingPathExtension().lastPathComponent }
    return "AetherPlayer"
}

/// Secondary line: "Artist \u{00B7} Album", or whichever part exists, or nil.
func nowPlayingSubtitle(metadata: MediaMetadata?) -> String? {
    let parts = [metadata?.artist, metadata?.album].compactMap { $0 }
    return parts.isEmpty ? nil : parts.joined(separator: " \u{00B7} ")
}

/// macOS window title. Audio: "Title - Artist" (hyphen, not an em-dash,
/// per the no-em-dash convention), degrading to just the title. Video:
/// the filename. App name when nothing is loaded.
func windowTitle(metadata: MediaMetadata?, url: URL?, isAudio: Bool) -> String {
    guard let url else { return "AetherPlayer" }
    if isAudio {
        let title = nowPlayingTitle(metadata: metadata, url: url)
        if let artist = metadata?.artist { return "\(title) - \(artist)" }
        return title
    }
    return url.lastPathComponent
}
