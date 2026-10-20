import Foundation
import ProviderAudioLibrary

/// 引导关心的仓库事件：只保留「仓库空 / 需要复核」这一位语义。
@MainActor
enum GuideLibraryEvent {
    /// 仓库为空（权威信号）。
    case repositoryEmpty
    /// 仓库事件发生，需要复核计数。
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
/// 只保留三件事：仓库目录与支持格式（导入用）、可用性与计数（判断空仓库用）、
/// 以及把复制进来的文件并入索引。
@MainActor
protocol GuideLibraryCapability: AnyObject {
    /// 当前音频文件所在的目录；未配置时为 `nil`。
    var audioDisk: URL? { get }

    /// 当前实现支持导入的文件扩展名。
    var supportedExtensions: [String] { get }

    /// 音频库是否已准备好访问。
    var isAvailable: Bool { get }

    /// 当前音频库中的项目数量。
    func totalCount() async -> Int

    /// 将文件系统扫描结果同步到音频库。
    func sync(urls: [URL]) async

    /// 订阅仓库变更；返回句柄需自行 `cancel()`。
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

    var audioDisk: URL? { resolve()?.audioDisk }
    var supportedExtensions: [String] { resolve()?.supportedExtensions ?? [] }
    var isAvailable: Bool { resolve()?.isAvailable ?? false }

    func totalCount() async -> Int {
        await resolve()?.totalCount() ?? 0
    }

    func sync(urls: [URL]) async {
        await resolve()?.sync(urls: urls, verbose: false, isFirst: false)
    }

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
            switch event {
            case .repositoryEmpty:
                // 权威信号：仓库确认为空。
                callback(.repositoryEmpty)
            case .synced, .updated, .deleted:
                // 其余事件只作为「需要复核计数」的信号。
                callback(.changed)
            case .repositoryAvailabilityChanged:
                // Provider 重新就绪：把之前没订阅上的回调补上。
                self?.flushPending(using: library)
            case .syncing, .sorting, .sortCompleted:
                break
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
