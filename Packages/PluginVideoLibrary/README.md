# PluginVideoLibrary

视频库插件：注册 `VideoLibraryProviding`，提供仓库列表、筛选排序、文件管理与播放界面。

仓库由 `PluginVideoRepository` 提供，存放于共享存储根目录下的 `videos` 子目录。列表界面支持网格 / 列表两种视图、按范围（全部 / 收藏 / 继续观看 / 未下载）与标签筛选，并可通过文件选择器把外部视频导入仓库。播放使用 `PluginVideoPlayback` 的播放栈，macOS 为覆盖式播放器，iOS 为全屏 sheet。
