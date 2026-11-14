import Combine
import Foundation
import MagicKit
import CisumProviderStorage
import ProviderStorage

@MainActor
final class StorageSettingsViewModel: ObservableObject, SuperLog {
    nonisolated static let verbose = false

    @Published private(set) var location: StorageLocation?
    @Published private(set) var isICloudAvailable = false
    @Published private(set) var isLocalStorageAvailable = false

    /// 存储能力（Capabilities 目录收窄），`weak` 持有。
    private weak var storage: (any StorageSettingsCapability)?

    init(storage: (any StorageSettingsCapability)? = nil) {
        self.storage = storage
        refresh()
    }

    /// 当前存储位置解析出的根 URL；不可用时为 `nil`。
    var storageRoot: URL? {
        storage?.storageRoot
    }

    /// 解析指定存储位置对应的根 URL；不可用时返回 `nil`。
    func storageRoot(for location: StorageLocation) -> URL? {
        storage?.storageRoot(for: location)
    }

    /// 用户意图：设置存储位置。
    func setStorageLocation(_ location: StorageLocation?) {
        storage?.setStorageLocation(location)
    }

    func handleProviderChanged() {
        refresh()
    }

    /// 绑定存储能力：设置页导航项可能在插件启动前被请求，
    /// 此时能力尚不存在，后续 `installSettingsState` 会再绑定一次。
    func updateStorage(_ storage: (any StorageSettingsCapability)?) {
        self.storage = storage
        refresh()
    }

    /// 迁移流程需要的存储能力；尚未绑定时为 `nil`。
    var resolvedStorage: (any StorageSettingsCapability)? { storage }

    private func refresh() {
        location = storage?.currentStorageLocation
        isICloudAvailable = storage?.isICloudStorageAvailable ?? false
        isLocalStorageAvailable = storage?.storageRoot(for: .local) != nil
    }
}