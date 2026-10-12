# Cisum Observer-Driven Plugin Architecture Plan

## 1. Purpose

将 Cisum 的插件运行时统一为 Lumi 的 Observer + ViewModel 模式：

> 外部状态进入插件的唯一入口是插件自己的 Observer；Observer 将外部事件转换成 ViewModel 状态；View 只观察 ViewModel 并渲染状态。

本计划只描述迁移方案，供另一个 agent 按阶段执行。迁移过程中不得借机重写 UI、改变产品行为或删除现有 Provider 能力。

## 2. Lumi 参考基线

迁移以以下 Lumi 实现为行为参考，不要只按名称复制：

- `Lumi/Packages/PluginCodeEditor/Sources/PluginCodeEditor/CodeEditorSuperPlugin.swift`
  - 插件入口在 `onBoot` 创建 ViewModel 和 Observer。
  - 入口持有 Observer，负责 `onDisable` / `onShutdown` 清理。
  - View 通过入口注入的 ViewModel 工作，不反向解析 Provider。
- `Lumi/Packages/PluginCodeEditor/Sources/PluginCodeEditor/Observers/CodeEditorProjectObserver.swift`
  - Observer 只负责订阅 `ProjectProviding` 并把事件转成 ViewModel 更新。
- `Lumi/Packages/PluginCodeEditor/Sources/PluginCodeEditor/Observers/CodeEditorThemeObserver.swift`
  - 主题 Provider 和系统外观通知都由 Observer 适配；View 不直接订阅外部通知。
- `Lumi/Packages/PluginConversationTitle/Sources/PluginConversationTitle/ConversationTitlePlugin.swift`
  - 入口同时创建状态对象和多个 Observer，并将外部变化写入状态对象。
- `Lumi/Packages/PluginConversationList/Sources/PluginConversationList/Observers/ConversationListContextObserver.swift`
  - 一个功能可以组合多个 Provider observer，但组合关系仍属于插件的 Observer 层。

Lumi 的核心不是“每个插件必须有一个叫 Observer 的文件”，而是外部依赖不能穿透到 View：插件入口负责组装生命周期，Observer 负责输入，ViewModel 负责可观察状态。

## 3. 当前 Cisum 状态与问题

### 3.1 已有基础

Cisum 已具备迁移所需的若干基础设施：

- `KernelCore/Sources/KernelCore/Contracts/SuperPlugin.swift` 已提供 `onRegister`、`onBoot`、`onReady`、`onEnable`、`onDisable`、`onShutdown`、`onUnregister` 生命周期。
- `KernelCore/Sources/KernelCore/Support/KernelEventObserverStore.swift` 已提供可取消的 Observer Handle 存储。
- 多数 Provider 协议已经定义了语义事件和 `addObserver`，例如：
  - `ProviderTheme/ThemeProviding.swift`
  - `ProviderStorage/StorageProviding.swift`
  - `ProviderScene/SceneProviding.swift`
  - `ProviderPlayback/PlaybackProviding.swift`
  - `ProviderAudioLibrary/AudioLibraryProviding.swift`
- 以下三个插件已经有初步实现：
  - `PluginScene/Sources/PluginScene/Observers/SceneProvidingObserver.swift`
  - `PluginStorage/Sources/Observers/StorageProvidingObserver.swift`
  - `PluginThemeSettings/Sources/Observers/ThemeProvidingObserver.swift`

### 3.2 主要问题

当前仍存在四种外部状态路径：

1. Provider 直接进入 View：例如 View 使用 `@Environment` 取得 `SceneProviding`，再通过 `.onChange` 监听。
2. View 直接订阅 `NotificationCenter`：例如音频、书籍数据库、喜欢状态、商店交易和播放控制视图。
3. View 自己创建 ViewModel，并在 `.onAppear` / `.onReceive` 中补充外部同步：ViewModel 生命周期被 UI 展示生命周期决定。
4. 插件入口只注入 Provider 或 Box，没有统一持有对应的 ViewModel 和 Observer：插件关闭/禁用时无法保证所有监听器停止。

结果是同一份外部状态可能同时通过 Provider、NotificationCenter、EnvironmentObject、View 的局部任务进入，容易出现重复刷新、状态竞争、设置窗口不响应或切换后仍显示旧数据。

## 4. 目标架构

每个有外部状态的插件按下面的结构组织：

