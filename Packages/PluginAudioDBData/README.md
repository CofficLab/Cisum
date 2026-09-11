# PluginAudioDBData

音频目录数据插件。它是 `AudioLibraryProviding`、`AudioLibraryOrderingProviding` 和
`AudioTrackNavigationProviding` 的唯一实现与注册入口，内部持有 SwiftData 模型、数据库、仓库、文件系统同步和事件桥接。

数据插件同时负责音频目录的一致性生命周期：启动时建立文件系统监控，执行首次扫描，
处理新增/修改/删除文件，并在存储位置变化时重建 Repository 与监控器。文件系统同步不再由
独立的 `PluginAudioJob` 插件驱动。

其他音频插件只能通过 Kernel 解析 Provider 协议，不能构造 `AudioRepo` 或访问全局 Host。

## Directory layout

```text
PluginAudioDBData/
├── Package.swift
├── Resources/
├── Sources/
│   ├── Plugin/
│   │   └── AudioDBDataPlugin.swift
│   ├── Providers/
│   │   ├── AudioLibraryProvider.swift
│   │   └── AudioTrackNavigationProvider.swift
│   ├── Observers/
│   │   └── AudioStorageObserver.swift
│   ├── Models/
│   │   └── AudioModel.swift
│   ├── Persistence/
│   │   ├── AudioDB.swift
│   │   ├── AudioRepo.swift
│   │   └── AudioConfigRepo.swift
│   ├── Synchronization/
│   │   └── AudioFileSystemMonitor.swift
│   ├── Events/
│   │   └── AudioEvent.swift
│   ├── Errors/
│   │   └── AudioPluginError.swift
│   └── Extensions/
│       └── URL+Directory.swift
└── Tests/
    ├── AudioDBPluginTests.swift
    └── AudioFileSystemMonitorTests.swift
```

目录的判断标准是职责，而不是 Swift 类型的可见性：`Providers` 是具体 Provider
适配器，`Observers` 只持有外部状态订阅并负责取消，`Persistence` 是 SwiftData/Repository
实现，`Synchronization` 负责外部文件变化到数据层的协调；跨插件可依赖的协议仍然只放在
`ProviderAudio*` 包中。
