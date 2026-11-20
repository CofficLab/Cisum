import Foundation

/// 视频库的内容范围。
///
/// 对应原型顶部的筛选胶囊：全部 / 收藏 / 继续观看 / 未下载。
public enum VideoLibraryScope: String, CaseIterable, Sendable {
    /// 全部视频。
    case all
    /// 只看收藏。
    case favorites
    /// 只看有未完成进度的视频。
    case continueWatching
    /// 只看尚未下载到本地的 iCloud 文件。
    case undownloaded

    /// 展示标题。
    public var title: String {
        switch self {
        case .all: "All"
        case .favorites: "Favorites"
        case .continueWatching: "Continue Watching"
        case .undownloaded: "Not Downloaded"
        }
    }

    /// 对应的 SF Symbol 名。
    public var systemImage: String {
        switch self {
        case .all: "square.grid.2x2"
        case .favorites: "star"
        case .continueWatching: "play.circle"
        case .undownloaded: "icloud.and.arrow.down"
        }
    }
}

/// 视频库的排序方式。
public enum VideoSortOrder: String, CaseIterable, Sendable {
    /// 最近添加。
    case recentAdded
    /// 名称。
    case name
    /// 时长。
    case duration
    /// 评分。
    case rating
    /// 最后播放。
    case lastPlayed

    /// 展示标题。
    public var title: String {
        switch self {
        case .recentAdded: "Recently Added"
        case .name: "Name"
        case .duration: "Duration"
        case .rating: "Rating"
        case .lastPlayed: "Last Played"
        }
    }

    /// 对应的 SF Symbol 名。
    public var systemImage: String {
        switch self {
        case .recentAdded: "clock.arrow.circlepath"
        case .name: "textformat.abc"
        case .duration: "timer"
        case .rating: "star"
        case .lastPlayed: "play.square"
        }
    }
}

/// 视频库的展示方式。
public enum VideoLibraryDisplayMode: String, CaseIterable, Sendable {
    /// 海报网格。
    case grid
    /// 列表。
    case list

    /// 展示标题。
    public var title: String {
        switch self {
        case .grid: "Grid"
        case .list: "List"
        }
    }

    /// 对应的 SF Symbol 名。
    public var systemImage: String {
        switch self {
        case .grid: "square.grid.2x2"
        case .list: "list.bullet"
        }
    }
}

public extension VideoItem {
    /// 是否处于「未看完」状态（有进度但没看完）。
    var isInProgress: Bool {
        progress.position > 5 && !progress.isCompleted && progress.fraction < 0.95
    }

    /// 恢复播放的起始位置（秒）；不需要恢复时为 `nil`。
    var resumePosition: TimeInterval? {
        isInProgress ? progress.position : nil
    }
}
