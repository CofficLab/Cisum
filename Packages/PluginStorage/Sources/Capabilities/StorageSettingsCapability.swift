import Foundation
import CisumProviderStorage

/// 存储设置页事件：只保留设置页关心的存储语义。
@MainActor
enum StorageSettingsEvent {
    /// 存储位置变更或可用性变化；两者都触发设置页整体刷新。
    case changed
}

/// 存储设置页监听句柄。
@MainActor
protocol StorageSettingsObserverHandle: AnyObject {
    /// 停止接收后续存储变更通知。重复调用无副作用。
    func cancel()
}

/// 存储插件设置页与迁移流程所需的最小存储能力。
///
/// 内核 `StorageProviding` 还包含 `databaseRoot` / `databaseFile(name:)` /
/// `pluginDataDirectory(for:)` / `resetStorageLocation` 等数据库侧能力，本插件
/// 的设置页与迁移流程只消费「读取存储位置 + 切换存储位置 + 订阅变更」，故在此收窄。
///
/// `MigrationProgressView` 迁移完成后需通过本能力提交新的存储位置，因此
/// 保留写入能力 `setStorageLocation(_:)`。
@MainActor
protocol StorageSettingsCapability: AnyObject {
    /// 当前存储位置；尚未配置时为 `nil`。
    var currentStorageLocation: StorageLocation? { get }

    /// 当前存储位置解析出的根 URL；不可用时为 `nil`。
    var storageRoot: URL? { get }

    /// 解析指定存储位置对应的根 URL；不可用时返回 `nil`。
    func storageRoot(for location: StorageLocation) -> URL?

    /// iCloud 是否可用（容器可解析且用户已登录）。
    var isICloudStorageAvailable: Bool { get }

    /// 设置存储位置并持久化（迁移成功后提交新位置时使用）。
    func setStorageLocation(_ location: StorageLocation?)

    /// 订阅存储变更；返回句柄需自行 `cancel()`。
    @discardableResult
    func addObserver(
        _ callback: @escaping (StorageSettingsEvent) -> Void
    ) -> any StorageSettingsObserverHandle
}

/// 将内核 `StorageProviding` 收窄为存储插件的设置页能力。
@MainActor
final class StorageSettingsCapabilityAdapter: StorageSettingsCapability {
    /// 持有内核 Provider 用 `weak`：Provider 可能已被 unregister，
    /// 此时能力应退化为「无存储位置」而非延长其生命周期。
    private weak var storage: (any StorageProviding)?

    init(storage: (any StorageProviding)?) {
        self.storage = storage
    }

    var currentStorageLocation: StorageLocation? { storage?.currentStorageLocation }
    var storageRoot: URL? { storage?.storageRoot }
    var isICloudStorageAvailable: Bool { storage?.isICloudStorageAvailable ?? false }

    func storageRoot(for location: StorageLocation) -> URL? {
        storage?.storageRoot(for: location)
    }

    func setStorageLocation(_ location: StorageLocation?) {
        storage?.setStorageLocation(location)
    }

    @discardableResult
    func addObserver(
        _ callback: @escaping (StorageSettingsEvent) -> Void
    ) -> any StorageSettingsObserverHandle {
        guard let storage else { return StorageSettingsObserverHandleBox(cancelAction: nil) }
        // 内核区分 locationChanged / storageAvailabilityChanged 两种事件，
        // 但设置页对二者响应一致（整体刷新），故在此合并为 .changed。
        let handle = storage.addObserver { _ in callback(.changed) }
        return StorageSettingsObserverHandleBox(cancelAction: handle.cancel)
    }
}

/// 将内核的 `StorageProvidingObserverHandle` 适配为本插件的句柄类型，
/// 避免 Provider 的句柄类型泄漏到能力协议之外。
@MainActor
private final class StorageSettingsObserverHandleBox: StorageSettingsObserverHandle {
    private var cancelAction: (() -> Void)?

    init(cancelAction: (() -> Void)?) {
        self.cancelAction = cancelAction
    }

    func cancel() {
        cancelAction?()
        cancelAction = nil
    }
}