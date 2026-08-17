import SwiftUI
import UIKit

/// Supplies the player's orientation mask to UIKit. Free rotation (allButUpsideDown) when no player
/// is up or in follow mode; the locked mask while the player pins an orientation.
final class OrientationAppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        // UIKit calls this on the main thread; read the MainActor-isolated mask safely.
        MainActor.assumeIsolated { PlayerOrientation.playerMask ?? .allButUpsideDown }
    }
}

@main
struct AetherPlayerApp: App {
    @UIApplicationDelegateAdaptor(OrientationAppDelegate.self) private var appDelegate
    @State private var model: PlayerViewModel? = { try? PlayerViewModel() }()

    var body: some Scene {
        WindowGroup {
            if let model {
                RootView(model: model)
                    .onOpenURL { url in
                        DocumentOpen.open(url, model: model)
                    }
            } else {
                Text("AetherEngine failed to initialize.")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.black).foregroundStyle(.white).ignoresSafeArea()
            }
        }
    }
}
