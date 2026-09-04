import XCTest
@testable import AetherPlayer

@MainActor
final class RecentsStoreTests: XCTestCase {
    private func makeStore() -> RecentsStore {
        let d = UserDefaults(suiteName: "RecentsStoreTests-\(UUID().uuidString)")!
        return RecentsStore(defaults: d)
    }
    private func url(_ n: String) -> URL { URL(fileURLWithPath: "/m/\(n)") }
    private let bm = Data([1, 2, 3])

    func testRecordMovesToFrontAndDedupes() {
        let s = makeStore()
        s.record(url: url("a.mkv"), bookmarkData: bm, duration: 100)
        s.record(url: url("b.mkv"), bookmarkData: bm, duration: 100)
        s.record(url: url("a.mkv"), bookmarkData: bm, duration: 100)
        XCTAssertEqual(s.items.map { $0.name }, ["a.mkv", "b.mkv"])
    }

    func testCapAt30() {
        let s = makeStore()
        for i in 0..<35 { s.record(url: url("f\(i).mkv"), bookmarkData: bm, duration: 100) }
        XCTAssertEqual(s.items.count, 30)
        XCTAssertEqual(s.items.first?.name, "f34.mkv")
    }

    func testPositionRoundTripAndFinish() {
        let s = makeStore()
        s.record(url: url("a.mkv"), bookmarkData: bm, duration: 100)
        s.updatePosition(42, duration: 100, for: url("a.mkv"))
        XCTAssertEqual(s.position(for: url("a.mkv"))?.position, 42)
        s.markFinished(url("a.mkv"))
        XCTAssertEqual(s.position(for: url("a.mkv"))?.position, 0)
    }

    func testRemoveAndClear() {
        let s = makeStore()
        s.record(url: url("a.mkv"), bookmarkData: bm, duration: 100)
        s.record(url: url("b.mkv"), bookmarkData: bm, duration: 100)
        s.remove(s.items.first { $0.name == "a.mkv" }!)
        XCTAssertEqual(s.items.map { $0.name }, ["b.mkv"])
        s.clearAll()
        XCTAssertTrue(s.items.isEmpty)
    }
}
