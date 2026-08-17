import SwiftUI
import UniformTypeIdentifiers

struct TracksSheet: View {
    let model: PlayerViewModel
    @Binding var showStats: Bool
    @Environment(\.dismiss) private var dismiss
    @State private var showSRTImporter = false

    var body: some View {
        NavigationStack {
            List {
                Section("Audio") {
                    ForEach(audioMenuRows(model.audioTracks, activeIndex: model.activeAudioTrackIndex)) { row in
                        Button {
                            model.selectAudio(engineIndex: row.engineIndex)
                        } label: {
                            trackRow(row.label, isSelected: row.isSelected)
                        }
                    }
                }
                Section("Subtitles") {
                    ForEach(subtitleMenuRows(model.subtitleTracks,
                                             selectedEngineIndex: model.selectedSubtitleIndex,
                                             isActive: model.isSubtitleActive)) { row in
                        Button {
                            switch row.kind {
                            case .off:
                                model.disableSubtitle()
                            case .track(let idx):
                                model.selectSubtitle(engineIndex: idx)
                            }
                        } label: {
                            trackRow(row.label, isSelected: row.isSelected)
                        }
                    }
                    Button("Load subtitle file...") {
                        showSRTImporter = true
                    }
                }
                Section("Subtitle Size") {
                    Picker("Size", selection: Binding(
                        get: { model.subtitleSize },
                        set: { model.setSubtitleSize($0) }
                    )) {
                        ForEach(SubtitleSize.allCases) { size in
                            Text(size.label).tag(size)
                        }
                    }
                }
                Section {
                    Toggle("Stats for Nerds", isOn: $showStats)
                }
            }
            .navigationTitle("Tracks")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .fileImporter(isPresented: $showSRTImporter,
                          allowedContentTypes: [UTType("public.srt") ?? .plainText, .plainText],
                          allowsMultipleSelection: false) { result in
                if case let .success(urls) = result, let url = urls.first {
                    let scoped = url.startAccessingSecurityScopedResource()
                    model.loadSidecarSubtitle(url: url)
                    if scoped { url.stopAccessingSecurityScopedResource() }
                }
            }
        }
    }

    @ViewBuilder
    private func trackRow(_ label: String, isSelected: Bool) -> some View {
        HStack {
            Text(label)
            Spacer()
            if isSelected {
                Image(systemName: "checkmark")
            }
        }
    }
}
