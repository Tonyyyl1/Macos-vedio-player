import Foundation
import AetherEngine

/// Whether the current session should present as audio-only.
///
/// The engine's `.audio` backend is authoritative once published. During
/// the brief load window before the backend is known (`.none`), fall back
/// to the file extension so the UI does not flash the black video surface
/// for an audio file. Any committed video backend (`native`/`software`/
/// `aether`) means video, regardless of extension.
func isAudioPlayback(backend: PlaybackBackend, url: URL?) -> Bool {
    switch backend {
    case .audio:
        return true
    case .native, .software, .aether:
        return false
    case .none:
        return isAudioExtension(url)
    }
}

/// Whether the URL's extension is a known audio container. Used as the
/// load-window fallback above and to force the engine's audio path at
/// open time (cover-art audio otherwise routes to the video pipeline).
func isAudioExtension(_ url: URL?) -> Bool {
    guard let ext = url?.pathExtension.lowercased() else { return false }
    return audioExtensions.contains(ext)
}
