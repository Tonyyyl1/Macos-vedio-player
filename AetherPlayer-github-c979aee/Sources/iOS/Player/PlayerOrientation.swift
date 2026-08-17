import UIKit

/// Process-wide orientation policy for the fullscreen player. OrientationAppDelegate reads
/// `playerMask` from `application(_:supportedInterfaceOrientationsFor:)`. Lock freezes the current
/// orientation (system-rotation-lock style); follow leaves rotation to the device. iPad is never
/// managed (it allows all). MainActor-isolated: every access is on the main thread (UIKit scene
/// and view-controller APIs), and the static state is only mutated from there.
@MainActor
enum PlayerOrientation {
    /// Orientation mask the player session enforces; nil while no player is up, or in follow mode.
    static private(set) var playerMask: UIInterfaceOrientationMask?
    /// Player session up with rotation following the device (lock icon open).
    static private(set) var isFollowing = false

    static var isPhone: Bool { UIDevice.current.userInterfaceIdiom == .phone }

    /// Player entry: apply the persisted mode, but never stomp a mode the in-player toggle already set.
    static func engage(locked: Bool) {
        guard isPhone, playerMask == nil, !isFollowing else { return }
        if locked { lockToCurrent() } else { follow() }
    }

    /// Freeze whatever orientation the user is holding.
    static func lockToCurrent() {
        guard isPhone else { return }
        isFollowing = false
        let mask = mask(for: currentOrientation)
        playerMask = mask
        apply(mask)
    }

    static func follow() {
        guard isPhone else { return }
        isFollowing = true
        playerMask = nil
        // No forced rotation; widening the allowed set lets the device attitude take over.
        refreshSupportedOrientations()
    }

    /// Release the lock on player exit; the device orientation takes over (home supports landscape).
    static func unlock() {
        guard isPhone else { return }
        isFollowing = false
        playerMask = nil
        refreshSupportedOrientations()
    }

    private static var scene: UIWindowScene? {
        UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
    }

    private static var currentOrientation: UIInterfaceOrientation {
        scene?.effectiveGeometry.interfaceOrientation ?? .landscapeRight
    }

    private static func mask(for orientation: UIInterfaceOrientation) -> UIInterfaceOrientationMask {
        switch orientation {
        case .portrait: .portrait
        case .portraitUpsideDown: .portraitUpsideDown
        case .landscapeLeft: .landscapeLeft
        case .landscapeRight: .landscapeRight
        default: .landscape
        }
    }

    private static func apply(_ orientation: UIInterfaceOrientationMask) {
        guard let scene else { return }
        scene.requestGeometryUpdate(.iOS(interfaceOrientations: orientation))
        refreshSupportedOrientations()
    }

    /// The player modal owns the orientation decision while presented, so the update must reach the
    /// top-most presented VC, not just the root.
    private static func refreshSupportedOrientations() {
        guard let root = scene?.keyWindow?.rootViewController else { return }
        var top = root
        while let presented = top.presentedViewController { top = presented }
        top.setNeedsUpdateOfSupportedInterfaceOrientations()
        if top !== root { root.setNeedsUpdateOfSupportedInterfaceOrientations() }
    }
}
