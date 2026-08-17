import AppKit
import CoreGraphics
import UniformTypeIdentifiers

/// Captures the current frame from the model and writes it to a
/// user-chosen PNG via a save panel. The panel grants write access, so no
/// read-write entitlement is needed.
@MainActor
enum SnapshotSaver {
    /// Capture + save. No-op if the frame can't be captured or the user cancels.
    static func captureAndSave(model: PlayerViewModel) {
        // Capture the time and name now, before the async decode lets
        // playback advance, so the suggested filename matches the frame.
        let atTime = model.currentTime
        let movieName = model.loadedURL?.lastPathComponent ?? "Frame"
        Task {
            guard let image = await model.snapshotCurrentFrame() else { return }
            let name = snapshotFilename(movieName: movieName, at: atTime)
            present(image, suggestedName: name)
        }
    }

    private static func present(_ image: CGImage, suggestedName: String) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.png]
        panel.nameFieldStringValue = suggestedName
        panel.canCreateDirectories = true
        // begin(completionHandler:) rather than runModal(): we are inside a
        // Task continuation here (after the async snapshot), and begin()
        // presents on the main run loop and calls back without spinning a
        // nested modal loop. Displaying the panel at all requires the
        // user-selected read-write entitlement (read-only is rejected).
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            let rep = NSBitmapImageRep(cgImage: image)
            guard let data = rep.representation(using: .png, properties: [:]) else { return }
            try? data.write(to: url)
        }
    }
}
