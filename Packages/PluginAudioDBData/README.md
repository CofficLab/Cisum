# PluginAudioDBData

音频目录数据插件。它是 `AudioLibraryProviding`、`AudioLibraryOrderingProviding` 和
`AudioTrackNavigationProviding` 的唯一实现与注册入口，内部持有 SwiftData 模型、数据库、仓库、文件系统同步和事件桥接。

其他音频插件只能通过 Kernel 解析 Provider 协议，不能构造 `AudioRepo` 或访问全局 Host。
