import SwiftUI

/// Central brand palette for the player UI. Blue-to-purple matches the app
/// icon's orb and play triangle. Neutral surfaces and text stay white; the
/// accent only lands on active and interactive elements (see CLAUDE.md design).
extension Color {
    /// Periwinkle blue, like the orb's core.
    static let aetherBlue = Color(red: 0.36, green: 0.45, blue: 0.95)
    /// Violet, like the right side of the orb.
    static let aetherPurple = Color(red: 0.60, green: 0.42, blue: 0.95)
}

extension LinearGradient {
    /// Blue to purple, leading to trailing: the direction of the play triangle
    /// in the app icon. Used for the scrubber fill and other accent surfaces.
    static let aetherAccent = LinearGradient(
        colors: [.aetherBlue, .aetherPurple],
        startPoint: .leading, endPoint: .trailing
    )
}

extension View {
    /// Tints an interactive control purple while hovered, white otherwise.
    /// Keeps the hover-tint logic in one place instead of per-button state.
    func aetherHover() -> some View {
        modifier(AetherHoverTint())
    }

    /// Purple-tinted capsule used for the small status badges (backend, rate).
    func aetherBadge() -> some View {
        self
            .foregroundStyle(.white)
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background(Color.aetherPurple.opacity(0.30), in: Capsule())
            .overlay(Capsule().stroke(Color.aetherPurple.opacity(0.45), lineWidth: 1))
    }
}

private struct AetherHoverTint: ViewModifier {
    @State private var hovering = false

    func body(content: Content) -> some View {
        content
            .foregroundStyle(hovering ? AnyShapeStyle(Color.aetherPurple) : AnyShapeStyle(.white))
            .onHover { hovering = $0 }
    }
}
