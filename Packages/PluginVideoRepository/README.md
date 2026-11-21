# PluginVideoRepository

视频仓库数据层插件：目录选择与持久化、目录扫描、标签 / 评分 / 播放进度元数据、文件重命名与删除。

对外只暴露 `VideoRepositoryProviding`（定义在 `ProviderVideo`），UI 插件不直接访问文件系统。
