# Plugin 边界

Cisum 的包只按三类组织：

1. `Provider*`：稳定的跨插件协议、事件、Observer 句柄和纯 DTO/模型；不包含业务实现、持久化或文件系统访问。
2. `Plugin*`：单一业务功能的生命周期、UI、Observers 和 Capabilities。它通过 Provider 接收外部变化，通过 Capability 操作外部能力。
3. `*Kit`：与业务无关的通用基础能力，例如 UI、播放、文件和系统工具。

书籍和音频的跨插件代码必须位于独立的中立 SwiftPM package，不能仅在某个 `Plugin*` package 内拆 target：

- `ProviderBook`：书籍模型、数据库、仓库、配置和领域事件。
- `ProviderAudioLibrary`：音频库、排序能力协议、事件和诊断 DTO。
- `ProviderAudioLike`：喜欢能力协议与 `AudioLikeItem` DTO。
- `ProviderAudioNavigation`：曲目首尾/前后导航协议。
- `ProviderStore`：订阅状态与商店服务，供音频复制能力使用。

功能插件只能依赖这些中立产品和公共 Provider，不能导入其他 `Plugin*` 模块，也不能通过另一个 `Plugin*` package 获取 Core 产品。唯一允许集中依赖具体插件的地方是 `FactoryCisum`。架构检查：

```text
Scripts/check-plugin-boundaries.sh
```

音频实现归属如下：`PluginAudioDBData` 唯一持有 `AudioModel`、`AudioDB`、`AudioRepo`、SwiftData 容器、文件系统同步和事件桥接；`PluginAudioLike` 唯一持有喜欢的 SwiftData 模型、仓库和配置。音频目录的文件系统同步属于数据一致性机制，由 `PluginAudioDBData` 在自身生命周期内启动、停止和重建，不再由独立的 `PluginAudioJob` 驱动。`PluginAudio` 只负责根视图和存储可用性门禁，功能插件通过 Kernel 解析协议。新增功能插件时，应先定义 Provider，再在插件内部实现 Provider；外部文件变化放在拥有数据一致性职责的插件内部，外部写入、播放、复制等动作放在 Capability。
