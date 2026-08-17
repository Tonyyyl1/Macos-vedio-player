#if os(macOS)
import Foundation
import MediaPlayer
import AppKit
import AetherEngine

/// Drives the macOS system Now-Playing surfaces (Control Center widget,
/// media keys) for every backend. On macOS, AVPlayer does not auto-
/// populate MPNowPlayingInfoCenter, so the host writes it directly. The
/// controller is metadata/clock agnostic: the view model pushes updates
/// and the remote-command callbacks route back into the view model.
@MainActor
final class NowPlayingController {
    private let info = MPNowPlayingInfoCenter.default()
    private let commands = MPRemoteCommandCenter.shared()
    private var configured = false

    /// Wire transport commands once. Each closure calls back into the
    /// supplied action set (the view model's methods).
    func configure(actions: Actions) {
        guard !configured else { return }
        configured = true

        commands.playCommand.addTarget { _ in actions.play(); return .success }
        commands.pauseCommand.addTarget { _ in actions.pause(); return .success }
        commands.togglePlayPauseCommand.addTarget { _ in actions.toggle(); return .success }

        commands.skipForwardCommand.preferredIntervals = [10]
        commands.skipForwardCommand.addTarget { _ in actions.skip(10); return .success }
        commands.skipBackwardCommand.preferredIntervals = [10]
        commands.skipBackwardCommand.addTarget { _ in actions.skip(-10); return .success }

        commands.nextTrackCommand.addTarget { _ in actions.next(); return .success }
        commands.previousTrackCommand.addTarget { _ in actions.previous(); return .success }

        commands.changePlaybackPositionCommand.addTarget { event in
            guard let e = event as? MPChangePlaybackPositionCommandEvent else { return .commandFailed }
            actions.seekTo(e.positionTime)
            return .success
        }
    }

    /// Enable/disable next/previous to match playlist availability.
    func updateAvailability(hasNext: Bool, hasPrevious: Bool) {
        commands.nextTrackCommand.isEnabled = hasNext
        commands.previousTrackCommand.isEnabled = hasPrevious
    }

    /// Push the current metadata + clock to the system. Pass nil to clear.
    func update(metadata: MediaMetadata?, fallbackTitle: String,
                duration: Double, elapsed: Double, rate: Float) {
        var dict = nowPlayingInfo(
            metadata: metadata, fallbackTitle: fallbackTitle,
            duration: duration, elapsed: elapsed, rate: rate)
        if let data = metadata?.artworkData, let image = NSImage(data: data) {
            dict[MPMediaItemPropertyArtwork] = Self.makeArtwork(image)
        }
        info.nowPlayingInfo = dict
        info.playbackState = rate > 0 ? .playing : .paused
    }

    /// Wrap an image as `MPMediaItemArtwork`. MediaPlayer invokes the
    /// request handler on its own internal queue, so the closure must NOT
    /// be main-actor-isolated; otherwise Swift's actor-isolation runtime
    /// check traps (SIGTRAP) the moment MediaPlayer renders the artwork.
    /// A `nonisolated` context produces a plain, non-isolated closure.
    private nonisolated static func makeArtwork(_ image: NSImage) -> MPMediaItemArtwork {
        MPMediaItemArtwork(boundsSize: image.size) { _ in image }
    }

    /// Clear the system surface on stop.
    func clear() {
        info.nowPlayingInfo = nil
        info.playbackState = .stopped
    }

    struct Actions {
        let play: () -> Void
        let pause: () -> Void
        let toggle: () -> Void
        let skip: (Double) -> Void
        let next: () -> Void
        let previous: () -> Void
        let seekTo: (Double) -> Void
    }
}
#else
import Foundation
import AetherEngine

/// iOS no-op: Now Playing is owned by AVPlayerViewController via
/// AVPlayerItem.externalMetadata (Task 2.4). Manual MPNowPlayingInfoCenter
/// writes crash against the engine's HLS loopback (_dispatch_assert_queue_fail),
/// so this stub keeps `PlayerViewModel`'s calls valid without touching MediaPlayer.
@MainActor
final class NowPlayingController {
    struct Actions {
        let play: () -> Void
        let pause: () -> Void
        let toggle: () -> Void
        let skip: (Double) -> Void
        let next: () -> Void
        let previous: () -> Void
        let seekTo: (Double) -> Void
    }

    func configure(actions: Actions) {}

    func updateAvailability(hasNext: Bool, hasPrevious: Bool) {}

    func update(metadata: MediaMetadata?, fallbackTitle: String,
                duration: Double, elapsed: Double, rate: Float) {}

    func clear() {}
}
#endif
