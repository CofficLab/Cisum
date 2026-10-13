import Foundation
import CisumProviderStorage

/// 音频设置关心的存储信号：位置/可用性变化（设置页需刷新仓库状态）。
@MainActor
enum AudioSettingsStorageEvent {
    /// 存储位置 / 可用性发生变化。
    case changed
}

/// 存储监听句柄。
@MainActor
protocol AudioSettingsStorageObserverHandle: AnyObject {
    /// 停止接收后续存储变更通知。重复调用无副作用。
    func cancel()
}

/// 音频设置页所需的最小存储能力。
///
/// 内核 `StorageProviding` 的读写、路径、云盘状态等能力设置页均不消费，
/// 只订阅「位置/可用性变化」这一信号。
@MainActor
protocol AudioSettingsStorageCapability: AnyObject {
    /// 订阅存储位置/可用性变化；返回句柄需自行 `cancel()`。
    @discardableResult
    func addObserver(
        _ callback: @escaping (AudioSettingsStorageEvent) -> Void
    ) -> any AudioSettingsStorageObserverHandle
}

/// 将内核 `StorageProviding` 收窄为音频设置页的存储能力。
@MainActor
final class AudioSettingsStorageCapabilityAdapter: AudioSettingsStorageCapability {
    /// 持有内核 Provider 用 `weak`：Provider 可能已被 unregister，
    /// 此时能力退化为「收不到存储信号」而非延长其生命周期。
    private weak var storage: (any CisumProviderStorage.StorageProviding)?

    init(storage: (any CisumProviderStorage.StorageProviding)?) {
        self.storage = storage
    }

    @discardableResult
    func addObserver(
        _ callback: @escaping (AudioSettingsStorageEvent) -> Void
    ) -> any AudioSettingsStorageObserverHandle {
        guard let storage else { return AudioSettingsStorageHandleBox(cancelAction: nil) }
        let handle = storage.addObserver { _ in callback(.changed) }
        return AudioSettingsStorageHandleBox(cancelAction: handle.cancel)
    }
}

/// 将内核的 `StorageProvidingObserverHandle` 适配为本插件的句柄类型，
/// 避免 Provider 的句柄类型泄漏到能力协议之外。
@MainActor
private final class AudioSettingsStorageHandleBox: AudioSettingsStorageObserverHandle {
    private var cancelAction: (() -> Void)?

    init(cancelAction: (() -> Void)?) {
        self.cancelAction = cancelAction
    }

    func cancel() {
        cancelAction?()
        cancelAction = nil
    }
}