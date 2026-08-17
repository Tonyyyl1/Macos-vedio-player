import CoreGraphics
#if os(macOS)
import AppKit
public typealias PlatformImage = NSImage
#else
import UIKit
public typealias PlatformImage = UIImage
#endif

extension PlatformImage {
    static func from(cgImage: CGImage) -> PlatformImage {
        #if os(macOS)
        return NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
        #else
        return UIImage(cgImage: cgImage)
        #endif
    }

    var cgImageValue: CGImage? {
        #if os(macOS)
        var rect = NSRect(x: 0, y: 0, width: size.width, height: size.height)
        return cgImage(forProposedRect: &rect, context: nil, hints: nil)
        #else
        return cgImage
        #endif
    }
}
