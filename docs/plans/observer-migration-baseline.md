# Cisum Observer-Driven Plugin Architecture — 迁移基线

> 本文档是 `docs/plans/observer-driven-plugin-architecture.md` 的 Phase 0 交付物：
> 仓库中每个外部状态监听点都有归属插件、归属 Observer 和目标 ViewModel。
>
> 记录方式：逐插件列出入口生命周期、外部输入点、目标 Observer / ViewModel、需要的 Provider 事件。
> 后续每完成一个插件的迁移，即删除该项的「直接外部订阅」。

## 0. 统计口径

- 扫描范围：`Packages/Plugin*` 下所有 `Sources/**` 的 Swift 文件（不含 `.build` / 依赖 checkout）。
- 「外部输入」指：非本地 UI 状态的 `.onReceive`、`.onChange`、`.task`、`NotificationCenter.default.(addObserver|publisher)`、`@EnvironmentObject`、`@Environment` 注入的 Provider、View 内对 `Kernel` / `PluginHost` / Repository 的直接解析。
- 本地 UI 状态（搜索文本、筛选器、列表选择、动画）不在此清单，保留在 View 或本地 ViewModel。

## 1. Provider 层现状（5.2 节检查项）

| Provider | 语义事件 | 默认 no-op | 实现发送真实事件 | 备注 |
|---|---|---|---|---|
| `ThemeProviding` | `themesChanged` / `selectionChanged` | 是 | 是（`ThemeService`） | 已落实 |
| `StorageProviding` | `locationChanged` / `storageAvailabilityChanged` | 是 | 是（`StorageProvider`） | 已落实；仍桥接旧通知 |
| `SceneProviding` | `selectionChanged(scene:)` | 是 | 是（`SceneProvider`） | 已落实 |
| `PlaybackProviding` | `stateChanged` / `assetChanged` / `timeChanged` / `durationChanged` / `playModeChanged` / `likedAssetsChanged` | 是 | 待核实（`MagicPlayMan+PlaybackProviding`） | 见 Phase 2 |
| `AudioLibraryProviding` | `libraryChanged(totalCount:)` | 是 | 待核实 | 见 Phase 2 |
| `CloudProviding` | `availabilityChanged` | 是 | 待核实（`FactoryCisum/CloudService`） | Phase 4 |
| `DeviceProviding` | `deviceChanged` | 是 | 待核实 | Phase 4 |
| `AppStateProviding` | `demoModeChanged` / `dbViewVisibilityChanged` / `importingChanged` / `droppingChanged` / `stateMessageChanged` | 是 | 待核实（`BasicAppStateService`） | Phase 4 |
| `PluginProviding` | `pluginsChanged` / `contributionsChanged` | 是 | 待核实（`BuiltinPluginManager`） | Phase 4 |
| `ContentViewProviding` / `RootViewProviding` / `ToolbarProviding` / `ControlViewProviding` | — | — | 静态贡献，无需 Observer | 仅静态能力，不增加空 Observer |

## 2. 各插件迁移清单

### Phase 1 — 已有 Observer + ViewModel 插件的修正

#### 2.1 PluginScene（`scene`）

- 入口：`ScenePlugin`（actor）
  - `onRegister`：注册 docs
  - `onBoot`：`registerSceneService(SceneProvider())`
  - `onReady`：`kernel.scene?.restoreCurrentScene()`
  - `onShutdown`：`unregisterProvider(SceneProviding.self)`
  - `addSettingNavigationItem`：`SceneSettingsView()`（未注入 ViewModel）
- 外部输入：
  - `SceneSettingsView`：`@Environment(\.sceneProviding)` 直接读 Provider；`@StateObject` 创建 ViewModel；`.onAppear` / `.onDisappear` attach/detach。
- 已有：`Observers/SceneProvidingObserver.swift` ✓、`ViewModels/SceneSettingsViewModel.swift` ✓
- 目标：
  - 入口 `onBoot` 创建并持有 `SceneSettingsViewModel` + `SceneProvidingObserver`（initial sync + 安装监听）。
  - `addSettingNavigationItem` 注入同一个 ViewModel。
  - `SceneSettingsView` 只接收 `@ObservedObject` ViewModel，删除 `@Environment(\.sceneProviding)` 与 attach/detach。
- 需要的 Provider 事件：`SceneProvidingEvent.selectionChanged(scene:)`（已具备）

#### 2.2 PluginStorage（`storage`）

