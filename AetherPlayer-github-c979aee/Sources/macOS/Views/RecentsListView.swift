import SwiftUI

struct RecentsListView: View {
    let items: [RecentItem]
    let thumbnails: RecentsThumbnailProvider
    let onOpen: (RecentItem) -> Void
    let onRemove: (RecentItem) -> Void
    let onClearAll: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Recent").font(.headline).foregroundStyle(.white.opacity(0.8))
                Spacer()
                Button("Clear All", action: onClearAll)
                    .buttonStyle(.borderless)
                    .foregroundStyle(.white.opacity(0.5))
            }
            ScrollView {
                VStack(spacing: 4) {
                    ForEach(items) { item in
                        RecentRow(item: item, thumbnails: thumbnails,
                                  onOpen: { onOpen(item) }, onRemove: { onRemove(item) })
                    }
                }
            }
            // Hug the content for a few entries, then cap and scroll, so the box
            // does not balloon into empty space with only one or two recents.
            .frame(height: min(CGFloat(items.count) * 56, 280))
        }
        .frame(maxWidth: 460)
        .fixedSize(horizontal: false, vertical: true)
        .padding(16)
        .background(.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 12))
    }
}

private struct RecentRow: View {
    let item: RecentItem
    let thumbnails: RecentsThumbnailProvider
    let onOpen: () -> Void
    let onRemove: () -> Void
    @State private var hovering = false
    @State private var thumbnail: CGImage?

    var body: some View {
        Button(action: onOpen) {
            HStack(spacing: 10) {
                thumbView
                    .frame(width: 72, height: 40)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.name).foregroundStyle(.white).lineLimit(1)
                    ProgressView(value: item.progress)
                        .frame(height: 2)
                        .tint(.aetherPurple)
                }
                Spacer()
                if hovering {
                    Button(action: onRemove) {
                        Image(systemName: "xmark.circle.fill")
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.white.opacity(0.5))
                }
            }
            .padding(.horizontal, 10).padding(.vertical, 8)
            .background(.white.opacity(hovering ? 0.08 : 0), in: RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .task(id: item.id) {
            thumbnail = await thumbnails.thumbnail(for: item)
        }
    }

    @ViewBuilder private var thumbView: some View {
        if let thumbnail {
            Image(decorative: thumbnail, scale: 1, orientation: .up)
                .resizable()
                .aspectRatio(contentMode: .fill)
        } else {
            ZStack {
                Color.white.opacity(0.08)
                Image(systemName: "film").foregroundStyle(.white.opacity(0.3))
            }
        }
    }
}
