import SwiftUI
import AVKit

/// Top row of the custom iOS player chrome: Close (leading), AirPlay route (center),
/// Tracks (trailing). Replaces the AVKit-era standalone corner buttons. Does not own
/// the tracks sheet; the caller (PlayerChrome, Task 7) presents it via `onTracks`.
struct PlayerTopBar: View {
    let model: PlayerViewModel
    let onTracks: () -> Void

    var body: some View {
        HStack {
            circle { Image(systemName: "xmark") }.onTapGesture { model.stop() }
            Spacer()
            AirPlayRouteButton().frame(width: 44, height: 44)
                .background(.ultraThinMaterial, in: Circle())
            if PlayerOrientation.isPhone {
                // Fill the circle with the accent gradient when engaged (Control Center pattern); the two
                // padlock glyphs alone read too similarly to tell locked from open at a glance.
                let locked = model.playerRotationLocked
                Image(systemName: locked ? "lock.rotation" : "lock.open.rotation")
                    .font(.title3).foregroundStyle(.white).frame(width: 44, height: 44)
                    .background {
                        if locked { Circle().fill(LinearGradient.aetherAccent) }
                        else { Circle().fill(.ultraThinMaterial) }
                    }
                    .onTapGesture {
                        let newLocked = !locked
                        model.setPlayerRotationLocked(newLocked)
                        if newLocked { PlayerOrientation.lockToCurrent() } else { PlayerOrientation.follow() }
                    }
            }
            circle { Image(systemName: "list.bullet") }.onTapGesture { onTracks() }
        }
        .padding(.horizontal, 16).padding(.top, 8)
    }

    private func circle<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        content().font(.title3).foregroundStyle(.white).frame(width: 44, height: 44)
            .background(.ultraThinMaterial, in: Circle())
    }
}

/// Wraps the system AirPlay route picker for the top bar. prioritizesVideoDevices so it
/// offers Apple TVs / video-capable routes first (ported from Sodalite's AirPlayRouteButton).
struct AirPlayRouteButton: UIViewRepresentable {
    func makeUIView(context: Context) -> AVRoutePickerView {
        let v = AVRoutePickerView()
        v.prioritizesVideoDevices = true
        v.tintColor = .white
        v.activeTintColor = .white
        return v
    }
    func updateUIView(_ uiView: AVRoutePickerView, context: Context) {}
}
