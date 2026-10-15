# TestPlan — ProviderScene

## 包概述

ProviderScene 管理应用「场景」(音乐库 / 有声书)的激活切换与持久化恢复。场景为内置固定枚举,不再由插件动态贡献。

核心组件:
- `AppScene` - 固定场景枚举(String / CaseIterable / Sendable / Codable / Identifiable)
- `SceneProviding` - 场景服务能力协议(`@MainActor` + `ObservableObject`)
- `SceneProvidingEvent` - 场景变更事件枚举(`selectionChanged`)
- `SceneProvidingObserverHandle` - 观察者句柄协议
- `NoopSceneProvidingObserverHandle` - 默认空实现

## 公开 API

### AppScene (枚举)
- Cases: `music`("Music Library")、`audiobooks`("Audiobooks")
- `id: String` / `accessibilityID: String` / `displayName: String`
- `iconName: String`(`music.note.list` / `book.closed`)
- `order: Int`(music=0, audiobooks=1)

### SceneProviding (协议, `@MainActor`)
属性:
- `scenes: [AppScene]`
- `currentScene: AppScene?`

方法:
- `setCurrentScene(_:)`
- `restoreCurrentScene()`(无记录/失效时回落首个场景)
- `addObserver(_:) -> SceneProvidingObserverHandle`(`@discardableResult`,默认返回 NoopHandle)

### SceneProvidingEvent (枚举, `@MainActor`)
- `selectionChanged(scene: AppScene?)`

## 测试用例清单

| ID | 类别 | 描述 | 前置条件 | 操作步骤 | 预期结果 | 优先级 | 状态 | 测试方法 |
|----|------|------|----------|----------|----------|------|------|----------|
| 1 | 枚举 | rawValue / id / displayName / iconName / order 稳定 | - | 逐项检查 | 返回预设值 | P0 | ✅ 已覆盖 | `appScenesKeepStablePersistenceAndPresentationValues` |
| 2 | 枚举 | Codable 往返一致 | - | encode → decode | 等于原值 | P0 | ✅ 已覆盖 | `appScenesKeepStablePersistenceAndPresentationValues` |
| 3 | 注册 | Kernel 未注册时解析为 nil | - | `resolveProvider` | `nil` | P0 | ✅ 已覆盖 | `kernelSceneAccessorResolvesRegisteredProvider` |
| 4 | 注册 | 注册后能解析出 provider 的 currentScene / scenes | 注册替身 | 注册后 resolve | 返回替身值 | P0 | ✅ 已覆盖 | `kernelSceneAccessorResolvesRegisteredProvider` |
| 5 | 注册 | 重复注册需先显式注销 | 已注册 | 二次注册 | 抛 `KernelCoreError`;注销后可重注册 | P1 | ✅ 已覆盖 | `duplicateRegistrationRequiresExplicitUnregister` |
| 6 | 观察者 | 默认 addObserver 返回 NoopHandle | 未实现协议的替身 | 调 `addObserver { _ in }` | 返回 `NoopSceneProvidingObserverHandle` | P0 | ✅ 已覆盖 | `defaultObserverUsesNoopFallback` |
| 7 | 观察者 | NoopHandle 可重复取消 | - | 调 `cancel()` 两次 | 不崩溃 | P0 | ✅ 已覆盖 | `defaultObserverUsesNoopFallback` / `explicitNoopHandleSupportsRepeatedCancellation` |
| 8 | 能力 | setCurrentScene 更新当前场景并持久化 | 具体实现 | 切换到另一场景 | `currentScene` 更新且持久化 | P1 | ❌ 缺失 | - |
| 9 | 能力 | restoreCurrentScene 无记录时回落首个场景 | 具体实现 | 空记录调用恢复 | `currentScene == scenes.first` | P1 | ❌ 缺失 | - |
| 10 | 事件 | selectionChanged 事件在切换后广播 | 具体实现 | 注册观察者后切换 | 回调收到 `.selectionChanged` | P1 | ❌ 缺失 | - |

> 说明:本包仅提供协议与默认 noop 观察者;用例 8-10 依赖场景 Provider 的具体实现(位于宿主/内核装配层)。

## 覆盖率统计

- P0: 已覆盖 6 / 6
- P1: 已覆盖 1 / 4
- **合计: 7 / 10**

## 优先级说明

- **P0**: 枚举契约、Kernel 注册解析、默认观察者兜底
- **P1**: 场景切换/恢复/事件广播等实现路径
- **P2**: 性能/便利性,可选

## 跨平台说明

- iOS 17+ / macOS 14+ 行为一致;`AppScene` 为纯 Swift 枚举
- 场景持久化依赖 `UserDefaults`,跨平台语义一致

## 测试执行

```bash
cd Packages/ProviderScene
swift test
```

## 维护规则

1. **新增公开 API** → 先在 TestPlan 登记测试用例,再写实现
2. **Bug 修复** → 追加回归用例,标注触发条件
3. **删除用例** → 在 commit message 说明理由
4. **状态同步** → 实现后更新 TestPlan,标记 ✅ 并填写测试方法名
