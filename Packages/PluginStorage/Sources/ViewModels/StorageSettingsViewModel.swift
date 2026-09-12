import Combine
import Foundation
import MagicKit

@MainActor
final class StorageSettingsViewModel: ObservableObject, SuperLog {
    nonisolated static let verbose = false

    @Published private(set) var location: StoragePluginLocation?
    @Published private(set) var isICloudAvailable = false
    @Published private(set) var isLocalStorageAvailable = false

    private var capability: (any StorageSettingsCapability)?

    init(capability: (any StorageSettingsCapability)?) {
        self.capability = capability
        refresh()
    }

    /// 当前存储位置解析出的根 URL；不可用时为 `nil`。
    var storageRoot: URL? {
        capability?.storageRoot
    }

    /// 解析指定存储位置对应的根 URL；不可用时返回 `nil`。
    func storageRoot(for location: StoragePluginLocation) -> URL? {
        capability?.storageRoot(for: location)
    }

    /// 用户意图：设置存储位置。
    func setStorageLocation(_ location: StoragePluginLocation?) {
        capability?.setStorageLocation(location)
    }

    func handleProviderChanged() {
        refresh()
    }

    func updateCapability(_ capability: (any StorageSettingsCapability)?) {
        self.capability = capability
        refresh()
    }

    private func refresh() {
        location = capability?.currentLocation
        isICloudAvailable = capability?.isICloudAvailable ?? false
        isLocalStorageAvailable = capability?.isLocalStorageAvailable ?? false
    }
}
