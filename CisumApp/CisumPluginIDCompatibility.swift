import Foundation

/// 插件 ID 兼容映射：新 id → 旧 id。
///
/// 插件 id 从「类型名」（`AudioPlugin`）改为「反向 DNS」
/// （`com.coffic.cisum.plugin.audio`）以对齐 Lumi 规范。id 同时是
/// **插件启用状态的存储键**——用户显式开关过的插件状态以旧 id 为键落盘。
///
/// 这张表交给 `HostManifest.legacyPluginIDAliases`：内核读取启用状态时
/// 先查新 id，miss 再查旧 id；写入时新 id 与旧 id 一起落盘，
/// 保证升级不丢状态、回滚旧版本也仍然生效。
///
/// 历史**目录名**的迁移表在存储层（`CisumProviderStorage.PluginDataDirectoryHistory`），
/// 经 `HostManifest.storage.legacyDirectoryMigrations` 交给装配引擎。
enum CisumPluginIDCompatibility {
    static let legacyAliases: [String: String] = [
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
}