import Foundation

/// 插件数据目录的历史名称表。
///
/// 插件数据目录名 = 插件 id。插件 id 从「类型名」（`AudioDBDataPlugin`）
/// 改为「反向 DNS」（`com.coffic.cisum.plugin.audio-db-data`）后，磁盘上
/// 留下的旧目录名也需要一并迁移。
///
/// ## 为什么放在 ProviderStorage
///
/// 这张表描述的是「磁盘布局的历史」，属于存储层知识：插件负责按表里的名字
/// 找旧目录，存储层负责搬家。两边分开放会让插件各自硬编码历史目录名，
/// 迟早漏掉一个。
///
/// 插件**启用状态**的 id 映射不在这里——那是宿主（`FactoryCisum`）的职责，
/// 因为它跨越所有插件，而存储层不该知道有哪些插件。
public enum PluginDataDirectoryHistory {
    /// 新插件 id → 历史目录名序列（按时间**从旧到新**）。
    ///
    /// 只有真正在磁盘上留下过目录的插件才需要登记：插件若不落盘数据，
    /// 目录名变了也没有任何东西需要搬。
    public static let legacyDirectoryNames: [String: [String]] = [
        // 音频数据层：曾用 `databaseFile(name: "audio")`，再用类型名。
        "com.coffic.cisum.plugin.audio-db-data": ["audio", "AudioDBDataPlugin"],
        // 喜欢数据：曾用 `databaseFile(name: "audio_like")`，再用类型名。
        "com.coffic.cisum.plugin.audio-like": ["audio_like", "AudioLikePlugin"],
        // 书籍数据层：曾用 `books_db`，再用类型名。
        "com.coffic.cisum.plugin.book-db-data": ["books_db", "BookDBDataPlugin"],
        // 磁盘日志：曾用 `FileLog`，再用类型名。
        "com.coffic.cisum.plugin.file-log": ["FileLog", "FileLogPlugin"],
        // 复制任务：曾用 `copy_db`，再用类型名。
        "com.coffic.cisum.plugin.copy": ["copy_db", "CopyPlugin"],
        // 播放状态：曾用 `PluginPlayBack`（类型名）。
        "com.coffic.cisum.plugin.playback": ["PluginPlayBack"],
        // 场景持久化：曾用 `ScenePlugin`（类型名）。
        "com.coffic.cisum.plugin.scene": ["ScenePlugin"],
        // 插件管理器：曾用 `PluginPluginManager`（类型名）。
        "com.coffic.cisum.plugin.plugin-manager": ["PluginPluginManager"],
    ]

    /// 某个新插件 id 对应的、需要迁移的历史目录名。
    ///
    /// - Parameter pluginID: 新插件 id。
    /// - Returns: 历史目录名（按时间从旧到新）；没有则返回空数组。
    public static func legacyDirectoryNames(for pluginID: String) -> [String] {
        legacyDirectoryNames[pluginID] ?? []
    }
}
