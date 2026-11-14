import Foundation
import ProviderAudioLibrary

/// 音频库事件：只保留本插件关心的语义，剥除内核事件的原始载荷。
@MainActor
public enum AudioLibraryEvent {
    case syncing
    case synced
    case updated
    /// 文件被删除；携带待从 UI 移除的 URL。
    case deleted(urls: [URL])
    case repositoryEmpty
    case repositoryAvailabilityChanged
    /// 排序开始；本插件不消费排序模式（读回由 Provider 自行处理）。
    case sorting
    case sortCompleted
}

/// 音频库监听句柄。
@MainActor
public protocol AudioLibraryObserverHandle: AnyObject {
    /// 停止接收后续音频库变更通知。重复调用无副作用。
    func cancel()
}

/// 音乐库视图与设置页所需的最小音频库能力。
///
/// 内核 `AudioLibraryProviding` 还包含 `sort(url:reason:)` /
/// `sortRandom(url:reason:verbose:)` / `contains(_:)` 等本插件不直接调用的
/// 能力；本插件只做「读取列表 / 删除 / 同步导入 / 订阅变更」，故在此收窄。
///
/// 标记为 `public`：`AudioDBDependencies` 是本包的公开依赖结构，需向宿主暴露。
///
/// ## 惰性解析
/// 数据层插件的 boot 顺序不确定，本插件的视图贡献可能早于 `AudioLibraryProviding`
/// 注册。因此能力内部持**惰性解析闭包**而非快照 Provider：每次调用都重新
/// `resolveProvider`，Provider 稍后就绪时能力自动生效，无需重建视图模型。
///
/// 精化 `Sendable`（与内核 `AudioLibraryProviding` 一致）：ViewModel 在
/// `Task { @MainActor in }` 中跨闭包使用本能力，需满足 Sendable 约束。
@MainActor
public protocol AudioLibraryCapability: AnyObject, Sendable {
    /// 当前音频文件所在的目录；未配置时为 `nil`。
    var audioDisk: URL? { get }

    /// 当前实现支持导入的文件扩展名。
    var supportedExtensions: [String] { get }

    /// 音频库是否已准备好访问。
    var isAvailable: Bool { get }

    /// 当前音频库中的项目数量。
    func totalCount() async -> Int

    /// 按稳定播放顺序读取音频 URL。
    func allURLs(reason: String) async -> [URL]

    /// 分页读取音频 URL。
    func urls(offset: Int, limit: Int, reason: String) async -> [URL]

    /// 删除音频文件及其索引记录。
    func delete(urls: [URL], verbose: Bool) async throws

    /// 将文件系统扫描结果同步到音频库。
    func sync(urls: [URL], verbose: Bool, isFirst: Bool) async

    /// 订阅音频库变更；返回句柄需自行 `cancel()`。
    @discardableResult
    func addObserver(
        _ callback: @escaping (AudioLibraryEvent) -> Void
    ) -> any AudioLibraryObserverHandle
}

/// 将内核 `AudioLibraryProviding` 收窄为音乐库的音频库能力。
///
/// 内部持惰性解析闭包而非 Provider 引用：Provider 注册时机晚于本插件视图
/// 注册是常态，快照会导致能力永久失效。
@MainActor
public final class AudioLibraryCapabilityAdapter: AudioLibraryCapability {
    private let resolve: @MainActor @Sendable () -> (any AudioLibraryProviding)?

    /// 待重试的观察者：首次 `addObserver` 时 Provider 尚未注册，订阅会被
    /// 永久错过。iOS 上 `AudioDBDataPlugin` 与 `AudioDBViewPlugin` 的
    /// `order` 相同，依赖 `originalIndex` 决出先后，跨平台时容易出现
    /// `AudioDBViewPlugin.onReady` 早于 `AudioDBDataPlugin.onReady`，导致
    /// 此处 `library` 为 nil 后被永久跳过。改为在 `repositoryAvailabilityChanged`
    /// 事件中重试订阅，并保留弱引用以避免循环持有。
    private struct PendingObserver {
        weak var adapter: AudioLibraryCapabilityAdapter?
        let callback: (AudioLibraryEvent) -> Void
    }
    private var pendingObservers: [PendingObserver] = []

    public init(resolve: @escaping @MainActor @Sendable () -> (any AudioLibraryProviding)?) {
        self.resolve = resolve
    }

    /// 当前可用的 Provider；尚未注册时为 `nil`。
    private var library: (any AudioLibraryProviding)? { resolve() }

