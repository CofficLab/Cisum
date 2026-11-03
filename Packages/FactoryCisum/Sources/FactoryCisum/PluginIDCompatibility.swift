import Foundation
import CisumProviderStorage

/// 插件 ID 兼容映射。
///
/// ## 背景
///
/// 插件 id 从「类型名」（`AudioPlugin`）改为「反向 DNS」
/// （`com.coffic.cisum.plugin.audio`）以对齐 Lumi 规范。id 同时是：
///
/// - **插件启用状态的存储键**——用户显式开关过的插件状态存在这里；
/// - **插件数据目录名**——`<databaseRoot>/<plugin.id>/`。
///
/// 两者都随 id 变化，因此升级必须携带旧 id 的映射，否则用户会看到
/// 「插件全被关掉」「数据目录消失」。
///
/// ## 两套映射，各司其职
///
/// - `legacyAliases`：新 id → 旧 id。交给内核的 `legacyPluginIDAliases`，
///   负责**启用状态**的读写兼容（读回退旧 id，写同时落两份）。
/// - `legacyDirectoryNames`：新 id → 旧**目录名**序列。负责**磁盘目录**
///   的迁移，且必须是序列——id 改过两轮（类型名 → 反向 DNS），
///   中间那版目录名也要一并考虑。
///
/// ## 为什么放在 Factory
///
/// 这张表描述的是「Cisum 这个宿主的产品决策」（插件叫什么），而不是
/// 某个插件自己的属性。插件包各自定义 id，但「旧 id 是什么」只有宿主
/// 知道——它跨越所有插件，放进任一插件包都会造成包之间的耦合。
public enum PluginIDCompatibility {
    /// 新插件 id → 旧插件 id。
    ///
    /// 交给 `KernelCoreContainer.legacyPluginIDAliases`：内核读取启用状态时
    /// 先查新 id，miss 再查这里的旧 id；写入时新 id 与旧 id 一起落盘，
    /// 保证回滚到旧版本时用户的开关依然有效。
    public static let legacyAliases: [String: String] = [
        "com.coffic.cisum.plugin.audio": "AudioPlugin",
        "com.coffic.cisum.plugin.audio-control-buttons": "AudioControlButtonsPlugin",
        "com.coffic.cisum.plugin.audio-db-data": "AudioDBDataPlugin",
        "com.coffic.cisum.plugin.audio-db-view": "AudioDBViewPlugin",
        "com.coffic.cisum.plugin.audio-demo": "AudioDemoPlugin",
        "com.coffic.cisum.plugin.audio-download": "AudioDownloadPlugin",
        "com.coffic.cisum.plugin.audio-like": "AudioLikePlugin",
        "com.coffic.cisum.plugin.audio-play-mode": "AudioPlayModePlugin",
        "com.coffic.cisum.plugin.audio-progress": "AudioProgressPlugin",
        "com.coffic.cisum.plugin.audio-scene": "AudioScenePlugin",
        "com.coffic.cisum.plugin.audio-settings": "AudioSettingsPlugin",
        "com.coffic.cisum.plugin.audio-widget-control": "AudioWidgetControlPlugin",
        "com.coffic.cisum.plugin.book": "BookPlugin",
        "com.coffic.cisum.plugin.book-control-buttons": "BookControlButtonsPlugin",
        "com.coffic.cisum.plugin.book-db-data": "BookDBDataPlugin",
        "com.coffic.cisum.plugin.book-db-view": "BookDBViewPlugin",
        "com.coffic.cisum.plugin.book-like": "BookLikePlugin",
        "com.coffic.cisum.plugin.book-play-mode": "BookPlayModePlugin",
        "com.coffic.cisum.plugin.book-progress": "BookProgressPlugin",
        "com.coffic.cisum.plugin.book-scene": "BookScenePlugin",
        "com.coffic.cisum.plugin.book-settings": "BookSettingsPlugin",
        "com.coffic.cisum.plugin.copy": "CopyPlugin",
        "com.coffic.cisum.plugin.file-log": "FileLogPlugin",
        "com.coffic.cisum.plugin.like-button": "LikeButtonPlugin",
        "com.coffic.cisum.plugin.open-button": "OpenButtonPlugin",
        "com.coffic.cisum.plugin.playback": "PluginPlayBack",
        "com.coffic.cisum.plugin.playback-hero": "PlaybackHeroPlugin",
        "com.coffic.cisum.plugin.playback-progress": "PlaybackProgressPlugin",
        "com.coffic.cisum.plugin.plugin-manager": "PluginPluginManager",
        "com.coffic.cisum.plugin.repository-guide": "RepositoryGuidePlugin",
        "com.coffic.cisum.plugin.scene": "ScenePlugin",
        "com.coffic.cisum.plugin.setting-general": "SettingGeneralPlugin",
        "com.coffic.cisum.plugin.settings-button": "SettingsButtonPlugin",
        "com.coffic.cisum.plugin.storage": "StoragePlugin",
        "com.coffic.cisum.plugin.store": "StorePlugin",
        "com.coffic.cisum.plugin.system": "SystemPlugin",
        "com.coffic.cisum.plugin.welcome": "WelcomePlugin",
    ]

    /// 新插件 id → 历史目录名序列（按时间从旧到新）。
    ///
    /// 磁盘目录的历史名称属于**存储层**知识（插件各自的历史目录名只有
    /// 存储层清楚），因此统一放在 `ProviderStorage.PluginDataDirectoryHistory`。
    /// 这里只做转发，避免同一张表在两处各写一份而逐渐漂移。
    public static let legacyDirectoryNames: [String: [String]] =
        PluginDataDirectoryHistory.legacyDirectoryNames

    /// 找出某个新 id 对应的、需要迁移的历史目录名。
    ///
    /// - Parameter pluginID: 新插件 id。
    /// - Returns: 历史目录名（按时间从旧到新）；没有则返回空数组。
    public static func legacyDirectoryNames(for pluginID: String) -> [String] {
        PluginDataDirectoryHistory.legacyDirectoryNames(for: pluginID)
    }
}
