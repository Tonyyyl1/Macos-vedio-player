import SwiftUI
import AppKit

/// AppKit-bridging NSView that captures key events at the window level
/// and forwards them. SwiftUI's `.onKeyPress` needs focus the full-bleed
/// video area can't reliably claim; an NSView in the responder chain gets
/// keyDown for free.
struct KeyCatcherView: NSViewRepresentable {
    let onKey: (NSEvent) -> Bool
    func makeNSView(context: Context) -> _KeyView {
        let v = _KeyView(); v.onKey = onKey; return v
    }
    func updateNSView(_ nsView: _KeyView, context: Context) { nsView.onKey = onKey }

    final class _KeyView: NSView {
        var onKey: ((NSEvent) -> Bool)?
        override var acceptsFirstResponder: Bool { true }
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            window?.makeFirstResponder(self)
        }
        override func keyDown(with event: NSEvent) {
            if onKey?(event) == true { return }
            super.keyDown(with: event)
        }
    }
}