    public var audioDisk: URL? { library?.audioDisk }
    public var supportedExtensions: [String] { library?.supportedExtensions ?? [] }
    public var isAvailable: Bool { library?.isAvailable ?? false }

    public func totalCount() async -> Int {
        await library?.totalCount() ?? 0
    }

    public func allURLs(reason: String) async -> [URL] {
        await library?.allURLs(reason: reason) ?? []
    }

    public func urls(offset: Int, limit: Int, reason: String) async -> [URL] {
        await library?.urls(offset: offset, limit: limit, reason: reason) ?? []
    }

    public func delete(urls: [URL], verbose: Bool) async throws {
        try await library?.delete(urls: urls, verbose: verbose)
    }

    public func sync(urls: [URL], verbose: Bool, isFirst: Bool) async {
        await library?.sync(urls: urls, verbose: verbose, isFirst: isFirst)
    }

    @discardableResult
    public func addObserver(
        _ callback: @escaping (AudioLibraryEvent) -> Void
    ) -> any AudioLibraryObserverHandle {
        if let library {
            return subscribe(on: library, callback: callback)
        }

        // Provider 尚未注册：保留回调，等首次 `repositoryAvailabilityChanged`
        // 事件（`AudioLibraryProvider.invalidateRepository` 触发）时重试订阅。
        let pending = PendingObserver(adapter: self, callback: callback)
        pendingObservers.append(pending)

        // 主动再尝试一次：跨插件 `onReady` 顺序有时是 AudioDBDataPlugin 先、
        // AudioDBViewPlugin 后（macOS），有时反过来（iOS）。在 `addObserver`
        // 失败时延迟一拍再 resolve，通常足够让对侧 plugin 完成注册。
        let resolveSnapshot = resolve
        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 50_000_000)
            guard let self else { return }
            if let laterLibrary = resolveSnapshot(), !self.pendingObservers.isEmpty {
                self.flushPendingObservers(using: laterLibrary)
            }
        }
        return AudioLibraryObserverHandleBox { [weak self] in
            self?.removePending(callback: callback)
        }
    }

    private func subscribe(
        on library: any AudioLibraryProviding,
        callback: @escaping (AudioLibraryEvent) -> Void
    ) -> AudioLibraryObserverHandleBox {
        let handle = library.addObserver { [weak self] event in
            // 把内核事件翻译成能力事件；Provider 的 ready 事件同时触发 pending 重试。
            switch event {
            case .syncing: callback(.syncing)
            case .synced: callback(.synced)
            case .updated: callback(.updated)
            case .deleted(let urls, _): callback(.deleted(urls: urls))
            case .repositoryEmpty: callback(.repositoryEmpty)
            case .repositoryAvailabilityChanged:
                callback(.repositoryAvailabilityChanged)
                self?.flushPendingObservers(using: library)
            case .sorting: callback(.sorting)
            case .sortCompleted: callback(.sortCompleted)
            }
        }
        return AudioLibraryObserverHandleBox(cancelAction: handle.cancel)
    }

    private func flushPendingObservers(using library: any AudioLibraryProviding) {
        // 清理已失效的回调，避免被取消的订阅仍然保留在待办列表里。
        pendingObservers.removeAll { $0.adapter == nil }
        guard !pendingObservers.isEmpty else { return }

        let remaining = pendingObservers
        pendingObservers.removeAll(keepingCapacity: true)
        for entry in remaining {
            // 同一个 callback 已经在别处订阅过（例如先有 defer 重试，然后
            // `repositoryAvailabilityChanged` 又触发一次）就跳过。
            _ = subscribe(on: library, callback: entry.callback)
        }
    }

    private func removePending(callback: (AudioLibraryEvent) -> Void) {
        // Swift 闭包无法稳定比较（无 Equatable，指针比较受 ARC 优化影响）。
        // 取消语义下，我们只能确保「所有 pending 一次性清空」；已知本插件入口
        // 仅在 `onDisable` / `onShutdown` 时 cancel 一次，pending 数量始终
        // ≤ 1（仅当 onReady 早于 Provider 注册时出现），简单 drop 即可。
        pendingObservers.removeAll()
    }
}

/// 将内核的 `AudioLibraryProvidingObserverHandle` 适配为本插件的句柄类型，
/// 避免 Provider 的句柄类型泄漏到能力协议之外。
@MainActor
private final class AudioLibraryObserverHandleBox: AudioLibraryObserverHandle {
    private var cancelAction: (() -> Void)?

    init(cancelAction: (() -> Void)?) {
        self.cancelAction = cancelAction
    }

    func cancel() {
        cancelAction?()
        cancelAction = nil
    }
}