- 入口：`StoragePlugin`（actor）
  - `onBoot`：`registerStorage(StorageProvider())`，设置 `StorageProvider.current`
  - `onShutdown`：清空 `StorageProvider.current`
  - `addSettingNavigationItem`：`StorageSettingView(storage:)` + `.pluginStorageDependencies(...)`
- 外部输入：
  - `StorageSettingView`：`@Environment(\.pluginStorageDependencies)`；`@StateObject` 创建 ViewModel；`@State` location/targetLocation/hasChanges；`.onChange(of: targetLocation)`；`.onChange(of: viewModel.location)`；`.onStoragePluginLocationChanged`（`NotificationCenter` 桥接）；`.onAppear`。
- 已有：`Observers/StorageProvidingObserver.swift` ✓、`ViewModels/StorageSettingsViewModel.swift` ✓
- 目标：
  - 入口创建并持有 `StorageSettingsViewModel` + `StorageProvidingObserver`；依赖（URL/位置判断）经 ViewModel 注入，不再经 Environment。
  - `StorageSettingView` 只接收 ViewModel；删除对 `pluginStorageDependencies` 的直接读取与 `.onStoragePluginLocationChanged`。
  - `StorageEvents.swift` 的 `onStoragePluginLocationChanged` 桥接在无消费者后移除。
- 需要的 Provider 事件：`StorageProvidingEvent.locationChanged(_)` / `.storageAvailabilityChanged`（已具备）

#### 2.3 PluginThemeSettings（`appearance`）

- 入口：`ThemeSettingsPlugin`（actor）
  - `onBoot`：`themeBox.theme = kernel.theme`
  - `onShutdown`：`themeBox.theme = nil`
  - `addSettingNavigationItem`：`ThemeSettingsDetailView(theme: themeBox.theme)`
- 外部输入：
  - `ThemeSettingsDetailView`：`@StateObject` 创建 ViewModel（init 传 theme）；`@State` selectedID/searchText/appearanceFilter（本地 UI 状态，保留）；`.onAppear`；`.onChange(of: filteredThemes.map(\.id))`（派生 UI，保留）。
- 已有：`Observers/ThemeProvidingObserver.swift` ✓、`ViewModels/ThemeSettingsViewModel.swift` ✓
- 目标：
  - 入口 `onBoot` 创建并持有 `ThemeSettingsViewModel` + `ThemeProvidingObserver`；`addSettingNavigationItem` 注入同一个 ViewModel。
  - `ThemeSettingsDetailView` 只接收 `@ObservedObject` ViewModel；`selectedID` 等本地 UI 状态保留。
- 需要的 Provider 事件：`ThemeProvidingEvent.themesChanged(_)` / `.selectionChanged(_)`（已具备）

### Phase 2 — 音频主链路

#### 2.4 PluginAudio（`audio`）

- 入口：`AudioPlugin`
  - `onRegister`：注册 docs
  - `onReady`：`guard let storage = kernel.storage` → 配置 `AudioPluginHost`（databaseURL / storageRoot / hasStorageLocation / 存储变化通知名）
  - `addRootView`：`AudioRootView(...)`（闭包注入）
- 外部输入：
  - `AudioRootView`：`@State` container/error/isInitializing/initGeneration；`.task { reloadContainer() }`；`AudioStorageChangeModifier`（`.onReceive` NotificationCenter 存储变化）。
- 目标：
  - `AudioRootViewModel`（入口持有）：容器、错误、加载、存储变化状态集中；generation 防旧结果覆盖保留。
  - `AudioStorageObserver`：订阅 `StorageProviding.locationChanged` / `.storageAvailabilityChanged`，触发容器重建与代际刷新；View 不再 `.onReceive` 存储通知。
  - `AudioRootView` 只观察 ViewModel，仓库/数据库操作经 ViewModel/Service 注入。
- 需要的 Provider 事件：`StorageProvidingEvent`（已具备）；若需 DB 语义事件，由 `AudioLibraryProviding.libraryChanged(totalCount:)` 提供。

#### 2.5 PluginAudioDBView（`audio-db`）

- 入口：`AudioDBPlugin`
  - `onRegister`：注册 docs；`onBoot` / `onShutdown`：注册/撤销 `AudioLibraryProviding`（实现位于 AudioPlugin? 需确认）
  - `addRootView`：`AudioDBRootView`；`addTabView`：DB 页
  - 入口内嵌 view：`@Environment(\.demoMode)` / `@Environment(\.appIsImporting)` / `@Environment(\.showAudioDBViewAction)` —— 均来自 `AppStateProviding` 的桥接，需迁到 `AppStateObserver`。
