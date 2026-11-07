import Foundation
import ProviderAudioLibrary
import ProviderBook

/// 引导关心的仓库信号：仓库内容变化，需要复核一次结论。
@MainActor
enum GuideLibraryEvent {
    /// 仓库状态可能已变化（扫描完成、文件增删、仓库位置变更）。
    case changed
}

/// 仓库监听句柄。
@MainActor
protocol GuideLibraryObserverHandle: AnyObject {
    /// 停止接收后续仓库事件。重复调用无副作用。
    func cancel()
}

/// 引导所需的最小仓库能力。
///
/// 内核 `AudioLibraryProviding` 的读写、排序、分页能力本插件均不消费，
/// 只保留一件事：**仓库是否确认为空**。这个结论由数据层给出——它知道仓库
/// 扫完了没有（没扫过时计数同样是 0，那是「还不知道」而不是「是空的」）。
@MainActor
protocol GuideLibraryCapability: AnyObject {
    /// 音乐仓库是否确认为空。
    var isRepositoryEmpty: Bool { get }

    /// 订阅仓库变化；返回句柄需自行 `cancel()`。
    @discardableResult
    func addObserver(
        _ callback: @escaping (GuideLibraryEvent) -> Void
    ) -> any GuideLibraryObserverHandle
}

/// 将内核 `AudioLibraryProviding` 收窄为引导用的仓库能力。
///
/// 内部持**惰性解析闭包**而非 Provider 快照：数据层插件（注册
/// `AudioLibraryProviding`）与本插件的 boot 顺序不固定，快照会让能力在
/// Provider 稍后就绪时永久失效。每次调用都重新解析 Provider。
@MainActor
final class GuideLibraryCapabilityAdapter: GuideLibraryCapability {
    private let resolve: @MainActor @Sendable () -> (any AudioLibraryProviding)?

    /// Provider 尚未注册时保留的回调，等 Provider 就绪后补订阅。
    private var pendingCallbacks: [(GuideLibraryEvent) -> Void] = []
    private var retryTask: Task<Void, Never>?

    /// 补订阅的最大重试次数；超过后仍会等待 `repositoryAvailabilityChanged` 事件。
    private static let maxRetryCount = 10
    private static let retryInterval: UInt64 = 200_000_000

    init(resolve: @escaping @MainActor @Sendable () -> (any AudioLibraryProviding)?) {
        self.resolve = resolve
    }

    var isRepositoryEmpty: Bool { resolve()?.isRepositoryEmpty ?? false }

    @discardableResult
    func addObserver(
        _ callback: @escaping (GuideLibraryEvent) -> Void
    ) -> any GuideLibraryObserverHandle {
        if let library = resolve() {
            return subscribe(on: library, callback: callback)
        }

        // Provider 尚未注册：保留回调并稍后重试补订阅。
        pendingCallbacks.append(callback)
        scheduleRetry()

        return GuideLibraryObserverHandleBox { [weak self] in
            self?.cancelPending()
        }
    }

    private func subscribe(
        on library: any AudioLibraryProviding,
        callback: @escaping (GuideLibraryEvent) -> Void
    ) -> GuideLibraryObserverHandleBox {
        let handle = library.addObserver { [weak self] event in
            // 任何仓库事件都只意味着「可能变了」——结论由消费方重新读取，
            // 不在这里替数据层解释计数。
            switch event {
            case .syncing, .synced, .updated, .deleted, .repositoryEmpty,
                 .repositoryAvailabilityChanged, .sorting, .sortCompleted:
                callback(.changed)
            }
        }
        return GuideLibraryObserverHandleBox(cancelAction: handle.cancel)
    }

    /// 延迟重试补订阅（Provider 注册可能晚于本插件 boot）。
    private func scheduleRetry() {
        guard retryTask == nil else { return }

        retryTask = Task { @MainActor [weak self] in
            for _ in 0 ..< Self.maxRetryCount {
                try? await Task.sleep(nanoseconds: Self.retryInterval)
                guard let self else { return }
                guard !self.pendingCallbacks.isEmpty else { return }
                if let library = self.resolve() {
                    self.flushPending(using: library)
                    return
                }
            }
        }
    }

    private func flushPending(using library: any AudioLibraryProviding) {
        guard !pendingCallbacks.isEmpty else { return }

        let remaining = pendingCallbacks
        pendingCallbacks.removeAll(keepingCapacity: true)
        for callback in remaining {
            _ = subscribe(on: library, callback: callback)
        }
    }

