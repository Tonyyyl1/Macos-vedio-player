import Testing
import CoreGraphics
@testable import AetherPlayer

struct PlatformImageTests {
    private func makeCGImage(w: Int = 4, h: Int = 4) -> CGImage {
        let cs = CGColorSpaceCreateDeviceRGB()
        let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8,
                            bytesPerRow: 0, space: cs,
                            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        ctx.setFillColor(CGColor(red: 1, green: 0, blue: 0, alpha: 1))
        ctx.fill(CGRect(x: 0, y: 0, width: w, height: h))
        return ctx.makeImage()!
    }

    @Test func roundTripsThroughCGImage() {
        let cg = makeCGImage()
        let platform = PlatformImage.from(cgImage: cg)
        let back = platform.cgImageValue
        #expect(back != nil)
        #expect(back?.width == 4)
        #expect(back?.height == 4)
    }
}
