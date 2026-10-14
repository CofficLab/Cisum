import MagicKit

/// iCloud 下载进度的集中观察者。
///
/// 订阅 `CloudDownloadCapability`，把进度事件转发给 `AudioListViewModel`。
/// 取代 `AudioItemView` 直接依赖 MagicKit `AvatarView` 内部监控的做法——
/// 视图不再自己持有订阅，下载状态成为插件状态源的一部分。
@MainActor
final class CloudDownloadObserver: SuperLog {
    nonisolated static let emoji = "☁️"
    nonisolated static let verbose = false

    private weak var viewModel: AudioListViewModel?
    private var handle: (any CloudDownloadObserverHandle)?

    init(download: any CloudDownloadCapability, viewModel: AudioListViewModel) {
        self.viewModel = viewModel
        handle = download.addObserver { [weak self] event in
            guard case let .progressChanged(url, progress) = event else { return }
            self?.viewModel?.applyDownloadProgress(url: url, progress: progress)
        }
    }

    func cancel() {
        handle?.cancel()
        handle = nil
    }
}