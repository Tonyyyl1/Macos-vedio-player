import CoreGraphics

/// Maximum height for the track-selection popover so it stays fully visible.
/// Leaves `inset` points of breathing room below the screen height (menu bar,
/// transport controls, popover arrow) and never collapses below `minimum`.
func tracksPopoverMaxHeight(screenHeight: CGFloat, inset: CGFloat = 160,
                            minimum: CGFloat = 200) -> CGFloat {
    max(minimum, screenHeight - inset)
}
