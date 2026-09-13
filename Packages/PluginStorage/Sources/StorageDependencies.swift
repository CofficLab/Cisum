import Foundation

public struct StorageDependencies: @unchecked Sendable {
    public var getStorageLocation: () -> StoragePluginLocation?
    public var updateStorageLocation: (StoragePluginLocation?) -> Void
    public var getStorageRoot: () -> URL?
    public var getStorageRootForLocation: (StoragePluginLocation) -> URL?
    public var postStorageLocationUpdated: () -> Void
    public var isDesktop: Bool

    public init(
        getStorageLocation: @escaping () -> StoragePluginLocation?,
        updateStorageLocation: @escaping (StoragePluginLocation?) -> Void,
        getStorageRoot: @escaping () -> URL?,
        getStorageRootForLocation: @escaping (StoragePluginLocation) -> URL?,
        postStorageLocationUpdated: @escaping () -> Void,
        isDesktop: Bool
    ) {
        self.getStorageLocation = getStorageLocation
        self.updateStorageLocation = updateStorageLocation
        self.getStorageRoot = getStorageRoot
        self.getStorageRootForLocation = getStorageRootForLocation
        self.postStorageLocationUpdated = postStorageLocationUpdated
        self.isDesktop = isDesktop
    }

    static let preview = StorageDependencies(
        getStorageLocation: { .local },
        updateStorageLocation: { _ in },
        getStorageRoot: { FileManager.default.temporaryDirectory },
        getStorageRootForLocation: { _ in FileManager.default.temporaryDirectory },
        postStorageLocationUpdated: {},
        isDesktop: true
    )
}
