import XCTest
@testable import AetherPlayer

final class ResumePolicyTests: XCTestCase {
    func testNoResumeWhenTooEarly() {
        XCTAssertNil(resumeTarget(lastPosition: 5, duration: 1000))    // < 10s in
    }
    func testNoResumeWhenEffectivelyFinished() {
        XCTAssertNil(resumeTarget(lastPosition: 990, duration: 1000))  // within last 15s
        XCTAssertNil(resumeTarget(lastPosition: 960, duration: 1000))  // > 95%
    }
    func testResumesInTheMiddle() {
        XCTAssertEqual(resumeTarget(lastPosition: 300, duration: 1000), 300)
    }
    func testNoResumeWithoutDuration() {
        XCTAssertNil(resumeTarget(lastPosition: 300, duration: 0))
        XCTAssertNil(resumeTarget(lastPosition: 300, duration: .nan))
    }
    func testIsFinished() {
        XCTAssertTrue(isEffectivelyFinished(position: 990, duration: 1000))
        XCTAssertFalse(isEffectivelyFinished(position: 300, duration: 1000))
    }
    func testShortFileResumesInMiddle() {
        // A 14s clip stopped at 11s (~79%) must resume, not start over.
        XCTAssertEqual(resumeTarget(lastPosition: 11, duration: 14), 11)
    }
    func testShortFileNearEndIsFinished() {
        // ~96% of a short clip counts as watched.
        XCTAssertNil(resumeTarget(lastPosition: 13.5, duration: 14))
        XCTAssertTrue(isEffectivelyFinished(position: 13.5, duration: 14))
    }
}
