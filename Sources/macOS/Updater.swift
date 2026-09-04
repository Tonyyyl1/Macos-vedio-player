#if DIRECT_DISTRIBUTION
import SwiftUI
import Sparkle

/// Owns Sparkle's updater controller. Only compiled into direct-distribution
/// builds; the App Store build omits Sparkle entirely.
@MainActor
final class Updater: ObservableObject {
    let controller: SPUStandardUpdaterController
    init() {
        controller = SPUStandardUpdaterController(startingUpdater: true,
                                                  updaterDelegate: nil,
                                                  userDriverDelegate: nil)
    }
    func checkForUpdates() { controller.checkForUpdates(nil) }
}
#endif
