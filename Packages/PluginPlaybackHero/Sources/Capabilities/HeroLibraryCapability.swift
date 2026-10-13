import Foundation
import ProviderAudioLibrary
import ProviderScene

/// 音乐仓库环境事件：封面区用它决定「是否应该展示封面」。
///
/// 与 `PluginAudioControlButtons` 的做法不同：那里的 Library 只发信号，
/// 可以与 Scene 合并为纯信号能力；而这里封面区需要 `totalCount` **数据**
/// （`synced(0)` 意味着仓库变空、应隐藏封面），因此单独建能力。
@MainActor
enum HeroLibraryEvent {
    /// 仓库为空（应隐藏封面）。
    case becameEmpty
    /// 仓库恢复为非空（应展示封面）。
    case becameNonEmpty
}

/// 音乐仓库监听句柄。
@MainActor
protocol HeroLibraryObserverHandle: AnyObject {
    /// 停止接收后续仓库事件。重复调用无副作用。
    func cancel()
}

/// 封面区所需的最小音乐仓库能力。
///
/// 内核 `AudioLibraryProviding` 的读写、排序、分页能力本插件均不消费，
/// 只保留「仓库是否为空」这一位信息供封面可见性决策使用。
@MainActor
protocol HeroLibraryCapability: AnyObject {
    /// 当前音频库中的项目数量。
    func totalCount() async -> Int

    /// 订阅仓库空/非空变化；返回句柄需自行 `cancel()`。
    @discardableResult
    func addObserver(
        _ callback: @escaping (HeroLibraryEvent) -> Void
    ) -> any HeroLibraryObserverHandle
}

/// 将内核 `AudioLibraryProviding` 收窄为封面区的仓库能力。
@MainActor
final class HeroLibraryCapabilityAdapter: HeroLibraryCapability {
    /// 持有内核 Provider 用 `weak`：Provider 可能已被 unregister，
    /// 此时能力退化为「仓库为空」而非延长其生命周期。
    private weak var library: (any AudioLibraryProviding)?

    init(library: (any AudioLibraryProviding)?) {
        self.library = library
    }

    func totalCount() async -> Int {
        await library?.totalCount() ?? 0
    }

    @discardableResult
    func addObserver(
        _ callback: @escaping (HeroLibraryEvent) -> Void
    ) -> any HeroLibraryObserverHandle {
        guard let library else { return HeroLibraryObserverHandleBox(cancelAction: nil) }
        let handle = library.addObserver { event in
            switch event {
            case .repositoryEmpty:
                callback(.becameEmpty)
            case .synced(let totalCount), .updated(let totalCount), .deleted(_, let totalCount):
                // 只有明确「变为非空」才恢复封面；计数为 0 时不改变可见性，
                // 等待 `repositoryEmpty` 这一权威信号，避免单次不一致的计数
                // 误判仓库状态（保持原有行为：计数 0 时不改变可见性）。
                if totalCount > 0 { callback(.becameNonEmpty) }
            case .syncing, .repositoryAvailabilityChanged, .sorting, .sortCompleted:
                break
            }
        }
        return HeroLibraryObserverHandleBox(cancelAction: handle.cancel)
    }
}

/// 将内核的 `AudioLibraryProvidingObserverHandle` 适配为本插件的句柄类型，
/// 避免 Provider 的句柄类型泄漏到能力协议之外。
@MainActor
private final class HeroLibraryObserverHandleBox: HeroLibraryObserverHandle {
    private var cancelAction: (() -> Void)?

    init(cancelAction: (() -> Void)?) {
        self.cancelAction = cancelAction
    }

    func cancel() {
        cancelAction?()
        cancelAction = nil
    }
}