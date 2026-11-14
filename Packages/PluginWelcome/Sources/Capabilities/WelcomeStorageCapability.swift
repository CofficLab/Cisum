import CisumProviderStorage
import Foundation

/// 欢迎页关心的存储信号：位置/可用性变化（引导页需重新判断是否展示）。
@MainActor
enum WelcomeStorageEvent {
    /// 存储位置 / 可用性发生变化。
    case changed
}

/// 存储监听句柄。
@MainActor
protocol WelcomeStorageObserverHandle: AnyObject {
    /// 停止接收后续存储变更通知。重复调用无副作用。
    func cancel()
}

/// 欢迎页存储引导所需的最小存储能力。
///
/// 内核 `StorageProviding` 的根目录、云盘状态、迁移等能力欢迎页不消费，
/// 只需要「存储位置是否可用」（决定引导层是否显示）与变化信号。
@MainActor
protocol WelcomeStorageCapability: AnyObject {
    /// 存储位置是否已配置且可用。
    var hasUsableStorageLocation: Bool { get }

    /// 订阅存储位置/可用性变化；返回句柄需自行 `cancel()`。
    @discardableResult
    func addObserver(
        _ callback: @escaping (WelcomeStorageEvent) -> Void
    ) -> any WelcomeStorageObserverHandle
}

/// 将内核 `StorageProviding` 收窄为欢迎页的存储能力。
@MainActor
final class WelcomeStorageCapabilityAdapter: WelcomeStorageCapability {
    /// 持有内核 Provider 用 `weak`：Provider 可能已被 unregister，
    /// 此时能力退化为「无可用存储」而非延长其生命周期。
    private weak var storage: (any CisumProviderStorage.StorageProviding)?

    init(storage: (any CisumProviderStorage.StorageProviding)?) {
        self.storage = storage
    }

    var hasUsableStorageLocation: Bool { storage?.hasUsableStorageLocation ?? false }

    @discardableResult
    func addObserver(
        _ callback: @escaping (WelcomeStorageEvent) -> Void
    ) -> any WelcomeStorageObserverHandle {
        guard let storage else { return WelcomeStorageHandleBox(cancelAction: nil) }
        let handle = storage.addObserver { event in
            switch event {
            case .locationChanged, .storageAvailabilityChanged:
                callback(.changed)
            }
        }
        return WelcomeStorageHandleBox(cancelAction: handle.cancel)
    }
}

/// 将内核的 `StorageProvidingObserverHandle` 适配为本插件的句柄类型，
/// 避免 Provider 的句柄类型泄漏到能力协议之外。
@MainActor
private final class WelcomeStorageHandleBox: WelcomeStorageObserverHandle {
    private var cancelAction: (() -> Void)?

    init(cancelAction: (() -> Void)?) {
        self.cancelAction = cancelAction
    }

    func cancel() {
        cancelAction?()
        cancelAction = nil
    }
}