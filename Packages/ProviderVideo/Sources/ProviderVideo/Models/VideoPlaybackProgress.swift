import Foundation

/// 视频文件的播放进度。
public struct VideoPlaybackProgress: Codable, Equatable, Hashable, Sendable {
    /// 上次播放到的位置（秒）。
    public var position: TimeInterval
    /// 媒体总时长（秒）。
    public var duration: TimeInterval
    /// 已播放次数。
    public var playCount: Int
    /// 最后一次播放时间。
    public var lastPlayedAt: Date?
    /// 看完的时间点。
    public var completedAt: Date?

    public init(
        position: TimeInterval = 0,
        duration: TimeInterval = 0,
        playCount: Int = 0,
        lastPlayedAt: Date? = nil,
        completedAt: Date? = nil
    ) {
        self.position = max(position, 0)
        self.duration = max(duration, 0)
        self.playCount = max(playCount, 0)
        self.lastPlayedAt = lastPlayedAt
        self.completedAt = completedAt
    }

    /// 空进度（尚未播放过）。
    public static let empty = VideoPlaybackProgress()

    /// 已播放比例（0...1）。
    public var fraction: Double {
        guard duration > 0 else { return 0 }
        return min(max(position / duration, 0), 1)
    }

    /// 是否已看完。
    public var isCompleted: Bool { completedAt != nil }

    /// 列表上的状态短文案。
    public var statusTitle: String {
        if isCompleted { return "Watched" }
        if position > 5 { return "\(Int(fraction * 100))%" }
        return ""
    }
}

/// 视频文件当前的可播放状态。
public enum VideoAvailability: Codable, Equatable, Hashable, Sendable {
    /// 本地可直接播放。
    case available
    /// 位于 iCloud，尚未下载到本地。
    case cloudNotDownloaded
    /// 正在从 iCloud 下载。
    case cloudDownloading
    /// 不可播放（文件缺失或读取失败）。
    case unavailable(String)

    /// 是否可以播放。
    public var isPlayable: Bool {
        switch self {
        case .available, .cloudNotDownloaded, .cloudDownloading: true
        case .unavailable: false
        }
    }

    /// 状态标题。
    public var title: String {
        switch self {
        case .available: "Available"
        case .cloudNotDownloaded: "In iCloud"
        case .cloudDownloading: "Downloading"
        case .unavailable: "Unavailable"
        }
    }

    /// 状态详情。
    public var detail: String {
        switch self {
        case .available: ""
        case .cloudNotDownloaded: "Tap to download from iCloud"
        case .cloudDownloading: "Downloading from iCloud"
        case .unavailable(let reason): reason
        }
    }

    /// 对应的 SF Symbol 名。
    public var systemImage: String {
        switch self {
        case .available: "checkmark.circle"
        case .cloudNotDownloaded: "icloud.and.arrow.down"
        case .cloudDownloading: "arrow.down.circle"
        case .unavailable: "exclamationmark.triangle"
        }
    }
}

/// 视频条目的评分（1...5 星）。
public struct VideoRating: Codable, Equatable, Hashable, Sendable {
    /// 允许的评分区间。
    public static let allowedValues = 1...5

    /// 星级值。
    public let value: Int

    /// 仅接受 1...5 的星级。
    public init?(_ value: Int) {
        guard Self.allowedValues.contains(value) else { return nil }
        self.value = value
    }

    /// 展示标题。
    public var title: String {
        value == 1 ? "1 star" : "\(value) stars"
    }

    /// 符号文案。
    public var symbolText: String {
        String(repeating: "★", count: value)
    }
}
