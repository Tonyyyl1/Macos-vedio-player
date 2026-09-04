import SwiftUI

/// Recents grid for the iOS Home screen. Adaptive column count grows with
/// available width, so iPad (Regular) naturally lays out more columns than
/// iPhone without a separate size-class branch.
struct RecentsGrid: View {
    let model: PlayerViewModel
    private let columns = [GridItem(.adaptive(minimum: 160, maximum: 240), spacing: 12)]

    var body: some View {
        let items = model.recents.items
        if items.isEmpty {
            ContentUnavailableView("No recents yet", systemImage: "clock",
                description: Text("Files you open appear here."))
                .padding(.top, 40)
        } else {
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(items) { item in
                    RecentCell(item: item, provider: model.recentsThumbnails)
                        .onTapGesture { Task { await model.openRecent(item) } }
                }
            }
            .padding()
        }
    }
}

private struct RecentCell: View {
    let item: RecentItem
    let provider: RecentsThumbnailProvider
    @State private var image: CGImage?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ZStack {
                Color.gray.opacity(0.2)
                if let image {
                    Image(decorative: image, scale: 1).resizable().scaledToFill()
                }
            }
            .aspectRatio(16.0 / 9.0, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            Text(item.name).font(.caption).lineLimit(1)
        }
        .task { image = await provider.thumbnail(for: item) }
    }
}
