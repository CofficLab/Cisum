import CisumProviderStorage
import Foundation

/// 音乐根容器关心的存储信号：位置或可用性变化（需重建容器）。
@MainActor
enum AudioRootStorageEvent {
    /// 存储位置 / 可用性发生变化。
    case changed
}

/// 存储监听句柄。
@MainActor
protocol AudioRootStorageObserverHandle: AnyObject {
    /// 停止接收后续存储变更通知。重复调用无副作用。
    func cancel()
}

/// 音乐根容器所需的最小存储能力。
///
/// 内核 `StorageProviding` 的根目录、云盘状态、迁移等能力根容器不消费，
/// 只需要「存储位置是否可用」这一位信息决定是否展示空态引导，
/// 以及位置/可用性变化信号（驱动重建容器）。
@MainActor
protocol AudioRootStorageCapability: AnyObject {
    /// 存储位置是否已配置且可用。
    var hasUsableStorageLocation: Bool { get }

    /// 订阅存储位置/可用性变化；返回句柄需自行 `cancel()`。
    @discardableResult
    func addObserver(
        _ callback: @escaping (AudioRootStorageEvent) -> Void
    ) -> any AudioRootStorageObserverHandle
}

/// 将内核 `StorageProviding` 收窄为音乐根容器的存储能力。
@MainActor
final class AudioRootStorageCapabilityAdapter: AudioRootStorageCapability {
    /// 持有内核 Provider 用 `weak`：Provider 可能已被 unregister，
    /// 此时能力退化为「无可用存储」而非延长其生命周期。
    private weak var storage: (any CisumProviderStorage.StorageProviding)?

    init(storage: (any CisumProviderStorage.StorageProviding)?) {
        self.storage = storage
    }

    var hasUsableStorageLocation: Bool { storage?.hasUsableStorageLocation ?? false }

    @discardableResult
    func addObserver(
        _ callback: @escaping (AudioRootStorageEvent) -> Void
    ) -> any AudioRootStorageObserverHandle {
        guard let storage else { return AudioRootStorageHandleBox(cancelAction: nil) }
        let handle = storage.addObserver { event in
            switch event {
            case .locationChanged, .storageAvailabilityChanged:
                callback(.changed)
            }
        }
        return AudioRootStorageHandleBox(cancelAction: handle.cancel)
    }
}

/// 将内核的 `StorageProvidingObserverHandle` 适配为本插件的句柄类型，
/// 避免 Provider 的句柄类型泄漏到能力协议之外。
@MainActor
private final class AudioRootStorageHandleBox: AudioRootStorageObserverHandle {
    private var cancelAction: (() -> Void)?

    init(cancelAction: (() -> Void)?) {
        self.cancelAction = cancelAction
    }

    func cancel() {
        cancelAction?()
        cancelAction = nil
    }
}