import SwiftUI

struct RootView: View {
    @Bindable var model: PlayerViewModel

    var body: some View {
        HomeView(model: model)
            .fullScreenCover(isPresented: Binding(
                get: { model.hasMedia },
                set: { if !$0 { model.stop() } })) {
                ZStack {
                    PlayerPresenter(model: model).ignoresSafeArea()
                    PlayerChrome(model: model)
                }
            }
    }
}
