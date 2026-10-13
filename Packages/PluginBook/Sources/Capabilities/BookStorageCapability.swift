import CisumProviderStorage
import Foundation

/// 书籍根容器关心的存储信号：存储位置/可用性变化（需重建数据层）。
@MainActor
enum BookStorageEvent {
    /// 存储位置 / 可用性发生变化。
    case changed
}

/// 存储监听句柄。
@MainActor
protocol BookStorageObserverHandle: AnyObject {
    /// 停止接收后续存储变更通知。重复调用无副作用。
    func cancel()
}

/// 书籍根容器所需的最小存储能力。
///
/// 内核 `StorageProviding` 的根目录、云盘状态、迁移等能力书籍根容器不消费，
/// 只需要「存储位置是否可用」这一位信息（用于初始同步）与位置/可用性变化信号
/// （驱动数据层重建）。
@MainActor
protocol BookStorageCapability: AnyObject {
    /// 存储位置是否已配置且可用。
    var hasUsableStorageLocation: Bool { get }

    /// 订阅存储位置/可用性变化；返回句柄需自行 `cancel()`。
    @discardableResult
    func addObserver(
        _ callback: @escaping (BookStorageEvent) -> Void
    ) -> any BookStorageObserverHandle
}

/// 将内核 `StorageProviding` 收窄为书籍根容器的存储能力。
@MainActor
final class BookStorageCapabilityAdapter: BookStorageCapability {
    /// 持有内核 Provider 用 `weak`：Provider 可能已被 unregister，
    /// 此时能力退化为「无可用存储」而非延长其生命周期。
    private weak var storage: (any CisumProviderStorage.StorageProviding)?

    init(storage: (any CisumProviderStorage.StorageProviding)?) {
        self.storage = storage
    }

    var hasUsableStorageLocation: Bool { storage?.hasUsableStorageLocation ?? false }

    @discardableResult
    func addObserver(
        _ callback: @escaping (BookStorageEvent) -> Void
    ) -> any BookStorageObserverHandle {
        guard let storage else { return BookStorageHandleBox(cancelAction: nil) }
        let handle = storage.addObserver { event in
            switch event {
            case .locationChanged, .storageAvailabilityChanged:
                callback(.changed)
            }
        }
        return BookStorageHandleBox(cancelAction: handle.cancel)
    }
}

/// 将内核的 `StorageProvidingObserverHandle` 适配为本插件的句柄类型，
/// 避免 Provider 的句柄类型泄漏到能力协议之外。
@MainActor
private final class BookStorageHandleBox: BookStorageObserverHandle {
    private var cancelAction: (() -> Void)?

    init(cancelAction: (() -> Void)?) {
        self.cancelAction = cancelAction
    }

    func cancel() {
        cancelAction?()
        cancelAction = nil
    }
}