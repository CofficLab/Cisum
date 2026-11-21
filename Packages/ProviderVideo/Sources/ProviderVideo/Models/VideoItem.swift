import Foundation

/// 仓库中的一个视频条目。
public struct VideoItem: Identifiable, Hashable, Sendable {
    /// 文件的绝对地址。
    public let url: URL
    /// 相对仓库根目录的路径（用于展示与稳定标识）。
    public let relativePath: String
    /// 展示标题（文件名，不含扩展名）。
    public let title: String
    /// 文件大小（字节）。
    public let size: Int64
    /// 文件最后修改时间。
    public let modifiedAt: Date?
    /// 媒体时长（秒）；无法读取时为 `nil`。
    public let duration: TimeInterval?
    /// 用户标签。
    public let tags: [String]
    /// 评分。
    public let rating: VideoRating?
    /// 播放进度。
    public let progress: VideoPlaybackProgress
    /// 是否收藏。
    public let isFavorite: Bool
    /// 可播放状态。
    public let availability: VideoAvailability

    public var id: URL { url }

    public init(
        url: URL,
        relativePath: String,
        title: String,
        size: Int64,
        modifiedAt: Date?,
        duration: TimeInterval?,
        tags: [String] = [],
        rating: VideoRating? = nil,
        progress: VideoPlaybackProgress = .empty,
        isFavorite: Bool = false,
        availability: VideoAvailability = .available
    ) {
        self.url = url
        self.relativePath = relativePath
        self.title = title
        self.size = size
        self.modifiedAt = modifiedAt
        self.duration = duration
        self.tags = tags
        self.rating = rating
        self.progress = progress
        self.isFavorite = isFavorite
        self.availability = availability
    }

    /// 文件扩展名（大写）。
    public var fileExtension: String {
        url.pathExtension.uppercased()
    }

    /// 可读的时长文案（`h:mm:ss` / `m:ss`）。
    public var formattedDuration: String {
        guard let duration, duration > 0 else { return "--:--" }
        let total = Int(duration.rounded())
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%d:%02d", minutes, seconds)
    }

    /// 可读的文件大小文案。
    public var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }

    /// 列表副标题：大小 · 时长 · 修改时间。
    public var subtitle: String {
        var parts: [String] = [formattedSize]
        if let duration, duration > 0 {
            parts.append(formattedDuration)
        }
        if !tags.isEmpty {
            parts.append(tags.prefix(3).joined(separator: " · "))
        }
        return parts.joined(separator: " · ")
    }
}