- 外部输入：
  - `AudioList`：`@EnvironmentObject playManController`；`@Environment(\.audioDBDependencies)`；`@State` urls/isLoading/isLoadingMore/hasMore/currentPage/pageSize/isSyncing/totalCount/loadGeneration/selectionGeneration；`.onAppear`；`.onChange(of: selection)`；`.onDBDeleted/.onDBSynced/.onDBSortDone/.onDBUpdated/.onDBSyncing`（`AudioDBEventViews` NotificationCenter 桥接）；`.onPlayManAssetChanged`。
  - `AudioDBRootView`：`@Environment(\.audioDBDependencies)`；`.task`。
  - `AudioItemView`：`@EnvironmentObject playMan`；`.task(id: url)`（本地加载，保留）。
  - `AudioDBEventViews`：6 个 `onReceive(NotificationCenter.publisher(...))` View modifier。
- 目标：
  - `AudioLibraryObserver`（订阅 `AudioLibraryProviding.libraryChanged(totalCount:)`）+ `AudioStorageObserver`（存储变化）+ `AudioDatabaseObserver`（`dbSynced/dbUpdated/dbDeleted/排序` 通知集中适配）。
  - `AudioListViewModel`（入口持有）：列表加载、分页、选中项、删除回读、同步状态集中。
  - `AudioDBEventViews` 不再直接消费外部数据库通知；如保留 modifier 仅转发 ViewModel 内部 UI action。
  - `AudioLikeSettingsView` / `AudioLikeRootView` 的直接通知订阅移入 `AudioLikeObserver`（见 2.6）。
- 需要的 Provider 事件：`AudioLibraryProvidingEvent.libraryChanged(totalCount:)`；存储事件 `StorageProvidingEvent`。

#### 2.6 PluginAudioLike（`audio-like`）

- 入口：`AudioLikePlugin`
  - `onRegister`：注册 docs；`onBoot` / `onShutdown`：注册/撤销喜欢能力
  - `addRootView`：`AudioLikePluginRootView`；`addSettingView` / `addSettingNavigationItem`：`AudioLikeSettingsView`
- 外部输入：
  - `AudioLikeRootView`：`@EnvironmentObject man`；`@Environment(\.sceneProviding)`（或等效）；`.onChange(of: scene?.currentScene)`。
  - `AudioLikeSettingsView`：`.onReceive(.AudioLikeStatusChanged)`。
- 目标：
  - `AudioLikeObserver`：订阅喜欢状态与播放状态（`PlaybackProviding.likedAssetsChanged` / `stateChanged` / `assetChanged`），替代直接通知订阅。
  - 喜欢列表 ViewModel：入口持有；View 只读。
- 需要的 Provider 事件：`PlaybackProvidingEvent.likedAssetsChanged(Set<URL>)` 等（已具备）。

### Phase 3 — 书籍主链路

#### 2.7 PluginBook（`book`）

- 入口：`BookPlugin`
  - `onReady`：`guard let storage = kernel.storage` → 配置 `BookPluginHost`
  - `addRootView`：`BookRootView(...)`
- 外部输入：
  - `BookRootView`：repo/container/error/loading `@State`；`.task`；`.onReceive`（存储变化通知列表，见 `BookRootView.swift:145`）。
- 目标：
  - `BookStorageObserver` + `BookDatabaseObserver`；根状态集中到入口持有的 ViewModel/根状态对象。
- 需要的 Provider 事件：`StorageProvidingEvent`。

#### 2.8 PluginBookDBView（`book-db`）

- 外部输入：
  - `BookGrid`：`@EnvironmentObject man` / `@EnvironmentObject repo`；`@Environment(\.bookDBViewDependencies)`；`.onChange`（选中项）。
  - `BookList` / `BookDBView` / `BookDBTips`：`@EnvironmentObject repo` / `@Environment(\.bookDBViewDependencies)`。
  - `BookTile`：`@EnvironmentObject repo`；`.task(id:)`（本地加载，保留）；`.onReceive(.bookStateUpdated)`。
  - `ChapterTile` / `BtnChapters`：`@EnvironmentObject playMan`。
  - `BookDBEventViews`：6 个 `onReceive(NotificationCenter.publisher(...))` View modifier。
