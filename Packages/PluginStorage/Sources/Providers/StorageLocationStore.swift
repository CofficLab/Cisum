import Foundation
import CisumProviderStorage

/// 存储位置配置的磁盘持久化。
///
/// ## 为什么不再用 `UserDefaults`
///
/// `UserDefaults` 属于用户偏好域，语义上不适合承载「应用把数据放在哪」
/// 这类配置：
///
/// - 偏好域会被 iCloud 同步（`NSUbiquitousKeyValueStore`），但数据目录
///   的选择是**设备本地**的决策——两台设备选同一个位置并不合理。
/// - 偏好域是**全应用共享**的，`UserDefaults.standard` 里混着几十个键，
///   「存储位置」只是其中一个，任何插件误用同名键都会污染它。
///
/// 因此改成像**普通插件**那样，把自己的配置写进自己的数据目录。
///
/// ## 归属
///
/// 配置落在 `<databaseRoot>/com.coffic.cisum.plugin.storage/storage-location.json`。
/// 目录名 = 插件 id（与 Lumi / Cisum 的插件数据目录约定一致）。
///
/// - Note: `PluginStorage` 自己就是 `StorageProviding` 的实现者，因此它的
///   目录不能用 `pluginDataDirectory(for:)` 拿——那会造成自举依赖。
///   这里直接由 `databaseRoot` 拼出路径，与 `pluginDataDirectoryPath(for:)`
///   的语义完全一致（只解析路径，不创建目录）。
@MainActor
final class StorageLocationStore {
    /// 配置文件名。
    static let fileName = "storage-location.json"

    /// 配置文件所在目录：`<databaseRoot>/<pluginID>/`。
    let directory: URL

    /// 配置文件完整路径。
    var fileURL: URL {
        directory.appendingPathComponent(Self.fileName, isDirectory: false)
    }

    init(databaseRoot: URL, pluginID: String) {
        self.directory = databaseRoot.appendingPathComponent(pluginID, isDirectory: true)
    }

    /// 读取已保存的存储位置。
    ///
    /// - Returns: 文件不存在、内容损坏或位置取值非法时返回 `nil`。
    func load() -> StorageLocation? {
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        guard let decoded = try? JSONDecoder().decode(StoredLocation.self, from: data) else {
            // 文件损坏时按「未配置」处理：引导会重新出现，用户可重新选择。
            // 损坏的文件保留在原处，不静默删除——便于事后排查。
            return nil
        }
        return StorageLocation(rawValue: decoded.location)
    }

    /// 写入存储位置。
    ///
    /// - Parameter location: 要保存的位置；`nil` 表示清除配置。
    func save(_ location: StorageLocation?) {
        guard let location else {
            try? FileManager.default.removeItem(at: fileURL)
            return
        }
        guard let data = try? JSONEncoder().encode(StoredLocation(location: location.rawValue)) else {
            return
        }
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try? data.write(to: fileURL, options: .atomic)
    }

    /// 清除存储位置配置。
    func reset() {
        try? FileManager.default.removeItem(at: fileURL)
    }

    /// 磁盘上的 JSON 结构。
    ///
    /// 单独建模而不是直接编码 `StorageLocation`：`StorageLocation` 是
    /// `Codable` 的裸字符串枚举，直接编码得到的是 `"icloud"` 这样的
    /// 顶层字符串，读起来不像配置文件。用带字段的结构体，
    /// 文件内容形如 `{"location":"icloud"}`。
    private struct StoredLocation: Codable {
        let location: String

        init(location: String) {
            self.location = location
        }
    }
}
