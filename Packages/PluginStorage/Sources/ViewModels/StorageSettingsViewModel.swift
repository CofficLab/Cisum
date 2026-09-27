import Combine
import Foundation
import MagicKit
import ProviderStorage

@MainActor
final class StorageSettingsViewModel: ObservableObject, SuperLog {
    nonisolated static let verbose = false

    @Published private(set) var location: StorageLocation?
    @Published private(set) var isICloudAvailable = false
    @Published private(set) var isLocalStorageAvailable = false

    private weak var storageProvider: (any StorageProviding)?

    init(storageProvider: (any StorageProviding)?) {
        self.storageProvider = storageProvider
        refresh()
    }

    /// 当前存储位置解析出的根 URL；不可用时为 `nil`。
    var storageRoot: URL? {
        storageProvider?.storageRoot
    }

    /// 解析指定存储位置对应的根 URL；不可用时返回 `nil`。
    func storageRoot(for location: StorageLocation) -> URL? {
        storageProvider?.storageRoot(for: location)
    }

    /// 用户意图：设置存储位置。
    func setStorageLocation(_ location: StorageLocation?) {
        storageProvider?.setStorageLocation(location)
    }

    func handleProviderChanged() {
        refresh()
    }

    func updateStorageProvider(_ provider: (any StorageProviding)?) {
        storageProvider = provider
        refresh()
    }

    var resolvedStorageProvider: (any StorageProviding)? { storageProvider }

    private func refresh() {
        location = storageProvider?.currentStorageLocation
        isICloudAvailable = storageProvider?.isICloudStorageAvailable ?? false
        isLocalStorageAvailable = storageProvider?.storageRoot(for: .local) != nil
    }
}
