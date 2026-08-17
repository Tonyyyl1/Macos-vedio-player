import AVKit

// MARK: - AVPlayerViewControllerDelegate (Picture in Picture)

/// AVKit-native auto-PiP handoff. No custom PiP button and no manual
/// `AVPictureInPictureController`; AVKit drives PiP directly off this delegate
/// when the user swipes Home during playback.
///
/// `nonisolated`: with Swift 6 + InferIsolatedConformances a plain `func` here
/// would silently inherit MainActor isolation from the class, which trips
/// `_dispatch_assert_queue_fail` if AVKit invokes the selector off-main before
/// the isolation check runs. Declaring `nonisolated` and hopping via
/// `Task { @MainActor }` keeps all `model`/`pipActive` access on the actor
/// while satisfying the (nonisolated) protocol requirement AVKit expects.
extension PlayerHostController: AVPlayerViewControllerDelegate {
    // Keep the player presented when PiP starts (the default dismisses it, so
    // returning from PiP would land back on the presenting view instead of
    // restoring fullscreen).
    nonisolated func playerViewControllerShouldAutomaticallyDismissAtPictureInPictureStart(
        _ playerViewController: AVPlayerViewController
    ) -> Bool {
        false
    }

    // `pipActive` is set synchronously (before PiP dismisses this VC) so
    // viewWillDisappear can distinguish a PiP handoff from a real teardown.
    nonisolated func playerViewControllerWillStartPictureInPicture(_ playerViewController: AVPlayerViewController) {
        pipActive = true
        Task { @MainActor [weak self] in self?.model.engine.pictureInPictureActive = true }
    }

    nonisolated func playerViewControllerDidStopPictureInPicture(_ playerViewController: AVPlayerViewController) {
        // Reset the latch synchronously (mirrors willStart). Without this, pipActive stays true
        // after a normal PiP stop and viewWillDisappear's `!pipActive` guard would skip model.stop()
        // on the next real dismissal, leaking the engine session.
        pipActive = false
        Task { @MainActor [weak self] in self?.model.engine.pictureInPictureActive = false }
    }

    nonisolated func playerViewController(
        _ playerViewController: AVPlayerViewController,
        failedToStartPictureInPictureWithError error: any Error
    ) {
        Task { @MainActor [weak self] in self?.pipActive = false }
    }
}
