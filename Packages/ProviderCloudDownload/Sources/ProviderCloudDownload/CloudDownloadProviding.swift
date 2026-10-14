import Foundation
import KitEventObservation

/// iCloud 文件下载进度事件。
///
/// 只描述「某个文件下载到了多少」，不携带触发原因：进度可能来自系统自发的
/// 后台下载，也可能来自用户点击播放后引擎发起的下载，消费方无需区分。
public enum CloudDownloadEvent: Sendable {
    /// 进度变化；`progress` 范围 `0...1`，`1.0` 表示下载完成。
    case progressChanged(url: URL, progress: Double)
}

/// 下载进度监听句柄。
@MainActor
public protocol CloudDownloadProvidingObserverHandle: AnyObject {
    /// 停止接收后续进度通知。重复调用无副作用。
    func cancel()
}

/// iCloud 文件下载进度能力协议。
///
/// 广播模型：Provider 全局广播**所有**正在下载文件的进度，**不接受订阅者的
/// URL 注册**。这样分页加载、列表滚动、条目删除都不需要向 Provider 声明兴趣集合。
///
/// 之所以能这样做，是因为底层 `NSMetadataQuery` 的 predicate 是
/// `IsDownloadingKey == YES`——系统只返回**正在下载**的文件，数据量天然极小。
///
/// ## 事件与快照的关系
/// - **事件是真值**：生产环境对 dataless 占位文件用资源键快照长期读到 `0`，
///   只有 `NSMetadataQuery` 推送的百分比才反映真实进度。
/// - **快照只用于初始化**：`progress(for:)` 返回当前进度的即时读数，供调用方
///   在建立订阅**之前**先填充一次。它不是事件流的替代品，也不保证精确。
@MainActor
public protocol CloudDownloadProviding: AnyObject, Sendable {
    /// 订阅下载进度变化；返回句柄需自行 `cancel()`。
    @discardableResult
    func addObserver(
        _ callback: @escaping (CloudDownloadEvent) -> Void
    ) -> any CloudDownloadProvidingObserverHandle

    /// 读取某 URL 的当前下载进度（`0...1`）。
    ///
    /// 已下载 / 非 iCloud 文件返回 `1.0`；正在下载返回系统百分比的实时读数；
    /// 无法判定时返回 `0`。用于调用方在订阅前初始化自身状态。
    func progress(for url: URL) -> Double
}

public extension CloudDownloadProviding {
    /// 默认实现提供空订阅句柄，使「只有生产者、没有消费者」的 Provider 无需
    /// 自行实现订阅面。
    @discardableResult
    func addObserver(
        _ callback: @escaping (CloudDownloadEvent) -> Void
    ) -> any CloudDownloadProvidingObserverHandle {
        NoopCloudDownloadProvidingObserverHandle()
    }
}

/// 不转发任何事件的空句柄；`cancel()` 可重复调用。
@MainActor
public final class NoopCloudDownloadProvidingObserverHandle: CloudDownloadProvidingObserverHandle {
    public init() {}

    public func cancel() {}
}

extension EventObserverHandle: CloudDownloadProvidingObserverHandle {}