- 目标：
  - `BookDatabaseObserver` + `BookPlaybackObserver` + `BookProgressObserver`；列表/网格状态集中到入口持有的 ViewModel。
  - 书籍状态刷新与恢复播放逻辑移入 Observer + ViewModel；View 只展示与发意图。
- 需要的 Provider 事件：`PlaybackProvidingEvent`；存储事件。

#### 2.9 PluginBookLike / BookProgress / BookControl / BookPlayMode / BookSettings / BookScene

- 外部输入：均为 `@EnvironmentObject man` + `.onChange(of: scene?.currentScene)` + `.onReceive(.bookDBDeleted / .bookDBSynced / .bookDBUpdated / .BookLikeStatusChanged)`（见基线统计）。
- 目标：`BookPlaybackObserver`（播放状态、场景变化）、`BookLikeObserver`（喜欢状态）、`BookDatabaseObserver`（DB 事件）各插件内按需建立；`scene?.currentScene` 的 `.onChange` 移入场景 Observer。

### Phase 4 — 系统、工具与基础设施插件

| 插件 | 外部输入 | 目标 |
|---|---|---|
| `PluginPluginManager` | `PluginManagementView`：`.onChange(filteredPlugins)`（派生 UI，保留）+ `.onReceive(.cisumEnabledPluginsDidChange)` | `PluginManagementObserver` + ViewModel，观察 `PluginProviding.pluginsChanged` |
| `PluginDevice` | `BtnDelDevice`：`@Environment(\.modelContext)`（本地数据上下文，保留） | 入口持有设备 ViewModel；`DeviceMetricsObserver`（采样/系统通知，如涉及） |
| `PluginStore` | `StoreSetting`：`.task` + `.onReceive(.storeTransactionUpdated / .Restored)`；`ProductCell` `.onChange` | Store observers + Store ViewModel |
| `PluginAudioJob` / `PluginAudioCopy` | 文件系统任务 / 迁移进度回调（`CopyEvents` 通知） | Observer/Coordinator，View 只读任务状态 |
| `PluginStorage` 迁移/文件页 | `FileInfo` / `Migrate` 系列 | 文件/迁移任务状态集中到 Observer/Coordinator |
| `PluginAudioWidgetControl` | `AudioWidgetControlRootView`：`.onReceive(.audioWidgetCommandReceived)` | Widget 命令 Observer |
| `PluginOpenButton` | `OpenCurrentButtonView`：`@EnvironmentObject man`（播放器操作） | 判断：一次性动作，无持续外部状态，可不建 Observer |
| `PluginReset` | `SystemPlugin` 内嵌 view：`@Environment(\.resetSettingsAction)` | 一次性动作，不建 Observer |
| `PluginWelcome` | `onReady`：`kernel.storage` | 一次性引导，不建 Observer |

### Phase 5 — 全量清理

- 清理范围（`Packages/Plugin*/Sources/**/Views`）：
  - `NotificationCenter.default.publisher` / `.addObserver`（View 层）
  - `@Environment` Provider 直接读取
  - 直接解析 `KernelCore` / `CisumKernel`
  - 直接调用 `PluginHost`、Repository、Provider 的外部状态读取
  - 处理外部状态的 `.onChange` / `.task`
- 保留的 View 代码需注释说明为本地 UI 状态。
- 删除旧通知 modifier、重复回调、View 内刷新 helper、兼容桥接。
- 每个插件补充 README/架构注释：入口持有的 ViewModel 与 Observer、每个 Observer 的外部来源。
- 评估静态检查脚本 / SwiftLint 规则，阻止新 View 直接订阅全局通知与 Provider。

## 3. 需要新 Provider 事件或改造的项

- `PlaybackProviding` / `AudioLibraryProviding` / `CloudProviding` / `DeviceProviding` / `AppStateProviding` / `PluginProviding` 的 no-op 默认实现：迁移对应插件时删除默认 no-op，要求实现发送真实事件（文档 5.2）。
- `AudioLibraryProviding.libraryChanged(totalCount:)` 需确认实现真实广播（`AudioPlugin` 注册的 AudioLibrary 实现）。
- 数据库通知（`dbSynced` / `dbUpdated` / `dbDeleted` / 排序）目前是跨包 `NotificationCenter`：优先将发送方改为 Provider 语义事件，通知仅保留为兼容桥接（文档 5.3）。
