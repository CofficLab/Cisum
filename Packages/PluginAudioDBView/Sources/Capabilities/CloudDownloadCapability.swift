import Foundation
import ProviderCloudDownload

/// 音频库下载事件：只保留列表关心的进度语义。
@MainActor
enum CloudDownloadEvent {
    /// 某文件的下载进度变化；`progress` 范围 `0...1`，`1.0` 表示完成。
    case progressChanged(url: URL, progress: Double)
}

/// 下载进度监听句柄。
@MainActor
protocol CloudDownloadObserverHandle: AnyObject {
    /// 停止接收后续下载进度通知。重复调用无副作用。
    func cancel()
}

/// 音乐库列表所需的最小下载进度能力。
///
/// 内核 `CloudDownloadProviding` 只有订阅与快照两个成员，本插件两条都要：
/// 订阅用于接收进行中的进度，快照用于在建立订阅**之前**为当前页补一次初值。
///
/// 能力**不按 URL 过滤**——Provider 广播所有正在下载的文件，而列表需要用快照
/// 判断某个具体条目是否正在下载，因此快照查询必须透出。
@MainActor
protocol CloudDownloadCapability: AnyObject {
    /// 订阅下载进度变化；返回句柄需自行 `cancel()`。
    @discardableResult
    func addObserver(
        _ callback: @escaping (CloudDownloadEvent) -> Void
    ) -> any CloudDownloadObserverHandle

    /// 读取某文件的当前下载进度（`0...1`）。
    func progress(for url: URL) -> Double
}

/// 将内核 `CloudDownloadProviding` 收窄为音乐库列表的下载进度能力。
///
/// 内部持惰性解析闭包而非 Provider 快照：本插件的视图贡献可能早于 Provider
/// 注册，快照会让能力永久失效。每次调用都重新 `resolveProvider`，
/// Provider 稍后就绪时能力自动生效。
@MainActor
final class CloudDownloadCapabilityAdapter: CloudDownloadCapability {
    private let resolve: @MainActor @Sendable () -> (any CloudDownloadProviding)?

    init(resolve: @escaping @MainActor @Sendable () -> (any CloudDownloadProviding)?) {
        self.resolve = resolve
    }

    /// 当前可用的 Provider；尚未注册时为 `nil`。
    private var download: (any CloudDownloadProviding)? { resolve() }

    @discardableResult
    func addObserver(
        _ callback: @escaping (CloudDownloadEvent) -> Void
    ) -> any CloudDownloadObserverHandle {
        guard let download else { return CloudDownloadObserverHandleBox(cancelAction: nil) }
        let handle = download.addObserver { event in
            guard case let .progressChanged(url, progress) = event else { return }
            callback(.progressChanged(url: url, progress: progress))
        }
        return CloudDownloadObserverHandleBox(cancelAction: handle.cancel)
    }

    func progress(for url: URL) -> Double {
        download?.progress(for: url) ?? 1
    }
}

/// 将内核的 `CloudDownloadProvidingObserverHandle` 适配为本插件的句柄类型，
/// 避免 Provider 的句柄类型泄漏到能力协议之外。
@MainActor
private final class CloudDownloadObserverHandleBox: CloudDownloadObserverHandle {
    private var cancelAction: (() -> Void)?

    init(cancelAction: (() -> Void)?) {
        self.cancelAction = cancelAction
    }

    func cancel() {
        cancelAction?()
        cancelAction = nil
    }
}