import SwiftUI

struct OpenURLSheet: View {
    let model: PlayerViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    private var validURL: URL? { MediaURLValidation.normalized(text) }

    var body: some View {
        NavigationStack {
            Form {
                TextField("https://example.com/video.mkv", text: $text)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.URL)
            }
            .navigationTitle("Open URL")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Play") {
                        if let url = validURL {
                            Task { await model.open(url: url) }
                            dismiss()
                        }
                    }.disabled(validURL == nil)
                }
            }
        }
    }
}
