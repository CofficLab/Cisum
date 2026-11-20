import Foundation
import ProviderVideo

/// 视频库消费的仓库能力。
///
/// 只暴露「列表 / 状态 / 元数据 / 文件操作」这些本场景真正需要的能力，
/// 避免视图层直接依赖 `VideoRepositoryProviding` 的全部方法。
@MainActor
final class VideoLibraryRepositoryCapability {
    private weak var repository: (any VideoRepositoryProviding)?

    init(repository: (any VideoRepositoryProviding)?) {
        self.repository = repository
    }

    var isAvailable: Bool { repository?.isAvailable ?? false }
    var state: VideoRepositoryState { repository?.state ?? .idle }
    var repositoryURL: URL? { repository?.repositoryURL }
    var items: [VideoItem] { repository?.items ?? [] }

    /// 存储位置标题（`iCloud` / `Local`）；未配置时为空。
    var storageLocationTitle: String { repository?.storageLocationTitle ?? "" }
    func refresh() { repository?.refresh() }

    func setTags(_ tags: [String], for url: URL) { repository?.setTags(tags, for: url) }
    func setRating(_ rating: Int?, for url: URL) { repository?.setRating(rating, for: url) }
    func setFavorite(_ isFavorite: Bool, for url: URL) { repository?.setFavorite(isFavorite, for: url) }
    func updateProgress(_ progress: VideoPlaybackProgress, for url: URL) {
        repository?.updateProgress(progress, for: url)
    }

    func rename(_ url: URL, to newName: String) throws {
        try repository?.rename(url, to: newName)
    }

    func delete(_ url: URL) throws {
        try repository?.delete(url)
    }

    func importVideos(from urls: [URL]) throws {
        try repository?.importVideos(from: urls)
    }

    func requestDownload(for url: URL) {
        repository?.requestDownload(for: url)
    }

    @discardableResult
    func addObserver(
        _ callback: @escaping (VideoRepositoryEvent) -> Void
    ) -> any VideoRepositoryObserverHandle {
        repository?.addObserver(callback) ?? NoopVideoRepositoryObserverHandle()
    }
}

/// 仓库观察句柄缺失时的空实现。
final class NoopVideoRepositoryObserverHandle: VideoRepositoryObserverHandle {
    func cancel() {}
}
