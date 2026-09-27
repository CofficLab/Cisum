import CoreGraphics

/// Shared responsive metrics for the player window.
///
/// These values are the layout contract that the legacy 3.10 player used:
/// the compact control area is 250pt high, the content area needs 200pt, and
/// the second album column appears once the window is wider than an iPad mini.
public enum CisumPlayerLayout {
    /// Keeps the two-column library layout usable: two 150pt tiles, their
    /// 12pt gap, content padding, and the scroll bar still fit comfortably.
    public static let minimumWindowWidth: CGFloat = 400
    public static let minimumWindowHeight: CGFloat = 250
    public static let defaultWindowSize = CGSize(width: minimumWindowWidth, height: 360)

    public static let controlMinimumHeight: CGFloat = 250
    public static let contentMinimumHeight: CGFloat = 200
    public static let albumMinimumHeight: CGFloat = 450
    public static let rightAlbumMinimumWidth: CGFloat = 768
    public static let collapsedWindowThresholdHeight: CGFloat = 270

    public static func stateHeight(for height: CGFloat) -> CGFloat {
        if height <= minimumWindowHeight { return 24 }
        if height <= albumMinimumHeight { return 36 }
        return 48
    }

    public static func controlButtonHeight(width: CGFloat, height: CGFloat) -> CGFloat {
        max(0, min(width / 5, 900, height / 4))
    }

    public static func shouldShowRightAlbum(width: CGFloat) -> Bool {
        width > rightAlbumMinimumWidth
    }

    /// Centers content in the visible window when a platform container offers
    /// a wider layout proposal than the window's actual content area.
    public static func horizontalCenteringOffset(proposedWidth: CGFloat, visibleWidth: CGFloat) -> CGFloat {
        guard proposedWidth.isFinite, visibleWidth.isFinite else { return 0 }
        return max(0, (proposedWidth - max(0, visibleWidth)) / 2)
    }

    public static func needsExpandedWindow(for height: CGFloat) -> Bool {
        height - controlMinimumHeight <= contentMinimumHeight
    }
}
