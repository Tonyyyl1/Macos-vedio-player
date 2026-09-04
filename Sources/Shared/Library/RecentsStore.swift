import Foundation
import Observation

/// Persists the recents list (and per-file resume position) as Codable JSON
/// in UserDefaults, newest first, capped at `limit`.
@Observable
@MainActor
final class RecentsStore {
    static let limit = 30
    private let defaults: UserDefaults
    private let key = "recents.v1"

    private(set) var items: [RecentItem] = []

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        load()
    }

    /// Insert or refresh an entry, moving it to the front and capping the list.
    func record(url: URL, bookmarkData: Data, duration: Double) {
        let id = url.standardizedFileURL.path
        var existing = items.first { $0.id == id }
        items.removeAll { $0.id == id }
        if existing != nil {
            existing!.name = url.lastPathComponent
            existing!.bookmarkData = bookmarkData
            if duration > 0 { existing!.duration = duration }
            existing!.lastPlayed = Date()
            items.insert(existing!, at: 0)
        } else {
            items.insert(RecentItem(id: id, name: url.lastPathComponent,
                                    bookmarkData: bookmarkData,
                                    lastPositionSeconds: 0, duration: duration,
                                    lastPlayed: Date()), at: 0)
        }
        if items.count > Self.limit { items.removeLast(items.count - Self.limit) }
        save()
    }

    func updatePosition(_ position: Double, duration: Double, for url: URL) {
        let id = url.standardizedFileURL.path
        guard let i = items.firstIndex(where: { $0.id == id }) else { return }
        items[i].lastPositionSeconds = position
        if duration > 0 { items[i].duration = duration }
        save()
    }

    func position(for url: URL) -> (position: Double, duration: Double)? {
        let id = url.standardizedFileURL.path
        guard let item = items.first(where: { $0.id == id }) else { return nil }
        return (item.lastPositionSeconds, item.duration)
    }

    func markFinished(_ url: URL) {
        let id = url.standardizedFileURL.path
        guard let i = items.firstIndex(where: { $0.id == id }) else { return }
        items[i].lastPositionSeconds = 0
        save()
    }

    func remove(_ item: RecentItem) {
        items.removeAll { $0.id == item.id }
        save()
    }

    func clearAll() {
        items.removeAll()
        save()
    }

    private func load() {
        guard let data = defaults.data(forKey: key),
              let decoded = try? JSONDecoder().decode([RecentItem].self, from: data) else { return }
        items = decoded
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(items) else { return }
        defaults.set(data, forKey: key)
    }
}
