import Foundation
import CisumProviderStorage

/// 磁盘日志配置协议
public protocol FileLogConfiguration: Sendable {
    /// 返回日志存储目录
    func logsDirectory() -> URL
}

/// 默认日志配置：使用 Cisum 的数据库目录下插件专属子目录
///
/// 目录名 = 插件 id（`com.coffic.cisum.plugin.file-log`），与所有插件的
/// 数据目录规则一致（见 `StorageProviding.pluginDataDirectory(for:)`）。
///
/// ## 为什么必须走插件专属目录
///
/// 早期实现把日志写进 `<databaseRoot>/FileLog/`——那是**历史目录名**
/// （已登记在 `PluginDataDirectoryHistory` 的 legacy 列表里），不是当前
/// 约定的目录名。若日志继续写在那里：
///
/// - 磁盘上会出现两个日志目录（`FileLog/` 与反向 DNS 目录），用户看不懂；
/// - 迁移逻辑无法把旧目录搬走——新目录「已有内容」时迁移会跳过，
///   旧目录里的历史日志永远留在原地；
/// - 插件被禁用时协调器仍会用这份默认配置写日志，与插件专属目录分叉。
///
/// 因此这里只解析**路径**（不创建目录），目录的创建交给协调器。
struct DefaultFileLogConfiguration: FileLogConfiguration {
    /// 本插件的 id，即日志目录名。
    nonisolated static let pluginID = "com.coffic.cisum.plugin.file-log"

    func logsDirectory() -> URL {
        FileLogDirectory.defaultLogsDirectory()
    }
}

enum FileLogDirectory {
    /// 日志目录：`<appSpecificSupport>/<dataRootName>/<pluginID>/`。
    ///
    /// 数据根目录名复用 `DataRootDirectoryNaming`，不再各抄一份
    /// `db_debug_v<N>`——否则改版本号策略时必然漏改一处，导致日志写到
    /// 另一个目录，用户看不到历史日志。
    static func defaultLogsDirectory() -> URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let bundleID = Bundle.main.bundleIdentifier ?? "com.yueyi.cisum"
        let dataRootName = DataRootDirectoryNaming.directoryName()
        return appSupport
            .appendingPathComponent(bundleID, isDirectory: true)
            .appendingPathComponent(dataRootName, isDirectory: true)
            .appendingPathComponent(DefaultFileLogConfiguration.pluginID, isDirectory: true)
    }
}
