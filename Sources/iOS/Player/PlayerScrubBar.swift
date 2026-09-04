import SwiftUI
import AetherEngine

/// Touch scrub track: drag-to-scrub with a deferred seek on release. The
/// touch analog of macOS `ScrubBar` (`Sources/macOS/Views/TransportBar.swift`),
/// dropping `onContinuousHover` (touch has no hover) and keeping
/// `DragGesture(minimumDistance: 0)` as the sole driver of both the live
/// preview and the committed seek.
struct PlayerScrubBar: View {
    let progress: Double
    let duration: Double
    let scrubPreview: ScrubPreviewProvider
    @Binding var scrubbing: Bool
    @Binding var scrubFraction: Double
    let onSeek: (Double) -> Void

    private let trackHeight: CGFloat = 5
    private let previewWidth: CGFloat = 160

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let active = min(max(scrubbing ? scrubFraction : progress, 0), 1)
            let knobX = CGFloat(active) * width
            let knobSize: CGFloat = scrubbing ? 20 : 14
            ZStack(alignment: .leading) {
                Capsule().fill(.white.opacity(0.25)).frame(height: trackHeight)
                Capsule().fill(LinearGradient.aetherAccent).frame(width: knobX, height: trackHeight)
                Circle().fill(Color.aetherPurple).frame(width: knobSize, height: knobSize)
                    .offset(x: knobX - knobSize / 2)
            }
            .frame(maxHeight: .infinity)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        scrubbing = true
                        scrubFraction = fraction(value.location.x, width)
                        scrubPreview.update(fraction: scrubFraction, durationSeconds: duration)
                    }
                    .onEnded { value in
                        let f = fraction(value.location.x, width)
                        scrubFraction = f
                        onSeek(f * duration)
                        scrubbing = false
                        scrubPreview.clear()
                    }
            )
            .overlay(alignment: .bottomLeading) {
                if scrubbing, let image = scrubPreview.previewImage {
                    ScrubThumbnail(image: image, time: scrubFraction * duration)
                        .offset(x: clampThumbX(scrubFraction, Double(width), Double(previewWidth)), y: -96)
                }
            }
        }
        .frame(height: 28)
    }

    private func fraction(_ x: CGFloat, _ width: CGFloat) -> Double {
        width > 0 ? min(max(Double(x / width), 0), 1) : 0
    }
    private func clampThumbX(_ fraction: Double, _ width: Double, _ thumbWidth: Double) -> CGFloat {
        CGFloat(min(max(fraction * width - thumbWidth / 2, 0), max(0, width - thumbWidth)))
    }
}

/// The floating keyframe preview shown above the playhead while scrubbing.
private struct ScrubThumbnail: View {
    let image: CGImage
    let time: Double
    private static let width: CGFloat = 160
    private var height: CGFloat {
        image.width > 0 ? Self.width * CGFloat(image.height) / CGFloat(image.width) : Self.width * 9 / 16
    }
    var body: some View {
        VStack(spacing: 2) {
            Image(decorative: image, scale: 1, orientation: .up)
                .resizable().frame(width: Self.width, height: height)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(.white.opacity(0.3), lineWidth: 1))
            Text(formatTimecode(time))
                .font(.system(.caption2, design: .monospaced)).foregroundStyle(.white)
                .padding(.horizontal, 4).padding(.vertical, 1)
                .background(.black.opacity(0.6), in: Capsule())
        }
        .shadow(radius: 6)
    }
}
