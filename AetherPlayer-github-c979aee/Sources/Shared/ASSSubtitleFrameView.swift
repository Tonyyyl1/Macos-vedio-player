import SwiftUI
import Combine
import SwiftAssRenderer
#if os(macOS)
import AppKit
#else
import UIKit
#endif

// MARK: - Styled ASS host (platform-split)

/// Hosts the styled ASS frame stream. A clone of swift-ass-renderer's `AssSubtitlesView`
/// (canvas sized in layout, frames drawn at `ProcessedImage.imageRect`) with ONE difference:
/// nil frames from the coordinator's `reloadTrack` are suppressed. The renderer publishes a
/// transient nil before the identical re-render lands, which blinked every visible sub; the
/// coordinator pre-announces reloads via `reloadSignal` so suppression is deterministic. A nil
/// with no announced reload is a real cue end and hides instantly.
///
/// Frames are drawn into a `CALayer` (contents = `CGImage`) so the same host compiles on iOS
/// (UIView) and macOS (NSView). See `ASSFrameHostView` for the macOS geometry handling.
#if os(macOS)
struct ASSRenderedSubtitles: NSViewRepresentable {
    let renderer: AssSubtitlesRenderer
    let reloadSignal: PassthroughSubject<Void, Never>
    /// Playback offset (overlay's `currentTime`, a sourceTime mirror); frame view needs it for
    /// track-data queries since the renderer's own offset is not public here.
    let currentOffset: Double

    func makeNSView(context: Context) -> ASSFrameHostView {
        ASSFrameHostView(renderer: renderer, reloadSignal: reloadSignal)
    }

    func updateNSView(_ view: ASSFrameHostView, context: Context) {
        view.currentOffset = currentOffset
    }
}
#else
struct ASSRenderedSubtitles: UIViewRepresentable {
    let renderer: AssSubtitlesRenderer
    let reloadSignal: PassthroughSubject<Void, Never>
    /// Playback offset (overlay's `currentTime`, a sourceTime mirror); frame view needs it for
    /// track-data queries since the renderer's own offset is not public here.
    let currentOffset: Double

    func makeUIView(context: Context) -> ASSFrameHostView {
        ASSFrameHostView(renderer: renderer, reloadSignal: reloadSignal)
    }

    func updateUIView(_ view: ASSFrameHostView, context: Context) {
        view.currentOffset = currentOffset
    }
}
#endif

#if os(macOS)
typealias ASSHostBase = NSView
#else
typealias ASSHostBase = UIView
#endif

final class ASSFrameHostView: ASSHostBase {
    /// Playback offset fed by the representable on every SwiftUI update (~10 Hz).
    var currentOffset: Double = 0
    private let renderer: AssSubtitlesRenderer
    /// Frames are drawn as this layer's `contents` (a `CGImage`), positioned by `imageRect`.
    private let imageLayer = CALayer()
    private var lastRenderBounds = CGRect.zero
    private var cancellables = Set<AnyCancellable>()
    /// Suppress nil frames until this deadline (armed per reload signal). `.distantPast` = off.
    private var suppressNilDeadline = Date.distantPast
    /// Deferred hide scheduled during suppression so a swallowed real cue end still hides.
    private var hideWorkItem: DispatchWorkItem?
    /// Generous upper bound for one reload round-trip (parse + font matching + render).
    private static let reloadSuppressWindow: TimeInterval = 0.5