```text
PluginFoo/
└── Sources/PluginFoo/
    ├── FooPlugin.swift                 # 唯一组装入口
    ├── Observers/
    │   ├── FooProviderObserver.swift   # Provider 事件适配
    │   ├── FooNotificationObserver.swift # 必要时适配系统/旧通知
    │   └── ...
    ├── ViewModels/
    │   ├── FooViewModel.swift          # @MainActor + @Published 状态
    │   └── ...
    └── Views/
        └── ...                         # 只读 ViewModel，渲染和发送用户意图
```

### 4.1 责任边界

#### 插件入口 `*Plugin.swift`

- 在 `onBoot` 或 `onReady` 解析 Provider。
- 创建并保存 ViewModel、Observer、Service/Coordinator。
- 将当前快照先同步到 ViewModel，再安装监听器，或由 Observer 统一执行 initial sync。
- 在 `onEnable` 重建运行期资源，在 `onDisable` 取消运行期资源。
- 在 `onShutdown` 和 `onUnregister` 做幂等清理。
- 向 View 注入同一个长期存在的 ViewModel，不在每次 `addRootView` / `addSettingView` 时重新创建状态对象。

入口至少要能表达以下成员：

```swift
private var viewModel: FooViewModel?
private var observers: FooObservers?
```

如果插件包含多个相互独立的页面，可以由入口持有多个明确命名的 ViewModel，但不要用无类型 `[Any]` 或全局 NotificationCenter 作为替代。

#### Observer

- 一个 Observer 只负责一个外部输入或一个紧密相关的输入组合。
- Observer 保存 Provider 的 observer handle / Notification token，并提供 `cancel()`。
- Observer 将原始事件映射为语义明确的 ViewModel 方法，例如 `viewModel.apply(.storageChanged(...))`，不把 Provider 直接暴露给 View。
- Observer 在构造或 `start()` 时执行一次 initial sync，避免监听安装前已经存在的状态丢失。
- 回调统一切回 `@MainActor` 更新 ViewModel；不得在后台线程直接修改 `@Published` 属性。
- Observer 不持有强引用形成环：通常由 Plugin 强持有 Observer 和 ViewModel，Observer 对 ViewModel 使用 weak 引用；需要异步任务时必须支持取消和代际校验。

#### ViewModel

- 默认标记 `@MainActor`，实现 `ObservableObject`。
- `@Published private(set)` 只暴露视图需要的状态；Provider 和原始通知不作为 View 的依赖。
- 对外部事件提供语义方法，例如 `handle(_ event:)`、`apply(snapshot:)`。
- 用户操作通过意图方法表达，例如 `selectTheme`、`setStorageLocation`、`play`；ViewModel 再调用注入的 action/Provider。
- ViewModel 不负责注册外部通知；监听生命周期全部由 Observer 管理。
- 列表、加载、错误、空状态、当前选中项、generation/cancellation 等展示状态集中在 ViewModel，避免散落在 View 的 `@State`。

#### View

- 只持有 `@ObservedObject` / `@EnvironmentObject` 的插件 ViewModel。
- 不解析 Kernel、Provider、Repository 或 Plugin Host。
- 不直接使用外部通知的 `.onReceive`，不直接使用 Provider 的 `.onChange`。
- `.onChange` 仅允许用于本地交互状态或纯派生 UI 状态，例如搜索文本、筛选器、当前列表选择；外部状态必须经过 Observer。
- `.task` 仅用于 ViewModel 暴露的用户触发/一次性 UI 生命周期动作；不能成为外部状态的长期监听入口。

## 5. Provider 与事件规则

### 5.1 Provider 是事实来源，Observer 是插件入口

保留 Provider 的协议边界；不允许插件互相引用具体实现。需要新增外部输入时，优先：

1. 在对应 Provider 定义语义事件和可取消 `ObserverHandle`。
2. 在 Provider 实现中，在状态真正变化的位置发送事件。
3. 在插件自己的 `Observers/` 中订阅 Provider。
4. Observer 更新插件 ViewModel。

事件必须描述“发生了什么”，而不是要求消费者重新猜测原因。举例：`selectionChanged(scene:)`、`locationChanged(_)`、`assetChanged(_)`、`libraryChanged(totalCount:)` 优于一个没有 payload 的 `didChange`。

### 5.2 禁止把 No-op observer 当成完成

当前若 Provider 协议通过默认实现返回 `Noop...ObserverHandle`，会掩盖实现没有广播事件的问题。迁移时按 Provider 分类处理：

