import SwiftUI
import AppKit
import UniformTypeIdentifiers
import AetherEngine

struct ContentView: View {
    @State private var model: PlayerViewModel
    @State private var isDropTargeted = false

    init(model: PlayerViewModel) {
        _model = State(initialValue: model)
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if model.hasMedia {
                if model.isAudioOnly {
                    NowPlayingView(model: model)
                        .ignoresSafeArea()
                } else {
                    PlayerContainerView(model: model)
                        .ignoresSafeArea()
                }
            } else {
                EmptyStateView(
                    isDropTargeted: isDropTargeted,
                    onOpen: openPanel,
                    recents: model.recents.items,
                    thumbnails: model.recentsThumbnails,
                    onOpenRecent: { item in Task { await model.openRecent(item) } },
                    onRemoveRecent: { model.recents.remove($0) },
                    onClearRecents: { model.clearRecents() }
                )
            }

            if let err = model.loadError {
                VStack {
                    Spacer()
                    Text(err)
                        .font(.callout)
                        .foregroundStyle(.white)
                        .padding(12)
                        .background(.red.opacity(0.85), in: RoundedRectangle(cornerRadius: 8))
                        .padding(.bottom, 24)
                }
                .transition(.opacity)
            }

            if let msg = model.resumeMessage {
                VStack {
                    Spacer()
                    ResumeToastView(message: msg, onStartOver: { model.startOver() })
                        .padding(.bottom, 90)
                }
                .transition(.opacity)
                .task(id: msg) {
                    try? await Task.sleep(for: .seconds(6))
                    model.dismissResumeMessage()
                }
            }
        }
        .animation(.easeInOut(duration: 0.25), value: model.loadError)
        .animation(.easeInOut(duration: 0.25), value: model.resumeMessage)
        .onDrop(of: [.fileURL], isTargeted: $isDropTargeted) { providers in
            guard let provider = providers.first else { return false }
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                guard let url else { return }
                Task { @MainActor in
                    var isDir: ObjCBool = false
                    FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir)
                    if isDir.boolValue {
                        let bm = BookmarkAccess.bookmark(for: url)
                        await model.openFolder(url, bookmarkData: bm)
                    } else if Self.subtitleExtensions.contains(url.pathExtension.lowercased()), model.hasMedia {
                        // A subtitle file dropped onto a playing video attaches as
                        // a sidecar track; anything else loads as a new video.
                        model.loadSidecarSubtitle(url: url)
                    } else if MediaTypePolicy.isPlayable(url) {
                        await model.open(url: url)
                    }
                }
            }
            return true
        }
        .onChange(of: model.loadedURL) { _, _ in updateWindowTitle() }
        .onChange(of: model.metadata) { _, _ in updateWindowTitle() }
        .onChange(of: model.isAudioOnly) { _, _ in updateWindowTitle() }
        .onChange(of: model.loadError) { _, err in
            // Auto-dismiss the error toast after a few seconds, unless a newer
            // error replaced it in the meantime.
            guard err != nil else { return }
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(5))
                if model.loadError == err { model.clearLoadError() }
            }
        }
    }

    /// Sidecar subtitle file extensions recognized on drop.
    private static let subtitleExtensions: Set<String> = ["srt", "ass", "ssa", "vtt", "sub"]

    private func updateWindowTitle() {
        NSApp.keyWindow?.title = windowTitle(
            metadata: model.metadata, url: model.loadedURL, isAudio: model.isAudioOnly)
    }

    func openPanel() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.allowedContentTypes = MediaTypePolicy.playableContentTypes
        if panel.runModal() == .OK, !panel.urls.isEmpty {
            Task { await model.open(urls: panel.urls) }
        }
    }
}
