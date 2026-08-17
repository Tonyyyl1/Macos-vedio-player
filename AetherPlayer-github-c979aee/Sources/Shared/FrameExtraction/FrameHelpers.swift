import Foundation

/// Representative keyframe time for a recents thumbnail: about 10% into the
/// runtime, clamped to the valid range. Returns 0 when duration is unknown.
func recentsThumbnailTime(duration: Double) -> Double {
    guard duration.isFinite, duration > 0 else { return 0 }
    return min(max(duration * 0.1, 0), duration)
}

/// Default filename for a saved frame: "<base> @ <timecode>.png", with the
/// timecode colons swapped for dots so the name is filesystem-safe. Falls
/// back to "Frame" when the source name is empty.
func snapshotFilename(movieName: String, at seconds: Double) -> String {
    let base = (movieName as NSString).deletingPathExtension
    let safeBase = base.isEmpty ? "Frame" : base
    let stamp = formatTimecode(seconds).replacingOccurrences(of: ":", with: ".")
    return "\(safeBase) @ \(stamp).png"
}

/// Leading-edge x offset for the scrub-preview overlay so it centers on the
/// playhead but stays within the track width. Returns 0 for a zero width.
func scrubThumbX(fraction: Double, width: Double, thumbWidth: Double) -> Double {
    guard width > 0 else { return 0 }
    let f = min(max(fraction, 0), 1)
    let leading = f * width - thumbWidth / 2
    return min(max(leading, 0), max(0, width - thumbWidth))
}

/// Maps a hover/drag x position on the scrub track to a 0...1 fraction,
/// clamped to the track. Returns 0 for a zero width.
func fraction(forX x: Double, width: Double) -> Double {
    guard width > 0 else { return 0 }
    return min(max(x / width, 0), 1)
}