- 有真实外部状态的 Provider：删除默认 no-op，要求所有实现提供真实事件。
- 只有静态能力、无运行期状态的 Provider：不强行增加 Observer；插件无需为静态贡献创建空 Observer。
- 过渡期必须保留 no-op 时，至少增加测试确认当前实现确实会发送事件，并在迁移完成后删除兼容默认实现。

优先检查并落实：`ThemeProviding`、`StorageProviding`、`SceneProviding`、`PlaybackProviding`、`AudioLibraryProviding`、`CloudProviding`、`DeviceProviding`、`AppStateProviding`、`PluginProviding`、`ContentViewProviding`、`RootViewProviding`、`ToolbarProviding`、`ControlViewProviding`。

### 5.3 NotificationCenter 适配策略

NotificationCenter 不是禁止使用，而是禁止让 View 直接使用：

- 现有跨包通知暂时不能删除时，为每个插件建立 `*NotificationObserver`，集中解析 `userInfo`、过滤事件、处理线程和取消。
- 如果通知表达的是 Provider 状态，应优先把发送方改成 Provider 事件，再由插件订阅 Provider；通知只保留为兼容桥接。
- 同一状态不得同时由 View 的 `.onReceive` 和 Observer 更新。
- 新增功能不得再定义“全局无类型通知 + View 直接订阅”的路径。

## 6. 分阶段执行计划

### Phase 0：建立迁移基线

目标：先把所有外部输入列清楚，不立即改行为。

任务：

- 统计所有插件入口中对 Provider、Repository、Kernel、Plugin Host 的解析点。
- 统计所有非本地 UI 的 `.onReceive`、`.onChange`、`NotificationCenter.default.addObserver`、`NotificationCenter.publisher`、`EnvironmentObject` 和 `.task`。
- 为每个输入标注：来源、事件类型、当前消费者、目标 ViewModel、是否已有 Provider observer、是否需要新 Provider 事件。
- 明确每个插件的入口生命周期：`onBoot`、`onReady`、`onEnable`、`onDisable`、`onShutdown`。
- 建立迁移清单，后续每完成一个插件就删除该项的直接外部订阅。

验收：仓库中每个外部状态监听点都有归属插件、归属 Observer 和目标 ViewModel；没有“暂时不知道由谁负责”的监听。

### Phase 1：修正已有 Observer + ViewModel 插件

范围：`PluginScene`、`PluginStorage`、`PluginThemeSettings`。

任务：

- 保留现有 `Observers/` 和 `ViewModels/`，统一命名、事件映射和取消语义。
- 将 `SceneSettingsViewModel`、`StorageSettingsViewModel`、`ThemeSettingsViewModel` 的创建从 View 移到对应插件入口或长期存在的页面状态容器。
- 让 `SceneSettingsView`、`StorageSettingView`、`ThemeSettingsDetailView` 只接收 ViewModel；删除 View 中对 Provider 的直接读取和外部通知订阅。
- 处理 Provider 尚未注册或插件被禁用的情况：Observer 可安全停止，ViewModel 展示空/不可用状态。
- 测试重复 `attach`、`detach`、关闭后再启动不会产生重复回调。

验收：切换场景、存储位置、主题后，设置页不依赖重新打开窗口即可更新；插件禁用后不再收到事件。

### Phase 2：迁移音频主链路

范围：`PluginAudio`、`PluginAudioDBView`、`PluginAudioLike`。

建议拆分：

1. `AudioLibraryObserver`：订阅音频库 Provider、数据库同步/更新/删除事件，更新音频库页面 ViewModel。
2. `AudioStorageObserver`：订阅 Storage Provider，负责存储位置变化后的容器/目录状态和代际刷新。
3. `AudioLikeObserver`：订阅喜欢状态与播放状态，替代 `AudioLikeSettingsView` 和 `AudioLikeRootView` 的直接通知订阅。
4. `AudioDatabaseObserver`：将 `dbSynced`、`dbUpdated`、`dbDeleted`、排序完成等输入集中适配，View 仅观察列表 ViewModel。

任务：

