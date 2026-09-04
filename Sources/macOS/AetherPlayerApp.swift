import SwiftUI
import AppKit
import UniformTypeIdentifiers

@main
struct AetherPlayerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    @State private var model: PlayerViewModel? = {
        try? PlayerViewModel()
    }()
    @State private var alwaysOnTop = false
#if DIRECT_DISTRIBUTION
    @StateObject private var updater = Updater()
#endif

    var body: some Scene {
        Window("AetherPlayer", id: "main") {
            Group {
                if let model {
                    ContentView(model: model)
                } else {
                    Text("AetherEngine failed to initialize.")
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.black)
                }
            }
            .onAppear {
                NSApp.windows.first?.setFrameAutosaveName("AetherPlayerMainWindow")
                if let model {
                    // Activation/fronting is handled in AppDelegate; just load.
                    AppDelegate.onOpenFiles = { urls in
                        guard !urls.isEmpty else { return }
                        Task { @MainActor in await model.open(urls: urls) }
                    }
                }
            }
            .onChange(of: alwaysOnTop) { _, on in
                NSApp.keyWindow?.level = on ? .floating : .normal
            }
            .frame(minWidth: 640, minHeight: 360)
        }
        .windowResizability(.contentMinSize)
        .commands {
#if DIRECT_DISTRIBUTION
            CommandGroup(after: .appInfo) {
                Button("Check for Updates\u{2026}") { updater.checkForUpdates() }
            }
#endif
            CommandGroup(replacing: .newItem) {
                Button("Open\u{2026}") { openFile() }
                    .keyboardShortcut("o", modifiers: .command)
                Button("Open Folder\u{2026}") { openFolderPanel() }
                    .keyboardShortcut("o", modifiers: [.command, .shift])
            }
            CommandGroup(replacing: .saveItem) {
                Button("Save Frame As\u{2026}") {
                    if let model { SnapshotSaver.captureAndSave(model: model) }
                }
                .keyboardShortcut("s", modifiers: [.command, .shift])
                .disabled(model?.hasMedia != true)
            }
            CommandMenu("Audio") {
                if let model {
                    ForEach(audioMenuRows(model.audioTracks, activeIndex: model.activeAudioTrackIndex)) { row in
                        Button(action: { model.selectAudio(engineIndex: row.engineIndex) }) {
                            Text((row.isSelected ? "\u{2713} " : "") + row.label)
                        }
                    }
                }
            }
            CommandMenu("Subtitles") {
                if let model {
                    ForEach(subtitleMenuRows(model.subtitleTracks,
                                             selectedEngineIndex: model.selectedSubtitleIndex,
                                             isActive: model.isSubtitleActive)) { row in
                        Button(action: {
                            switch row.kind {
                            case .off: model.disableSubtitle()
                            case .track(let idx): model.selectSubtitle(engineIndex: idx)
                            }
                        }) {
                            Text((row.isSelected ? "\u{2713} " : "") + row.label)
                        }
                    }
                }
            }
            CommandMenu("Window") {
                Toggle("Always on Top", isOn: $alwaysOnTop)
                    .keyboardShortcut("t", modifiers: [.command, .shift])
                Menu("Subtitle Size") {
                    if let model {
                        ForEach(SubtitleSize.allCases) { size in
                            Button(action: { model.setSubtitleSize(size) }) {
                                Text((model.subtitleSize == size ? "\u{2713} " : "") + size.label)
                            }
                        }
                    }
                }
            }
            StatsCommands()
        }

        Window("Stats for Nerds", id: "stats") {
            Group {
                if let model {
                    StatsInspectorView(model: model)
                } else {
                    Text("No player.").frame(minWidth: 320, minHeight: 420)
                }
            }
        }
        .windowResizability(.contentMinSize)
        .defaultPosition(.topTrailing)
        // SwiftUI auto-adds a Window-menu item for every Window scene, using its title. That collided with the
        // explicit StatsCommands button (which carries the Cmd-Shift-I shortcut), showing "Stats for Nerds" twice.
        // commandsRemoved() drops the auto item so only the explicit, shortcut-bearing entry remains.
        .commandsRemoved()

        Settings {
            PreferencesView()
        }
    }

    private func openFile() {
        guard let model else { return }
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.allowedContentTypes = MediaTypePolicy.playableContentTypes
        if panel.runModal() == .OK, !panel.urls.isEmpty {
            Task { await model.open(urls: panel.urls) }
        }
    }

    private func openFolderPanel() {
        guard let model else { return }
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            let bm = BookmarkAccess.bookmark(for: url)
            Task { await model.openFolder(url, bookmarkData: bm) }
        }
    }
}

private struct StatsCommands: Commands {
    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        CommandGroup(after: .windowArrangement) {
            Button("Stats for Nerds") { openWindow(id: "stats") }
                .keyboardShortcut("i", modifiers: [.command, .shift])
        }
    }
}

/// Preferences window (Cmd-,). Currently the forward-buffer depth; a home for future settings.
private struct PreferencesView: View {
    // 0 == Auto (engine default); otherwise a forward-buffer segment count
    // (AetherEngine #102, engine clamps to 4...150). Applied on the next open.
    @AppStorage("playback.forwardBufferSegments") private var forwardBufferSegments = 0

    var body: some View {
        Form {
            Picker("Forward buffer", selection: $forwardBufferSegments) {
                Text("Auto").tag(0)
                Text("Small (8 segments)").tag(8)
                Text("Default (30 segments)").tag(30)
                Text("Large (60 segments)").tag(60)
                Text("Maximum (120 segments)").tag(120)
            }
            Text("How far ahead to buffer. Higher values help slow or unstable sources at the cost of memory, and apply to the next file you open.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(20)
        .frame(width: 440)
    }
}
