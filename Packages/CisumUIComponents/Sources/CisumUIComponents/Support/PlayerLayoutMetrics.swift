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
    /// Compact player height used while there is no current track to present.
    public static let emptyPlayerControlHeight: CGFloat = 150
    public static let contentMinimumHeight: CGFloat = 200
    public static let albumMinimumHeight: CGFloat = 450
    public static let rightAlbumMinimumWidth: CGFloat = 768
    public static let collapsedWindowThresholdHeight: CGFloat = 270
    public static let controlButtonMinimumSize: CGFloat = 44
    public static let controlButtonMaximumSize: CGFloat = 72
    public static let controlButtonSpacing: CGFloat = 12
    public static let controlButtonBottomPadding: CGFloat = 20

    public static func stateHeight(for height: CGFloat) -> CGFloat {
        if height <= minimumWindowHeight { return 24 }
        if height <= albumMinimumHeight { return 36 }
        return 48
    }

    public static func controlButtonHeight(width: CGFloat, height: CGFloat) -> CGFloat {
        guard width.isFinite, height.isFinite, width > 0, height > 0 else { return 0 }

        let widthLimitedButtonSize = max(
            0,
            (width - controlButtonSpacing * 4) / 5
        )
        let minimumAreaHeight = min(controlButtonMinimumSize, widthLimitedButtonSize)
            + controlButtonBottomPadding
        let responsiveHeight = max(0, min(width / 5, 900, height / 4))

        return max(minimumAreaHeight, responsiveHeight)
    }

    /// Computes the diameter from the same shared constraints used to reserve
    /// the button row, so a compact player cannot shrink its hit targets below
    /// the available width/height.
    public static func controlButtonSize(width: CGFloat, areaHeight: CGFloat) -> CGFloat {
        guard width.isFinite, areaHeight.isFinite, width > 0, areaHeight > 0 else { return 0 }

        let widthLimitedButtonSize = max(
            0,
            (width - controlButtonSpacing * 4) / 5
        )
        let heightLimitedButtonSize = max(0, areaHeight - controlButtonBottomPadding)
        return min(controlButtonMaximumSize, widthLimitedButtonSize, heightLimitedButtonSize)
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
