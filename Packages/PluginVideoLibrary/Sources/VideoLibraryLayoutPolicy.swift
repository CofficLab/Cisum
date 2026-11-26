import CoreGraphics
import Foundation

/// 视频库的布局形态：按可用宽度决定侧栏与检查器是常驻列还是临时面板。
enum VideoLibraryLayout: Equatable {
    /// 侧栏 + 内容 + 检查器三栏常驻。
    case wide
    /// 侧栏常驻，检查器以面板呈现。
    case medium
    /// 单栏，侧栏与检查器都以面板呈现。
    case compact
}

enum VideoLibraryLayoutPolicy {
    static let wideMinimumWidth: CGFloat = 1080
    static let mediumMinimumWidth: CGFloat = 660
    static let sidebarWidth: CGFloat = 212
    static let inspectorWidth: CGFloat = 296
    /// 网格单元的可选宽度区间。
    static let gridCellWidth = 160.0...260.0

    static func layout(forWidth width: CGFloat) -> VideoLibraryLayout {
        if width >= wideMinimumWidth { return .wide }
        if width >= mediumMinimumWidth { return .medium }
        return .compact
    }

    /// 侧栏是否常驻。
    static func showsSidebar(_ layout: VideoLibraryLayout) -> Bool {
        layout != .compact
    }

    /// 选中条目是否以检查器列呈现（否则为面板）。
    static func showsInspectorColumn(_ layout: VideoLibraryLayout) -> Bool {
        layout == .wide
    }
}

/// 播放时间的统一文案（`h:mm:ss` / `m:ss`）。
enum VideoTimeFormatting {
    static func string(from value: TimeInterval) -> String {
        guard value.isFinite, value > 0 else { return "0:00" }
        let total = Int(value.rounded())
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%d:%02d", minutes, seconds)
    }
}
