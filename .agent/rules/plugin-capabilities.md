# 插件 Capabilities 能力边界规范

> 本规范定义 Cisum 插件如何声明自己**消费外部能力**的最小边界。
> 参考兄弟项目 Lumi 的同名机制，核心目的：让 View / ViewModel 不再直接依赖 `any *Providing` 宽接口。

---

## 核心原则

**插件依赖的是「自己声明的窄能力」，不是「内核的宽 Provider」。**

一个插件对外界（内核 Provider、其他插件的 Provider）的所有依赖，都应收敛到本插件 `Capabilities/` 目录下的
`protocol XxxCapability` + `XxxCapabilityAdapter`。View / ViewModel / Observer 只面向该窄协议编程。

---

## 1. 目录位置

| 包结构 | 位置 |
|--------|------|
| 无包裹目录（`path: "."` + `sources: ["Sources"]`，当前多数插件） | `Sources/Capabilities/` |
| 有包裹目录（`Sources/<PackageName>/`，如 `PluginPlayBack`） | `Sources/<PackageName>/Capabilities/` |

每个能力一个文件，文件名 = 主类型名，例如 `PlaybackSettingsCapability.swift`。

---

## 2. 与 `Providers/` 的区别（关键，别混淆）

Cisum 中两个目录方向**相反**：

| 目录 | 方向 | 内容 | 例 |
|------|------|------|------|
| `Providers/` | **生产**：本插件向外**提供**能力 | 实现内核的 `*Providing` 协议 | `PluginStorage/Providers/StorageProvider.swift` |
| `Capabilities/` | **消费**：本插件向**内**索取能力 | 声明本插件**需要的**窄接口 + Adapter | `PluginStorage/Capabilities/StorageSettingsCapability.swift` |

一句话：`Providers/` 是我给别人什么，`Capabilities/` 是我需要什么。

---

## 3. 标准写法

```swift
import ProviderScene

/// 设置页所需的最小场景能力。
///
/// 收敛 `SceneProviding`，View 与 ViewModel 不再直接接触 Provider。
@MainActor
protocol PlaybackSettingsSceneCapability: AnyObject {
    /// 当前选中场景；nil 表示尚未恢复。
    var currentScene: AppScene? { get }

    /// 订阅场景切换；返回句柄需自行 cancel。
    @discardableResult
    func addObserver(_ callback: @escaping (AppScene?) -> Void) -> any PlaybackSettingsSceneObserverHandle
}

/// 将内核 `SceneProviding` 收窄为本插件能力。
@MainActor
final class PlaybackSettingsSceneCapabilityAdapter: PlaybackSettingsSceneCapability {
    // Provider 宽接口只存在于 Adapter 内部
    private weak var scene: (any SceneProviding)?

    init(scene: (any SceneProviding)?) {
        self.scene = scene
    }

    var currentScene: AppScene? { scene?.currentScene }

    @discardableResult
    func addObserver(_ callback: @escaping (AppScene?) -> Void) -> any PlaybackSettingsSceneObserverHandle {
        ...
    }
}
```

### 命名规范

| 角色 | 命名 |
|------|------|
| 协议 | `<Plugin前缀><Domain>Capability`，如 `GitProjectCapability`、`StorageSettingsCapability` |
| 适配器 | 协议名 + `Adapter`，如 `GitProjectCapabilityAdapter` |
| 事件枚举 | `<Domain>Event`，如 `PendingMessageSendingEvent` |
| 观察句柄 | `<Domain>ObserverHandle`，如 `PendingMessageSendingObserverHandle` |

> 多个能力共用同一 Provider 时，前缀区分用途而非 Provider 本身
> （如 `MessageListMessageCapability` 与 `MessageListConversationCapability`）。

---

## 4. 规则

1. **收窄优先**：能力协议只声明实际用到的成员，禁止把 Provider 整个协议照抄一遍。
2. **不泄漏句柄类型**：Provider 的 `*ObserverHandle` 不应出现在能力协议里；需在能力文件内**内联定义**自己的事件枚举与句柄协议（见 Lumi `PendingMessageSendingCapability`）。
3. **装配只在插件入口**：Adapter 一律在 `<Plugin>.swift` 的 `onBoot(kernel:)` 中创建并注入 ViewModel / Observer。
4. **持有用 `weak`**：Adapter 持有 Provider 时默认 `private weak var`，避免 Provider 已被 unregister 时仍被强引用。
5. **⚠️ 入口必须强持有 Adapter**：`weak` 持有是消费侧的规则，但 Adapter 本身的**所有者是插件入口**。若入口只是 `makeXxxCapability(kernel:).init(...)` 临时创建后直接注入，Adapter 会随调用返回立即释放，消费方的 `weak` 全部落空（功能静默失效）。

