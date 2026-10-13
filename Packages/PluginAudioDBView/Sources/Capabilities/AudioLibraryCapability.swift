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
        guard let library else { return AudioLibraryObserverHandleBox(cancelAction: nil) }
        let handle = library.addObserver { event in
            switch event {
            case .syncing: callback(.syncing)
            case .synced: callback(.synced)
            case .updated: callback(.updated)
            case .deleted(let urls, _): callback(.deleted(urls: urls))
            case .repositoryEmpty: callback(.repositoryEmpty)
            case .repositoryAvailabilityChanged: callback(.repositoryAvailabilityChanged)
            // 内核携带排序模式，但本插件的消费者只把它当作「排序中 / 已完成」信号，
            // 具体模式由 Provider 自行持久化，故在此剥除载荷。
            case .sorting: callback(.sorting)
            case .sortCompleted: callback(.sortCompleted)
            }
        }
        return AudioLibraryObserverHandleBox(cancelAction: handle.cancel)
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