- 将 `AudioRootView` 的容器、错误、加载和存储变化状态迁移到 `AudioRootViewModel` 或音频插件持有的等价状态对象。
- 将 `AudioList` 的加载、分页、当前选中项刷新、删除后的回读集中到 ViewModel/Observer 协作中。
- 删除 `AudioDBEventViews` 对外部数据库通知的直接消费；如果保留 View modifier，仅允许它转发 ViewModel 的内部 UI action，不得再做 Provider/数据库读取。
- 播放控制和播放模式页面订阅 `PlaybackProviding` 的语义事件，不直接依赖 `MagicPlayMan` 的 `@Published` 作为外部输入；播放器操作仍通过 Provider/action 执行。
- 保持现有后台数据库任务和 generation 防旧结果覆盖逻辑，迁移 Observer 时不能把数据库工作移回主线程。

验收：导入、删除、同步、切换存储位置、点赞/取消点赞、播放进度和当前资源变化都能更新对应页面；音频插件禁用/关闭后没有残留通知回调。

### Phase 3：迁移书籍主链路

范围：`PluginBook`、`PluginBookDBView`、`PluginBookProgress`、`PluginBookLike`、`PluginBookPlayMode`、`PluginBookControlButtons`、`PluginBookSettings`。

任务：

- 建立 `BookStorageObserver`、`BookDatabaseObserver`、`BookPlaybackObserver`、`BookProgressObserver` 等插件内 Observer。
- 将书籍存储变化、数据库同步/更新/删除、书籍状态进度更新和场景变化从 View 的 `.onReceive` / `.onChange` 移出。
- 将 `BookRootView` 的 repo/container/error/loading 状态改为入口持有的 ViewModel 或明确的根状态对象。
- 将 `BookGrid`、`BookTile` 的书籍状态刷新和恢复播放逻辑放到 Observer + ViewModel；View 只负责展示和发出播放意图。
- 进度保存继续在后台执行，Observer 只负责接收完成/失败结果并回主 actor 更新展示状态。

验收：导入、删除、排序、进度变化、切换场景和播放状态变化不会要求重新构建页面；书籍插件生命周期结束后所有监听器均取消。

### Phase 4：迁移系统、工具和基础设施插件

优先级：

1. `PluginPluginManager`：把启用状态变化从 View 的 `.onReceive` 移到 `PluginManagementObserver` + ViewModel。
2. `PluginDevice`：把设备指标采样/系统通知集中到 `DeviceMetricsObserver`，入口持有所有设备 ViewModel。
3. `PluginStore`：把交易、恢复购买、订阅状态事件集中到 Store observers 和 Store ViewModel。
4. `PluginAudioDBData`、`PluginAudioCopy`、`PluginStorage` 文件/迁移页面：把音频目录同步和迁移进度回调集中到数据协调器/Observer，View 只读任务状态。
5. `PluginAudioWidgetControl`、`PluginOpenButton`、`PluginReset`、`PluginWelcome` 等：逐项判断是否有持续外部状态；一次性用户动作不需要为了形式增加 Observer。

验收：所有持续外部状态都有明确 Observer；纯本地选择、搜索和动画状态保留在 View 或本地 ViewModel，不被过度抽象。

### Phase 5：清理直连路径并强化架构约束

任务：

- 在 `Packages/Plugin*/*/Views` 范围内搜索并逐项清理：
  - `NotificationCenter.default.publisher`
  - `NotificationCenter.default.addObserver`
  - `@Environment` Provider
  - 直接解析 `KernelCore` / `CisumKernel`
  - 直接调用 `PluginHost`、Repository 或 Provider 的外部状态读取
  - 处理外部状态的 `.onChange` / `.task`
- 允许保留的 View 代码必须有注释说明它是本地 UI 状态，而非外部状态监听。
- 删除不再需要的旧通知 modifier、重复回调、View 内刷新 helper 和兼容桥接。
- 为每个插件补充 README/架构注释，说明入口持有的 ViewModel 和 Observer，以及每个 Observer 的外部来源。
- 如果可行，增加静态检查脚本或 SwiftLint 规则，阻止新 View 直接订阅全局通知和 Provider。

## 7. 统一生命周期模板

每个需要外部状态的插件按以下语义实现，具体方法名以当前 `SuperPlugin` 协议为准：

