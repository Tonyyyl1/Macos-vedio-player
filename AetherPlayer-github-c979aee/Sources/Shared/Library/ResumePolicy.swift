import Foundation

private let minimumResumeSeconds: Double = 10
private let finishedFraction: Double = 0.95

/// True when a saved position is close enough to the end to treat the file
/// as watched (no resume, clear the saved point). Uses a fraction of the
/// duration rather than an absolute tail in seconds, so it works for short
/// clips and long films alike -- an absolute tail larger than a short file's
/// duration would otherwise mark every position as finished.
func isEffectivelyFinished(position: Double, duration: Double) -> Bool {
    guard duration.isFinite, duration > 0 else { return false }
    return position / duration >= finishedFraction
}

/// The position to resume at, or nil if we should start from the beginning
/// (too early in, no duration, or effectively finished).
func resumeTarget(lastPosition: Double, duration: Double) -> Double? {
    guard duration.isFinite, duration > 0 else { return nil }
    guard lastPosition >= minimumResumeSeconds else { return nil }
    if isEffectivelyFinished(position: lastPosition, duration: duration) { return nil }
    return lastPosition
}
