import ProviderStorage
import Foundation
import MagicKit

/// 存储设置页面需要的最小存储能力。
///
/// ViewModel 不直接依赖 Kernel 或 `StorageProviding`；Provider 由插件入口
/// 在组装阶段适配成这条能力边界。
@MainActor
protocol StorageSettingsCapability: AnyObject {
    var currentLocation: StoragePluginLocation? { get }
    var storageRoot: URL? { get }
    var isICloudAvailable: Bool { get }
    var isLocalStorageAvailable: Bool { get }

    func storageRoot(for location: StoragePluginLocation) -> URL?
    func setStorageLocation(_ location: StoragePluginLocation?)
}

/// 将内核存储 Provider 收窄成设置页面所需的能力。
@MainActor
final class StorageSettingsCapabilityAdapter: StorageSettingsCapability, SuperLog {
    nonisolated static let verbose = false

    private weak var storage: (any StorageProviding)?

    init(storage: any StorageProviding) {
        self.storage = storage
    }

    var currentLocation: StoragePluginLocation? {
        storage?.currentStorageLocation.map(StoragePluginLocation.init)
    }

    var storageRoot: URL? { storage?.storageRoot }

    var isICloudAvailable: Bool {
        storage?.storageRoot(for: .icloud) != nil
    }

    var isLocalStorageAvailable: Bool {
        storage?.storageRoot(for: .local) != nil
    }

    func storageRoot(for location: StoragePluginLocation) -> URL? {
        storage?.storageRoot(for: StorageLocation(location))
    }

    func setStorageLocation(_ location: StoragePluginLocation?) {
        storage?.setStorageLocation(location.map(StorageLocation.init))
    }
}