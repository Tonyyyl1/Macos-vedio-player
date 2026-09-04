import SwiftUI
import AVKit

struct PlayerPresenter: UIViewControllerRepresentable {
    let model: PlayerViewModel

    func makeUIViewController(context: Context) -> PlayerHostController {
        PlayerHostController(model: model)
    }
    func updateUIViewController(_ uiViewController: PlayerHostController, context: Context) {}
}
