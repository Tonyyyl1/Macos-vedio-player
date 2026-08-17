import SwiftUI
import UIKit

/// Full-screen tap+drag catcher below the controls, above the video. Single tap toggles chrome;
/// double-tap left/right third skips -/+10s, center toggles play/pause. A vertical drag near the
/// left/right edge sets brightness / volume; the wide center is a dead zone.
struct PlayerGestureCatcher: View {
    let onToggleControls: () -> Void
    let onSkip: (Double) -> Void
    let onTogglePlayPause: () -> Void
    let onSetBrightness: (CGFloat) -> Void
    let onSetVolume: (Float) -> Void
    private let skipInterval: Double = 10

    @State private var panAxis: PanAxis = .undecided
    @State private var panZone: PlayerTouchInput.PanZone = .none
    @State private var panStartLevel: Double = 0
    private enum PanAxis { case undecided, vertical, ignored }

    var body: some View {
        GeometryReader { geo in
            Color.clear.contentShape(Rectangle())
                .onTapGesture(count: 2, coordinateSpace: .local) { location in
                    if let seconds = PlayerTouchInput.skipSeconds(forTapX: location.x, width: geo.size.width, interval: skipInterval) {
                        onSkip(seconds)
                    } else {
                        onTogglePlayPause()
                    }
                }
                .onTapGesture { onToggleControls() }
                .simultaneousGesture(verticalPan(in: geo.size))
        }
    }

    private func verticalPan(in size: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 16)
            .onChanged { value in
                if panAxis == .undecided {
                    let isVertical = abs(value.translation.height) > abs(value.translation.width)
                    let zone = PlayerTouchInput.zone(forStartX: value.startLocation.x, width: size.width)
                    if isVertical, zone != .none {
                        panAxis = .vertical
                        panZone = zone
                        panStartLevel = zone == .brightness ? Double(Self.currentBrightness) : Double(PlayerSystemVolume.current)
                    } else {
                        // Vertical drag in the dead center, or a horizontal drag: ignore so it can't change levels.
                        panAxis = .ignored
                    }
                }
                guard panAxis == .vertical else { return }
                let level = panStartLevel + PlayerTouchInput.levelDelta(translationY: value.translation.height, height: size.height)
                switch panZone {
                case .brightness: onSetBrightness(CGFloat(level))
                case .volume: onSetVolume(Float(level))
                case .none: break
                }
            }
            .onEnded { _ in panAxis = .undecided; panZone = .none }
    }

    private static var currentBrightness: CGFloat {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }.first?.screen.brightness ?? 0.5
    }
}
