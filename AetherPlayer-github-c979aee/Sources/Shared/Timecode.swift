import Foundation

/// Formats a duration in seconds as "M:SS" under an hour, "H:MM:SS" at or
/// above an hour. Non-finite or negative inputs clamp to "0:00".
func formatTimecode(_ seconds: Double) -> String {
    guard seconds.isFinite, seconds > 0 else { return "0:00" }
    let total = Int(seconds.rounded(.down))
    let h = total / 3600
    let m = (total % 3600) / 60
    let s = total % 60
    if h > 0 {
        return String(format: "%d:%02d:%02d", h, m, s)
    }
    return String(format: "%d:%02d", m, s)
}

/// Formats a playback rate as a compact multiplier: integer rates drop the decimal
/// ("1x", "2x"), others use the shortest representation ("0.5x", "1.25x").
func rateLabel(_ r: Float) -> String {
    if r == r.rounded() { return "\(Int(r))x" }
    return "\(String(format: "%g", r))x"
}
