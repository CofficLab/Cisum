import CisumProviderStorage
import KernelCore
import ProviderPlugin
import Foundation
import KitEventObservation
import MagicKit
import ProviderStorage

private typealias CisumStorageProvidingEvent = CisumProviderStorage.StorageProvidingEvent

/// `StorageProviding` 的具体实现。
///
/// 目录结构（对齐 Lumi/GitOK `DefaultStorageProvider`）：
/// - 数据根目录：`~/Library/Application Support/<bundleID>/db_<debug|production>_v<majorVersion>/`
/// - 插件数据目录：`<root>/<pluginID>/`（无 `Plugins/` 中间层）
/// - 数据库文件：`<root>/<name>/<name>.db`
///
/// 吸收了旧版 `Config` 的存储位置逻辑（iCloud / 本地 / 自定义）与数据库目录
/// 管理，成为存储能力的唯一数据源。
///
/// 存储位置配置本身**不**存在 `UserDefaults` 里，而是写进本插件自己的
/// 数据目录（`<root>/<pluginID>/storage-location.json`），详见
/// `StorageLocationStore`。存储变更通过 `StorageProvidingEvent` 广播。
@MainActor
public final class StorageProvider: ObservableObject, CisumProviderStorage.StorageProviding, ProviderStorage.StorageProviding {
    /// 存储位置配置的磁盘存储。
    ///
    /// 配置写进本插件自己的数据目录（`<databaseRoot>/<pluginID>/storage-location.json`），
    /// 不再用 `UserDefaults`——偏好域会被 iCloud 同步，而「数据放在哪」是
    /// 设备本地的决策。详见 `StorageLocationStore`。
    private let locationStore: StorageLocationStore

    /// 数据根目录名：`db_<debug|production>_v<majorVersion>`（对齐 Lumi/GitOK 命名规则）。
    private let dataRootDirectoryName: String

    /// 缓存的数据库根目录（init 时尽力创建）。
    public let databaseRoot: URL
    private let eventObservers = EventObserverStore<CisumStorageProvidingEvent>()

    /// - Parameters:
    ///   - databaseRoot: 数据根目录。缺省按标准规则解析。
    ///   - pluginID: 本插件 id，决定配置文件的落盘目录。
    public init(
        databaseRoot: URL? = nil,
        pluginID: String = StoragePlugin.pluginID
    ) {
        dataRootDirectoryName = DataRootDirectoryNaming.directoryName()
        let root = databaseRoot
            ?? MagicApp.getAppSpecificSupportDirectory()
                .appendingPathComponent(dataRootDirectoryName, isDirectory: true)
        try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        self.databaseRoot = root
        locationStore = StorageLocationStore(databaseRoot: root, pluginID: pluginID)
    }

    // MARK: - Lumi ProviderStorage compatibility

    /// Lumi's shared storage contract uses the same application data root as
    /// Cisum's database root. Keeping this as a computed property ensures both
    /// protocol views always refer to the same directory.
    public var dataRootDirectory: URL { databaseRoot }

    /// Shared Lumi plugins keep infrastructure data under the same Core
    /// directory used by Cisum's storage root.
    public func coreDataDirectory() -> URL {
        let directory = databaseRoot.appendingPathComponent("Core", isDirectory: true)
        try? Self.ensureDirectory(at: directory)
        return directory
    }

    public var currentStorageLocation: StorageLocation? {
        guard let location = locationStore.load() else { return nil }
        guard storageRoot(for: location) != nil else { return nil }
        return location
    }

    public var storageRoot: URL? {
        guard let location = currentStorageLocation else { return nil }
        return storageRoot(for: location)
    }

    public func storageRoot(for location: StorageLocation) -> URL? {
        switch location {
        case .icloud: MagicApp.getCloudDocumentsDirectory()
        case .local: MagicApp.getDocumentsDirectory()
        case .custom: nil
        }
    }

    public var hasUsableStorageLocation: Bool { currentStorageLocation != nil }

    public var isICloudStorageAvailable: Bool { storageRoot(for: .icloud) != nil }

    public func databaseFile(name: String) throws -> URL {
        let dir = databaseRoot.appendingPathComponent(name, isDirectory: true)
        try Self.ensureDirectory(at: dir)
        return dir.appendingPathComponent("\(name).db")
    }

    public func pluginDataDirectory(for pluginID: String) -> URL {
        let dir = pluginDataDirectoryPath(for: pluginID)
        try? Self.ensureDirectory(at: dir)
        return dir
    }

    /// 解析插件数据目录路径，**不创建目录**。
    ///
    /// 与 `pluginDataDirectory(for:)` 分开，是为了让目录迁移能在目录被
    /// 创建之前判断「新目录是否已存在」——若先创建再判断，迁移永远不会执行。
    public func pluginDataDirectoryPath(for pluginID: String) -> URL {
        databaseRoot.appendingPathComponent(pluginID, isDirectory: true)
    }

    public func setStorageLocation(_ location: StorageLocation?) {
        locationStore.save(location)
        eventObservers.send(.locationChanged(location))
        eventObservers.send(.storageAvailabilityChanged)
    }

    public func resetStorageLocation() {
        locationStore.reset()
        eventObservers.send(.locationChanged(nil))
        eventObservers.send(.storageAvailabilityChanged)
    }

    @discardableResult
    public func addObserver(
        _ callback: @escaping (CisumProviderStorage.StorageProvidingEvent) -> Void
    ) -> any CisumProviderStorage.StorageProvidingObserverHandle {
        eventObservers.add(callback)
    }

    // MARK: - 数据根目录命名（对齐 GitOK DefaultStorageProvider）

    /// 数据根目录名：`db_<debug|production>_v<majorVersion>`。
    ///
    /// 转发到 `DataRootDirectoryNaming`——命名规则只有一份定义，
    /// 其它插件与调试入口一律复用它，避免各处抄一份后改版本号策略时漏改。
    static func dataRootDirectoryName(debug: Bool, majorVersion: Int) -> String {
        DataRootDirectoryNaming.directoryName(isDebug: debug, majorVersion: majorVersion)
    }

    /// 解析主版本号：`"5.3.1" -> 5`；无法解析时回退 1。
    static func majorVersion(from versionString: String) -> Int {
        DataRootDirectoryNaming.majorVersion(from: versionString)
    }

    private static func ensureDirectory(at url: URL) throws {
        var isDirectory: ObjCBool = false
        if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory), !isDirectory.boolValue {
            try FileManager.default.removeItem(at: url)
        } else if (try? FileManager.default.destinationOfSymbolicLink(atPath: url.path)) != nil {
            try FileManager.default.removeItem(at: url)
        }
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }
}