    private func cancelPending() {
        pendingCallbacks.removeAll()
        retryTask?.cancel()
        retryTask = nil
    }
}

/// 将内核的 `AudioLibraryProvidingObserverHandle` 适配为本插件的句柄类型，
/// 避免 Provider 的句柄类型泄漏到能力协议之外。
@MainActor
private final class GuideLibraryObserverHandleBox: GuideLibraryObserverHandle {
    private var cancelAction: (() -> Void)?

    init(cancelAction: (() -> Void)?) {
        self.cancelAction = cancelAction
    }

    func cancel() {
        cancelAction?()
        cancelAction = nil
    }
}

/// 将内核书籍库收窄为引导用的「仓库是否为空」能力。
///
/// 书籍库只提供异步的 `totalCount()` 与变化事件，没有音乐库那样的三态
/// 「扫描结论」。这里把首次查询与每次变化都折算成缓存结论：
/// - 查询前是「不知道」，按非空处理（引导不出现）；
/// - `libraryChanged(totalCount:)` 直接给出计数，可立即下结论；
/// - 其它事件（同步完成、删除、存储位置变化）触发一次重新查询。
///
/// 与音乐库 Adapter 一样惰性解析 Provider：数据层插件的 boot 顺序不固定。
@MainActor
final class GuideBookLibraryCapabilityAdapter: GuideLibraryCapability {
    private let resolve: @MainActor @Sendable () -> (any BookDatabaseProviding)?

    /// 已得到的结论；`hasConclusion == false` 表示还没查到过。
    private var cachedIsEmpty = false
    private var hasConclusion = false

    private var callback: ((GuideLibraryEvent) -> Void)?
    private var providerHandle: (any BookProvidingObserverHandle)?
    private var refreshTask: Task<Void, Never>?
    private var retryTask: Task<Void, Never>?

    private static let maxRetryCount = 10
    private static let retryInterval: UInt64 = 200_000_000

    init(resolve: @escaping @MainActor @Sendable () -> (any BookDatabaseProviding)?) {
        self.resolve = resolve
    }

    var isRepositoryEmpty: Bool {
        hasConclusion && cachedIsEmpty
    }

    @discardableResult
    func addObserver(
        _ callback: @escaping (GuideLibraryEvent) -> Void
    ) -> any GuideLibraryObserverHandle {
        self.callback = callback
        attachIfPossible()
        return GuideLibraryObserverHandleBox { [weak self] in
            self?.stop()
        }
    }

    /// 已有 Provider 就订阅并查询；没有则稍后重试。
    private func attachIfPossible() {
        guard let library = resolve() else {
            scheduleRetry()
            return
        }

        retryTask?.cancel()
        retryTask = nil

        providerHandle = library.addObserver { [weak self] event in
            switch event {
            case let .libraryChanged(totalCount):
                self?.apply(totalCount: totalCount)
            case .librarySynced, .libraryDeleted, .storageLocationChanged:
                self?.refresh()
            case .librarySyncing, .playbackStateChanged:
                break
            }
        }
        refresh()
    }

    private func refresh() {
        guard let library = resolve() else {
            scheduleRetry()
            return
        }

        refreshTask?.cancel()
        refreshTask = Task { @MainActor [weak self] in
            let count = await library.totalCount()
            guard let self, !Task.isCancelled else { return }
            self.apply(totalCount: count)
        }
    }

    private func apply(totalCount: Int) {
        let isEmpty = totalCount == 0
        let changed = !hasConclusion || cachedIsEmpty != isEmpty
        hasConclusion = true
        cachedIsEmpty = isEmpty

        if changed {
            callback?(.changed)
        }
    }

    private func scheduleRetry() {
        guard retryTask == nil else { return }

        retryTask = Task { @MainActor [weak self] in
            for _ in 0 ..< Self.maxRetryCount {
                try? await Task.sleep(nanoseconds: Self.retryInterval)
                guard let self, self.callback != nil else { return }
                if self.resolve() != nil {
                    self.attachIfPossible()
                    return
                }
            }
        }
    }

    private func stop() {
        callback = nil
        providerHandle?.cancel()
        providerHandle = nil
        refreshTask?.cancel()
        refreshTask = nil
        retryTask?.cancel()
        retryTask = nil
    }
}
