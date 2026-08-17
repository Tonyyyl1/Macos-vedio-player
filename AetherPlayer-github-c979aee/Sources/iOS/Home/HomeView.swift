import SwiftUI
import UniformTypeIdentifiers

struct HomeView: View {
    let model: PlayerViewModel
    @State private var showFileImporter = false
    @State private var showFolderImporter = false
    @State private var showURLSheet = false

    var body: some View {
        NavigationStack {
            ScrollView {
                HStack {
                    Button { showFileImporter = true } label: {
                        Label("Open File", systemImage: "folder")
                    }
                    Button { showFolderImporter = true } label: {
                        Label("Open Folder", systemImage: "folder.badge.plus")
                    }
                    Button { showURLSheet = true } label: {
                        Label("Open URL", systemImage: "link")
                    }
                }
                .buttonStyle(.borderedProminent)
                .padding()
                RecentsGrid(model: model)
            }
            .navigationTitle("AetherPlayer")
        }
        .fileImporter(
            isPresented: $showFileImporter,
            allowedContentTypes: [.movie, .video, .audio],
            allowsMultipleSelection: false
        ) { result in
            DocumentOpen.handlePicked(result, model: model)
        }
        .fileImporter(
            isPresented: $showFolderImporter,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false
        ) { result in
            DocumentOpen.openFolder(result, model: model)
        }
        .sheet(isPresented: $showURLSheet) { OpenURLSheet(model: model) }
    }
}
