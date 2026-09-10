import KernelCore
import Foundation
import MagicKit
import ProviderStorage

/// `StorageProviding` 的具体实现。
///
/// 目录结构（对齐 Lumi/GitOK `DefaultStorageProvider`）：
/// - 数据根目录：`~/Library/Application Support/<bundleID>/db_<debug|production>_v<majorVersion>/`
/// - 插件数据目录：`<root>/<pluginID>/`（无 `Plugins/` 中间层）
/// - 数据库文件：`<root>/<name>/<name>.db`
///
/// 吸收了旧版 `Config` 的存储位置逻辑（iCloud / 本地 / 自定义）与数据库目录
/// 管理，成为存储能力的唯一数据源。保持向后兼容：
/// - `UserDefaults` key `"StorageLocation"`（与旧版 `Config` 一致）。
/// - 存储变更通过内核事件 `.cisumStorageLocationDidChange` / `.cisumStorageLocationDidReset` 广播。
@MainActor
public final class StorageProvider: ObservableObject, StorageProviding {
    private static let storageLocationKey = "StorageLocation"

    /// 数据根目录名：`db_<debug|production>_v<majorVersion>`（对齐 Lumi/GitOK 命名规则）。
    private let dataRootDirectoryName: String

    /// 缓存的数据库根目录（init 时尽力创建）。
    public let databaseRoot: URL
    private let eventObservers = KernelEventObserverStore<StorageProvidingEvent>()

    public init() {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1"
        let majorVersion = Self.majorVersion(from: version)

        #if DEBUG
            dataRootDirectoryName = Self.dataRootDirectoryName(debug: true, majorVersion: majorVersion)
        #else
            dataRootDirectoryName = Self.dataRootDirectoryName(debug: false, majorVersion: majorVersion)
        #endif

        let root = MagicApp.getAppSpecificSupportDirectory()
            .appendingPathComponent(dataRootDirectoryName, isDirectory: true)
        try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        databaseRoot = root
    }

    public var currentStorageLocation: StorageLocation? {
        guard let raw = UserDefaults.standard.string(forKey: Self.storageLocationKey),
              let location = StorageLocation(rawValue: raw) else { return nil }
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
        let dir = databaseRoot.appendingPathComponent(pluginID, isDirectory: true)
        try? Self.ensureDirectory(at: dir)
        return dir
    }

    public func setStorageLocation(_ location: StorageLocation?) {
        UserDefaults.standard.set(location?.rawValue, forKey: Self.storageLocationKey)
        eventObservers.send(.locationChanged(location))
        eventObservers.send(.storageAvailabilityChanged)
        NotificationCenter.default.post(name: .cisumStorageLocationDidChange, object: nil)
    }

    public func resetStorageLocation() {
        UserDefaults.standard.removeObject(forKey: Self.storageLocationKey)
        eventObservers.send(.locationChanged(nil))
        eventObservers.send(.storageAvailabilityChanged)
        NotificationCenter.default.post(name: .cisumStorageLocationDidReset, object: nil)
    }

    @discardableResult
    public func addObserver(
        _ callback: @escaping (StorageProvidingEvent) -> Void
    ) -> any StorageProvidingObserverHandle {
        eventObservers.add(callback)
    }

    // MARK: - Bridging（为旧版 `StorageDependencies` 视图提供兼容入口）

    /// 由插件在 `onBoot` 设置，供 `StoragePlugin.addSettingView` 构建旧版依赖闭包使用。
    nonisolated(unsafe) public static var current: StorageProvider?

    /// 构建旧版 `StorageDependencies`，桥接到当前 `StorageProvider`。
    public static func makePluginDependencies() -> StorageDependencies {
        StorageDependencies(
            getStorageLocation: { current?.currentStorageLocation.map { StoragePluginLocation($0) } },
            updateStorageLocation: { current?.setStorageLocation($0.map { StorageLocation($0) }) },
            getStorageRoot: { current?.storageRoot },
            getStorageRootForLocation: { current?.storageRoot(for: StorageLocation($0)) },
            postStorageLocationUpdated: {
                NotificationCenter.default.post(name: .cisumStorageLocationDidChange, object: nil)
            },
            isDesktop: MagicApp.isDesktop
        )
    }

    // MARK: - 数据根目录命名（对齐 GitOK DefaultStorageProvider）

    /// 数据根目录名：`db_<debug|production>_v<majorVersion>`。
    static func dataRootDirectoryName(debug: Bool, majorVersion: Int) -> String {
        let environment = debug ? "debug" : "production"
        return "db_\(environment)_v\(majorVersion)"
    }

    /// 解析主版本号：`"5.3.1" -> 5`；无法解析时回退 1。
    static func majorVersion(from versionString: String) -> Int {
        versionString.split(separator: ".").first.flatMap { Int($0) } ?? 1
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

// MARK: - StorageLocation ↔ StoragePluginLocation

public extension StoragePluginLocation {
    init(_ location: StorageLocation) {
        self = StoragePluginLocation(rawValue: location.rawValue) ?? .local
    }
}

public extension StorageLocation {
    init(_ location: StoragePluginLocation) {
        self = StorageLocation(rawValue: location.rawValue) ?? .local
    }
}