```swift
// ❌ 错误：Adapter 无人持有，方法返回即释放
let viewModel = MyViewModel(capability: MyCapabilityAdapter(provider: provider))

// ✅ 正确：入口持有 Adapter，并在 shutdown 释放
private var capability: MyCapabilityAdapter?
let capability = MyCapabilityAdapter(provider: provider)
self.capability = capability
let viewModel = MyViewModel(capability: capability)
```

6. **可见性**：能力协议默认 `internal`；仅当该能力需被本包 `Tests` 使用时才提为 `public`。跨插件共享的能力不属于本机制，应下沉为 `Provider*` / `Kit*` 包。
7. **禁止循环**：Adapter 可依赖 `Provider*` 包；Provider 包**不得**反向依赖插件。

---

## 5. 是否该建 Capability（判断标准）

**应当建**：
- View / ViewModel / Observer 直接持有 `any XxxProviding`（**无论成员多少**——消费面小不等于可以绕过边界）
- 同一 Provider 在插件内有 2 处以上消费点
- 入口注入的多个闭包各自 `resolveProvider` 同一个 Provider（收敛为一个能力，解析与降级语义只留一份）
- 单元测试需要 mock 掉某个外部能力

**不必建**（豁免项必须在代码中写注释说明理由）：
- 只有插件入口（`<Plugin>.swift`）消费 Provider —— 入口本就是组装层，直接 resolve 即可
- `Providers/` 生产目录内的文件 —— 那是本插件**实现** Provider 的地方及其基础设施依赖
- 一次性同步读取的闭包（如恢复进度时读一次 `isLiked`）、纯诊断快照（如
  `AudioStorageDiagnosticsFactory`）—— 不订阅、不持有、不重试
- 组装层 View 中「`resolveProvider` 后立刻包成 Adapter」的调用 —— View 在此角色等同入口
  （如 `PluginRootView/CisumRootLayoutView`），但必须在调用点注释说明组装层身份

---

## 6. 消费方持有样式

| 持有者 | 样式 | 理由 |
|--------|------|------|
| Adapter → Provider | **`weak`**（硬规则） | Provider 可能已被 unregister，不得延长其生命周期 |
| 插件入口 → Adapter | **强持有**（硬规则，见第 4 节第 5 条） | 组装层所有权；teardown 时随状态一起释放 |
| ViewModel / View → Adapter | **默认强持有 `let`** | 能力是容器的普通依赖；容器生命周期由入口 teardown 控制（先置空容器再释放能力）。强持有不会延长 Provider 生命周期（Adapter 对 Provider 已 `weak`），且消除了「临时 Adapter 被释放 → 能力静默失效」的陷阱 |
| Observer → Adapter | 不持有 | 观察者只在 `init` 期间用能力安装订阅，之后仅依赖返回的句柄 |

> 例外：若消费容器可能**长寿于**组装层（如 StateObject 之外的跨会话缓存），可改 `weak`，
> 但必须在注释中说明为何组装层的强持有不足。

**测试陷阱**：Adapter 对 Provider 是 `weak`，测试中
`MyCapabilityAdapter(probe: MyProbe())` 这种临时 Provider 会在初始化后立即释放，
能力退化为空值。测试必须自己持有 Probe 与 Adapter（与生产路径的第 5 条同源）。

---

## 7. 惰性解析场景

当 Provider 的注册时机**晚于**本插件的视图贡献请求（跨插件 boot 顺序不确定），
不要在插件入口把 Provider **快照**进 Adapter——快照会永久失效。

正确做法：让 Adapter 内部持**惰性解析闭包**，每次调用都重新 `resolveProvider`：

```swift
@MainActor
public final class XxxCapabilityAdapter: XxxCapability {
    private let resolve: @MainActor @Sendable () -> (any XxxProviding)?

    public init(resolve: @escaping @MainActor @Sendable () -> (any XxxProviding)?) {
        self.resolve = resolve
    }

    private var provider: (any XxxProviding)? { resolve() }
    public var value: Int { provider?.value ?? 0 }
}
```

这样「仓库不可用」的判断也要跟着改——原代码靠**闭包返回 nil** 判断，
现在闭包被收进能力内部，应改判能力的 `isAvailable` / 空值语义。

**注意 Sendable**：若 ViewModel 在 `Task { @MainActor in }` 跨闭包使用能力，
能力协议需精化 `Sendable`（与内核 Provider 保持一致）。

---

## 8. 迁移状态与验证

