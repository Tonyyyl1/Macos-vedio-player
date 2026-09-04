import Testing
import Foundation
@testable import AetherPlayer

struct MediaURLValidationTests {
    @Test func acceptsHTTPURL() {
        #expect(MediaURLValidation.normalized("http://x.com/a.mkv")?.scheme == "http")
        #expect(MediaURLValidation.normalized("https://x.com/a.mkv")?.scheme == "https")
    }
    @Test func trimsWhitespace() {
        #expect(MediaURLValidation.normalized("  https://x.com/a.mp4  ") != nil)
    }
    @Test func rejectsEmptyAndNonURL() {
        #expect(MediaURLValidation.normalized("") == nil)
        #expect(MediaURLValidation.normalized("not a url") == nil)
    }
    @Test func rejectsUnsupportedScheme() {
        #expect(MediaURLValidation.normalized("ftp://x.com/a.mkv") == nil)
    }
}
