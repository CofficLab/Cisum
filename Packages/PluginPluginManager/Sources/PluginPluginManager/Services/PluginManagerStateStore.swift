import ProviderStorage
import Foundation
import CisumKernelSupport

/// PluginPluginManager 的状态存储服务（Services 层，对齐 Lumi `ProviderStorage.PluginEnabledStateStore`）。
///
/// 专门负责把插件启用/禁用状态持久化到磁盘：以 `[pluginID: Bool]` 形式写入
/// 插件的专属数据目录（对齐 GitOK：目录名 = 插件 ID），跨启动保留。
///
/// ## 文件
/// - 路径：`<pluginDataDirectory>/plugin-enabled-overrides.plist`
/// - 格式：binary plist，`[String: Bool]`（`.atomic` 写入）。
///
/// ## 目录来源
/// `pluginDataDirectory` 由调用方通过 `StorageProviding.pluginDataDirectory(for: pluginID)`
/// 解析得到，目录名即插件 ID（对齐 GitOK `DefaultStorageProvider` 规律）。
///
/// ## 迁移
/// 首次初始化且文件为空时，从旧版 UserDefaults key
/// `com.coffic.cisum.pluginEnabledOverrides` 迁移，成功后清除该 key。
@MainActor
public final class PluginManagerStateStore: PluginStatePersisting {
    private static let filename = "plugin-enabled-overrides.plist"
    private static let legacyDefaultsKey = "com.coffic.cisum.pluginEnabledOverrides"

    private let fileURL: URL
    private var cache: [String: Bool]

    /// - Parameter pluginDataDirectory: 插件专属数据目录
    ///   （由 `StorageProviding.pluginDataDirectory(for: pluginID)` 解析得到）。
    public init(pluginDataDirectory: URL) {
        self.fileURL = pluginDataDirectory
            .appendingPathComponent(Self.filename, isDirectory: false)
        self.cache = Self.load(from: fileURL)

        // 从旧版内核持有的 UserDefaults 存储迁移，保留用户既有设置。
        if cache.isEmpty,
           let legacy = UserDefaults.standard.dictionary(forKey: Self.legacyDefaultsKey) as? [String: Bool],
           !legacy.isEmpty {
            self.cache = legacy
            persist()
            UserDefaults.standard.removeObject(forKey: Self.legacyDefaultsKey)
        }
    }

    /// 读取某个插件的用户覆盖值；`nil` 表示用户未设置（应回到默认值）。
    public func override(for pluginID: String) -> Bool? {
        cache[pluginID]
    }

    /// 设置某个插件的启用状态覆盖并持久化。
    public func setOverride(_ enabled: Bool, for pluginID: String) {
        cache[pluginID] = enabled
        persist()
    }

    /// 清除某个插件的启用状态覆盖（回到策略默认值）。
    public func clearOverride(for pluginID: String) {
        cache.removeValue(forKey: pluginID)
        persist()
    }


    // MARK: - LumiKernel PluginStatePersisting 适配（对齐共享内核命名）

    public func enabledState(pluginID: String) -> Bool? {
        override(for: pluginID)
    }

    public func setEnabled(_ enabled: Bool, pluginID: String) {
        setOverride(enabled, for: pluginID)
    }
    public func removeState(pluginID: String) {
        clearOverride(for: pluginID)
    }


    /// 清除所有覆盖值。
    public func reset() {
        cache.removeAll()
        persist()
    }

    // MARK: - Persistence

    private func persist() {
        do {
            let directory = fileURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let data = try PropertyListSerialization.data(
                fromPropertyList: cache,
                format: .binary,
                options: 0
            )
            try data.write(to: fileURL, options: .atomic)
        } catch {
            // A failed write must not prevent the in-memory setting from taking effect.
        }
    }

    private static func load(from url: URL) -> [String: Bool] {
        guard let data = try? Data(contentsOf: url),
              let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil),
              let values = plist as? [String: Bool] else {
            return [:]
        }
        return values
    }
}