### 已完成迁移（可作为参考实现）

全部 36 个带测试的插件包已迁移完毕（2026-10 全量批次），按模式归类：

| 模式 | 参考插件 |
|------|---------|
| 多 Provider 合并为「环境能力」（信号合并，非数据） | `PluginAudioControlButtons`、`PluginAudioProgress`、`PluginRootView` |
| 信号 vs 数据的区分（需要数据的 Provider 不合并） | `PluginPlaybackHero`（需要 `totalCount` 数据） |
| 惰性解析闭包（Provider 注册晚于视图请求） | `PluginAudioDBView`、`PluginAudioProgress`、`PluginAudioLike`、`PluginAudioCopy` |
| 入口注入的多个闭包收敛为单一能力 | `PluginAudioWidgetControl`（4 闭包）、`PluginBookProgress`（6 闭包）、`PluginBookLike`/`PluginAudioLike`（本地 Store 闭包保留） |
| 生产方收窄自己的契约（保留写入能力） | `PluginScene` |
| 消费边与生产边分离（自产自销的 Provider） | `PluginAudioLike`（自己注册 `AudioLikeProviding`，消费侧同样收窄） |
| 纯信号 Observer（无读取） | `PluginAudioSettings`、`PluginBookSettings`、`PluginAudioDBData` |
| View 组装层 | `PluginRootView`（View 构造 Adapter 并注释组装层身份） |

### 验证扫描命令

```bash
cd Packages && for p in Plugin*/; do n=$(basename $p); [ -d "$p/Sources" ] || continue
  files=$(grep -rlE "any [A-Z][A-Za-z]*Providing" "$p/Sources" --include="*.swift" 2>/dev/null \
    | grep -v "/Capabilities/" | grep -vE "Plugin\.swift$")
  c=$(echo "$files" | grep -c .)
  [ "$c" != "0" ] && { echo "-- $n"; echo "$files" | sed "s|$p/Sources/||"; }
done
```

> **注意用宽模式 `any XxxProviding`，不要用 `(any ...`**——带括号的窄模式会漏掉
> `init(provider: any StorageProviding)` 这类无括号签名，首次扫描因此漏掉 6 个插件。

**当前允许的输出**（均须有代码注释说明理由）：
- `Providers/` 与 `Services/` 下的 Provider 实现文件（生产目录，含其基础设施依赖）
- 插件入口 `*Plugin.swift` / `*Manager.swift`（组装层）
- `AudioStorageDiagnosticsFactory`（一次性诊断快照）
- `AudioProgressViewModel` 的 `audioLike` 闭包（恢复时一次性读取）
- `CisumRootLayoutView`（组装层 View，`resolveProvider` 后立即包成 Adapter）

### 回归

新增/改动后对全部插件包跑测试（一次约 4 分钟）：

```bash
cd Packages && for p in Plugin*/; do [ -d "$p/Tests" ] || continue
  printf "%-26s " "$(basename $p)"; (cd $p && swift test 2>&1 | grep -E "✘|error:|Test run with" | tail -1)
done
```

---

## 检查清单

新增/改造插件时，确认：

- [ ] View / ViewModel / Observer 不直接持有 `any *Providing`
- [ ] 能力协议只声明用到的成员
- [ ] 未泄漏 Provider 的 `*ObserverHandle` 与事件类型
- [ ] Adapter 在插件入口 `onBoot` 中创建并注入
- [ ] Adapter 持有 Provider 用 `weak`
- [ ] **插件入口显式强持有 Adapter，并在 shutdown 释放**
- [ ] 能力文件放在 `Capabilities/`（而非 `Providers/`）
- [ ] 命名符合 `<Plugin前缀><Domain>Capability` / `Adapter`
- [ ] 收窄后保留「Provider 缺失时的降级语义」——原代码靠 `provider == nil` / 闭包返回 nil
      判断的可用性，要在能力上以 `isAvailable` / 空值语义显式承载，避免 UI 在启动早期误闪
- [ ] 消费方持有样式符合第 6 节表格（VM/View 默认强持有能力，入口强持有为硬要求）
- [ ] 包若使用**逐目录列举**的 `sources:` 清单（如 `PluginAudio`、`PluginBook`、`PluginAudioLike`），
      新建 `Sources/Capabilities` 后需同步加入清单，否则能力文件不会被编译

---

## 相关规范

- [插件包目录结构规范](./plugin-package-structure.md) — `Sources/` 分层与包裹目录
- [插件国际化规范](./plugin-i18n-rules.md) — xcstrings 文件管理
- [日志记录规范](./swift-log.md) — Swift 日志记录标准