import Foundation

/// 视频仓库的状态。
public enum VideoRepositoryState: Equatable, Sendable {
    /// 尚未选择存储位置。
    case idle
    /// 正在定位仓库（解析存储根目录）。
    case locating
    /// 正在扫描仓库。
    case scanning(URL)
    /// 仓库可用。
    case ready(URL, Int)
    /// 仓库不可用。
    case unavailable(String)

    /// 是否处于进行中的状态。
    public var isWorking: Bool {
        switch self {
        case .locating, .scanning: true
        case .idle, .ready, .unavailable: false
        }
    }

    /// 状态标题。
    public var title: String {
        switch self {
        case .idle: "No Repository"
        case .locating: "Locating…"
        case .scanning: "Scanning…"
        case .ready: "Ready"
        case .unavailable: "Unavailable"
        }
    }

    /// 状态详情。
    public var detail: String {
        switch self {
        case .idle: "Choose the storage location in Settings to create the video repository"
        case .locating: "Locating the video repository"
        case .scanning(let url): "Scanning \(url.lastPathComponent)"
        case .ready(let url, let count): "\(count) videos in \(url.lastPathComponent)"
        case .unavailable(let reason): reason
        }
    }
}

/// 视频仓库的事件。
@MainActor
public enum VideoRepositoryEvent: Sendable {
    /// 仓库地址发生变化。
    case repositoryChanged(URL?)
    /// 扫描完成。
    case scanCompleted(URL, Int)
    /// 条目列表发生变化（增删改）。
    case itemsChanged([VideoItem])
}

/// 仓库事件的观察句柄。
@MainActor
public protocol VideoRepositoryObserverHandle: AnyObject {
    func cancel()
}

/// 视频仓库能力：跟随存储根目录，扫描、元数据与文件管理。
///
/// 仓库位置不由本能力自行选择：根目录由 `StorageProviding` 决定（用户在
/// 首启引导里选 iCloud 或本地），视频库在其下建自己的子仓库——与音乐
/// （`audios`）、有声书（`audios_book`）同一套逻辑。
@MainActor
public protocol VideoRepositoryProviding: AnyObject {
    /// 当前状态。
    var state: VideoRepositoryState { get }
    /// 当前仓库地址。
    var repositoryURL: URL? { get }
    /// 扫描到的视频条目。
    var items: [VideoItem] { get }
    /// 仓库是否可用。
    var isAvailable: Bool { get }
    /// 存储位置标题（`iCloud` / `Local`）；未配置时为空。
    var storageLocationTitle: String { get }

    /// 重新扫描当前仓库。
    func refresh()
    /// 把某个视频标记为已下载 / 尚未下载（iCloud 场景）。
    func updateAvailability(_ availability: VideoAvailability, for url: URL)

    /// 设置标签。
    func setTags(_ tags: [String], for url: URL)
    /// 设置评分（`nil` 表示清除）。
    func setRating(_ rating: Int?, for url: URL)
    /// 设置收藏状态。
    func setFavorite(_ isFavorite: Bool, for url: URL)
    /// 记录播放进度。
    func updateProgress(_ progress: VideoPlaybackProgress, for url: URL)

    /// 重命名视频文件（保持扩展名）。
    func rename(_ url: URL, to newName: String) throws
    /// 删除视频文件。
    func delete(_ url: URL) throws

    @discardableResult
    func addObserver(_ callback: @escaping (VideoRepositoryEvent) -> Void) -> any VideoRepositoryObserverHandle
}
