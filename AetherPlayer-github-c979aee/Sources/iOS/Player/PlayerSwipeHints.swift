import SwiftUI

/// Subtle edge affordances shown with the controls: a vertical swipe on the left edge adjusts
/// brightness, on the right edge volume. Visual only, the gesture catcher underneath does the work.
struct PlayerSwipeHints: View {
    var body: some View {
        HStack {
            hint(icon: "sun.max.fill")
            Spacer()
            hint(icon: "speaker.wave.2.fill")
        }
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .allowsHitTesting(false)
    }

    private func hint(icon: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: "chevron.up").font(.caption2.weight(.semibold))
            Image(systemName: icon).font(.subheadline)
            Image(systemName: "chevron.down").font(.caption2.weight(.semibold))
        }
        .foregroundStyle(.white.opacity(0.5))
        .padding(.vertical, 9)
        .padding(.horizontal, 7)
        .background(
            Capsule()
                .fill(.ultraThinMaterial)
                .environment(\.colorScheme, .dark)
                .opacity(0.55)
        )
    }
}