```swift
@MainActor
public final class FooPlugin: SuperPlugin {
    private var viewModel: FooViewModel?
    private var observer: FooObserver?

    public func onBoot(kernel: CisumKernel) async throws {
        guard let provider = kernel.resolveProvider((any FooProviding).self) else {
            throw CisumKernelError.serviceNotAvailable(service: "FooProviding")
        }

        let viewModel = FooViewModel(/* actions/providers */)
        let observer = FooObserver(provider: provider, viewModel: viewModel)
        self.viewModel = viewModel
        self.observer = observer
    }

    public func onDisable(kernel: CisumKernel) async throws {
        observer?.cancel()
        observer = nil
        viewModel = nil
    }

    public func onShutdown(kernel: CisumKernel) async throws {
        observer?.cancel()
        observer = nil
        viewModel = nil
    }
}
```

如果 View 贡献可能在插件启动前被请求，入口必须提供一个稳定的状态容器或延迟绑定机制；不能通过 View 每次出现时重新创建 ViewModel 来掩盖生命周期顺序问题。

## 8. 并发与数据一致性要求

- Provider、Observer Handle、ViewModel 的 actor 隔离必须明确；当前 UI Provider 多为 `@MainActor`，不要为了形式把主 actor 状态对象搬到后台。
- 文件扫描、数据库容器创建、查询、网络、媒体元数据读取继续使用后台任务；后台任务只返回 `Sendable` 快照，回主 actor 更新 ViewModel。
- 每个可重入加载流程都要有 cancellation 或 generation token，旧结果不能覆盖新存储位置、新选中项或新页面状态。
- Observer 回调可能同步触发，因此先准备 ViewModel，再保存 Observer；取消必须幂等。
- Provider 事件回调中不要执行长时间同步工作；Observer 只做过滤/映射，重工作交给后台任务，结果再通过 ViewModel 应用。
- 不跨 actor 传递 `ModelContext`、SwiftUI View、`AnyView` 或未确认线程安全的 Repository 状态。

## 9. 测试与验收矩阵

### 单元测试

- 每个 Observer 对每种相关 Provider 事件都能调用正确的 ViewModel 更新方法。
- Observer 构造时能完成 initial sync。
- `cancel()` 后事件不再改变 ViewModel。
- 重复启动/关闭、启用/禁用不会重复订阅。
- 过期异步结果不会覆盖新 generation。

### 集成测试

- 启动 Kernel 后所有启用插件都完成 Observer 安装。
- Provider 缺失时插件能明确失败或展示不可用状态，不产生半初始化引用。
- Kernel shutdown 后没有活跃 Observer Handle、Notification token 或后台任务。
- 运行时启用/禁用插件后，Provider 状态和对应贡献能恢复/撤回。

### 手工验收

- 设置窗口：切换主题、场景、存储位置后当前页面立即更新。
- 音频：导入、删除、同步、点赞、取消点赞、切换歌曲和播放进度均能更新。
- 书籍：导入、删除、进度保存、恢复播放、切换场景均能更新。
- 插件管理：启用/禁用插件后列表和贡献即时更新。
- 关闭再打开设置窗口、切换页面、禁用再启用插件后不出现重复刷新或无响应。

## 10. 交付顺序与提交建议

建议按以下边界提交，方便另一个 agent 回滚和定位：

1. `refactor(kernelcore): enforce provider observer lifecycle`
2. `refactor(plugin-scene): move external state into observers`
3. `refactor(plugin-storage): move external state into observers`
4. `refactor(plugin-theme-settings): move external state into observers`
5. `refactor(audio): centralize external updates in observers`
6. `refactor(book): centralize external updates in observers`
7. `refactor(plugin-manager): observe plugin state through view model`
8. `refactor(plugins): remove direct external subscriptions from views`
9. `test(plugins): cover observer lifecycle and stale updates`

每个提交都只包含对应阶段的路径；提交前至少运行受影响包的 `swift build`、相关测试、`git diff --cached --check`，最后再运行完整 `xcodebuild`。

## 11. 完成定义

迁移完成必须同时满足：

- 所有持续外部状态都有插件级 Observer；
- 插件入口创建并持有 Observer 和 ViewModel，并在生命周期结束时取消；
- View 不直接订阅外部 NotificationCenter、不直接观察 Provider、不直接读取 Kernel/Repository 外部状态；
- Provider 事件是语义化、可取消、能覆盖当前状态变化的真实事件，而不是默认 no-op；
- 初始快照、后续变化、异步结果和错误都经过同一个 ViewModel 状态流；
- 启用/禁用、关闭/启动、设置窗口反复打开不会产生重复监听或旧状态覆盖；
- 受影响包、集成测试和完整 App 构建通过，并完成上述手工验收矩阵。
