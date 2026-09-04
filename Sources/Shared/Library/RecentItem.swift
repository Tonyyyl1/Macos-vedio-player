import Foundation

/// One entry in the recents list. `id` is the file's standardized path so
/// repeated opens of the same file dedupe. `bookmarkData` reopens it later.
struct RecentItem: Codable, Identifiable, Equatable {
    let id: String          // standardized file path
    var name: String
    var bookmarkData: Data
    var lastPositionSeconds: Double
    var duration: Double
    var lastPlayed: Date

    /// 0...1 watched fraction for the progress bar (0 when unknown).
    var progress: Double {
        guard duration > 0 else { return 0 }
        return min(1, max(0, lastPositionSeconds / duration))
    }
}
