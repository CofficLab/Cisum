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
5. **可见性**：能力协议默认 `internal`；仅当该能力需被本包 `Tests` 使用时才提为 `public`。跨插件共享的能力不属于本机制，应下沉为 `Provider*` / `Kit*` 包。
6. **禁止循环**：Adapter 可依赖 `Provider*` 包；Provider 包**不得**反向依赖插件。

---

## 5. 是否该建 Capability（判断标准）

**应当建**：
- View / ViewModel / Observer 直接持有 `any XxxProviding`
- 同一 Provider 在插件内有 2 处以上消费点
- 单元测试需要 mock 掉某个外部能力

**不必建**：
- 只有插件入口（`<Plugin>.swift`）消费 Provider —— 入口本就是组装层，直接 resolve 即可
- 只有单个 Observer 消费、且仅转发一次事件

---

## 6. 渐进迁移

本规范**不要求**一次性改造全部插件。新增或重构插件时遵守；既有插件在触及相关文件时顺手迁移即可。

当前存在「非入口文件直接依赖 `any *Providing`」且适合优先改造的包：
`PluginPlayBack`、`PluginStorage`、`PluginBookDBView`、`PluginAudioDBView`。

---

## 检查清单

新增/改造插件时，确认：

- [ ] View / ViewModel / Observer 不直接持有 `any *Providing`
- [ ] 能力协议只声明用到的成员
- [ ] 未泄漏 Provider 的 `*ObserverHandle` 与事件类型
- [ ] Adapter 在插件入口 `onBoot` 中创建并注入
- [ ] Adapter 持有 Provider 用 `weak`
- [ ] 能力文件放在 `Capabilities/`（而非 `Providers/`）
- [ ] 命名符合 `<Plugin前缀><Domain>Capability` / `Adapter`

---

## 相关规范

- [插件包目录结构规范](./plugin-package-structure.md) — `Sources/` 分层与包裹目录
- [插件国际化规范](./plugin-i18n-rules.md) — xcstrings 文件管理
- [日志记录规范](./swift-log.md) — Swift 日志记录标准