    init(renderer: AssSubtitlesRenderer, reloadSignal: PassthroughSubject<Void, Never>) {
        self.renderer = renderer
        super.init(frame: .zero)
        imageLayer.contentsGravity = .resize
        #if os(macOS)
        // Layer-backed NSView. Flipping the backing layer's geometry (plus the matching
        // `isFlipped` override below) establishes a top-left origin world like iOS, so libass'
        // top-left `imageRect` applies directly to the sublayer and its CGImage contents render
        // upright. See the class-level geometry note in the task report.
        wantsLayer = true
        layer?.isGeometryFlipped = true
        layer?.backgroundColor = NSColor.clear.cgColor
        layer?.addSublayer(imageLayer)
        #else
        backgroundColor = .clear
        isUserInteractionEnabled = false
        layer.addSublayer(imageLayer)
        #endif
        // No receive(on:): synchronous main-actor delivery arms suppression before the renderer's
        // transient nil can arrive (coordinator sends right before reloadTrack).
        reloadSignal
            .sink { [weak self] in
                self?.suppressNilDeadline = Date().addingTimeInterval(Self.reloadSuppressWindow)
            }
            .store(in: &cancellables)
        renderer
            .framesPublisher()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.handleFrameChanged($0) }
            .store(in: &cancellables)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) not supported")
    }

    /// Backing scale for the libass canvas. Read per layout so a window moved between displays
    /// with different backing factors re-renders at the correct scale.
    private var displayScale: CGFloat {
        #if os(macOS)
        return window?.backingScaleFactor ?? 2
        #else
        return UITraitCollection.current.displayScale
        #endif
    }

    #if os(macOS)
    override var isFlipped: Bool { true }
    /// Never swallow mouse events meant for the video / chrome beneath (iOS uses isUserInteractionEnabled).
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
    override func layout() {
        super.layout()
        handleLayout()
    }
    #else
    override func layoutSubviews() {
        super.layoutSubviews()
        handleLayout()
    }
    #endif

    private func handleLayout() {
        // A zero-bounds pass must never reach the renderer: a 0x0 canvas renders every event as
        // nil, hiding the visible subtitle with no reload announced.
        guard !bounds.isEmpty else { return }
        if !lastRenderBounds.isEmpty, imageLayer.contents != nil, lastRenderBounds != bounds {
            let ratioX = bounds.width / lastRenderBounds.width
            let ratioY = bounds.height / lastRenderBounds.height
            let f = imageLayer.frame
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            imageLayer.frame = CGRect(
                x: f.origin.x * ratioX, y: f.origin.y * ratioY,
                width: f.width * ratioX, height: f.height * ratioY
            ).integral
            CATransaction.commit()
        }
        renderer.setCanvasSize(bounds.size, scale: displayScale)
    }

    // MARK: Frame application

    private func setFrame(_ image: ProcessedImage) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        imageLayer.frame = image.imageRect
        imageLayer.contents = image.image   // CGImage, cross-platform
        imageLayer.isHidden = false
        CATransaction.commit()
    }

    private func hideNow() {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        imageLayer.isHidden = true
        imageLayer.contents = nil
        CATransaction.commit()
        suppressNilDeadline = .distantPast
    }

    // MARK: Nil-frame suppression (ported verbatim from Sodalite SubtitleOverlayView.swift 453-520)

    private func handleFrameChanged(_ image: ProcessedImage?) {
        if let image {
            hideWorkItem?.cancel()
            hideWorkItem = nil
            suppressNilDeadline = .distantPast
            lastRenderBounds = bounds
            setFrame(image)
        } else {
            let remaining = suppressNilDeadline.timeIntervalSinceNow
            guard remaining > 0 else {
                // Real cue end (no reload announced): hide instantly.
                hideWorkItem?.cancel()
                hideWorkItem = nil
                hideNow()
                return
            }
            // Reload in flight: keep the last image; arm a safety hide at the deadline in case no
            // frame follows (reload coinciding with a real cue end).
            guard hideWorkItem == nil else { return }
            scheduleSafetyHide(after: remaining)
        }
    }

    /// Resolve a suppression window that ended without a new frame (re-arms if a newer reload
    /// extended the deadline). libass skips the publish when a reload's re-render is visually
    /// identical (parked on the transient nil), so at the deadline query track data directly: an
    /// active event means keep the image and end suppression; none means hide (reload hit a cue end).
    private func scheduleSafetyHide(after delay: TimeInterval) {
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.hideWorkItem = nil
            let remaining = self.suppressNilDeadline.timeIntervalSinceNow
            if remaining > 0 {
                self.scheduleSafetyHide(after: remaining)
                return
            }
            let stillActive = !self.renderer.dialogues(at: self.currentOffset).isEmpty
            if stillActive {
                self.suppressNilDeadline = .distantPast
                // Frame subject is parked on nil, so the real cue end's nil-after-nil is swallowed
                // by the duplicate filter and the frame would linger forever. Watch track data for
                // the end ourselves until the next published frame.
                self.scheduleEndWatch()
            } else {
                self.hideNow()
            }
        }
        hideWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }

    /// Poll track data while holding a manually-kept frame; hide once no event is active.
    /// Cancelled by any freshly published frame (handleFrameChanged cancels `hideWorkItem`).
    private func scheduleEndWatch() {
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.hideWorkItem = nil
            if self.renderer.dialogues(at: self.currentOffset).isEmpty {
                self.hideNow()
            } else {
                self.scheduleEndWatch()
            }
        }
        hideWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1, execute: work)
    }
}
