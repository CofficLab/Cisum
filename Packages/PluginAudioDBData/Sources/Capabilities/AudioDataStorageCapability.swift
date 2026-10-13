import CisumProviderStorage
import Foundation

/// 数据层关心的存储信号：位置/可用性变化（需重建音频仓库）。
///
/// 载荷在能力边界被抹平：原 Observer 的所有调用方（插件入口重启同步、
/// `AudioLibraryProvider` 丢弃旧仓库）均忽略 `StorageProvidingEvent`
/// 的具体载荷，只把事件当作「存储变了，请重新解析」的信号。
@MainActor
enum AudioDataStorageEvent {
    /// 存储位置 / 可用性发生变化。
    case changed
}

/// 存储监听句柄。
@MainActor
protocol AudioDataStorageObserverHandle: AnyObject {
    /// 停止接收后续存储变更通知。重复调用无副作用。
    func cancel()
}

/// 音频数据层所需的最小存储能力。
///
/// 数据层只消费存储变更信号；路径读取等能力属于其自身基础设施依赖，
/// 不在本能力范围。
@MainActor
protocol AudioDataStorageCapability: AnyObject {
    /// 订阅存储位置/可用性变化；返回句柄需自行 `cancel()`。
    @discardableResult
    func addObserver(
        _ callback: @escaping (AudioDataStorageEvent) -> Void
    ) -> any AudioDataStorageObserverHandle
}

/// 将内核 `StorageProviding` 收窄为音频数据层的存储能力。
@MainActor
final class AudioDataStorageCapabilityAdapter: AudioDataStorageCapability {
    /// 持有内核 Provider 用 `weak`：Provider 可能已被 unregister，
    /// 此时能力退化为「收不到存储信号」而非延长其生命周期。
    private weak var storage: (any CisumProviderStorage.StorageProviding)?

    init(storage: (any CisumProviderStorage.StorageProviding)?) {
        self.storage = storage
    }

    @discardableResult
    func addObserver(
        _ callback: @escaping (AudioDataStorageEvent) -> Void
    ) -> any AudioDataStorageObserverHandle {
        guard let storage else { return AudioDataStorageHandleBox(cancelAction: nil) }
        let handle = storage.addObserver { event in
            switch event {
            case .locationChanged, .storageAvailabilityChanged:
                callback(.changed)
            }
        }
        return AudioDataStorageHandleBox(cancelAction: handle.cancel)
    }
}

/// 将内核的 `StorageProvidingObserverHandle` 适配为本插件的句柄类型，
/// 避免 Provider 的句柄类型泄漏到能力协议之外。
@MainActor
private final class AudioDataStorageHandleBox: AudioDataStorageObserverHandle {
    private var cancelAction: (() -> Void)?

    init(cancelAction: (() -> Void)?) {
        self.cancelAction = cancelAction
    }

    func cancel() {
        cancelAction?()
        cancelAction = nil
    }
}