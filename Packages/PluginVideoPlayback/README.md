# PluginVideoPlayback

视频播放插件：注册 `VideoPlaybackProviding`，并管理底层播放引擎。

引擎按平台选择：macOS 走 mpv（格式覆盖广、HEVC 硬解），iOS 走系统 AVPlayer，引擎失败时自动降级到兜底引擎。
