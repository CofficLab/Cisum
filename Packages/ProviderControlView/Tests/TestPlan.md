# TestPlan — ProviderControlView

## 包概述

ProviderControlView 定义根布局顶部「播放控制区」的提供能力：各区块可由外部注入。状态区未注入时使用 `StateView`，其他播放区块未注入时不渲染。同时提供共享布局信号 `ControlHeroVisibility`。

核心组件:
- `ControlViewProviding` - 控制区能力协议(`@MainActor` + `ObservableObject`)
- `ControlViewProvidingEvent` - 事件枚举(`viewInvalidated`)
- `ControlViewProvidingObserverHandle` / `NoopControlViewProvidingObserverHandle`
- `DefaultControlViewProvider` - 默认实现(存储注入的区块视图并渲染 `ControlView`)
- `ControlHeroVisibility` - 播放器区呈现与否的共享布局信号(单例)
- `ControlView` / `StateView` - 内置视图

## 公开 API

### ControlViewProviding (协议)
- `makeControlView() -> AnyView`
- `setHeroView(_:)` / `setStateView(_:)` / `setProgressView(_:)` / `setControlButtonsView(_:)` / `setRightAlbumView(_:)`(默认扩展为 noop)
- `setDemoMode(_:)`(默认扩展 noop)
- `addObserver(_:) -> ControlViewProvidingObserverHandle`(默认返回 NoopHandle)

### DefaultControlViewProvider
- `heroView`/`stateView`/`progressView`/`controlButtonsView`/`rightAlbumView`/`isDemoMode`(均 `private(set)`)
- 各 `setXxxView(_:)` 存储/清除;`makeControlView()` 组装 `ControlView`

## 测试用例清单

| ID | 类别 | 描述 | 前置条件 | 操作步骤 | 预期结果 | 优先级 | 状态 | 测试方法 |
|----|------|------|----------|----------|----------|------|------|----------|
| 1 | 默认实现 | 各区块初始为 nil / demo=false,注入后存储,再传 nil 清除 | `DefaultControlViewProvider` | 注入 → 断言 → 清空 → 断言 | 槽位随注入/清除变化,可渲染 | P0 | ✅ 已覆盖 | `defaultProviderStoresAndClearsInjectedAreas` |
| 2 | 视图 | `StateView` 的 body 求值会执行消息与贡献闭包，包括 demo 模式 | - | 对 demo / 非 demo 组合求值 body | demo 中两个闭包各调用 1 次；未验证最终可见视图 | P1 | ✅ 已覆盖 | `stateViewSuppressesMessagesAndContributionsInDemoMode` |
| 3 | 协议 | 轻量替身默认观察者返回 NoopHandle、setter 为 noop 且安全 | 仅实现 `makeControlView` 的替身 | 调各 set* + addObserver → cancel ×2 | 返回 NoopHandle,不崩溃 | P0 | ✅ 已覆盖 | `lightweightProviderDefaultsRemainNoopAndSafe` |
| 4 | 信号 | `ControlHeroVisibility.shared` 默认 `isVisible == true`,可切换 | - | 读默认值并改写 | 初值 true,可更新并发布变化 | P1 | ❌ 缺失 | - |
| 5 | 事件 | 视图失效时广播 `viewInvalidated` | 具体实现/宿主 | 触发失效并订阅 | 观察者收到 `.viewInvalidated` | P2 | ❌ 缺失 | - |

> 说明:`ControlViewProvidingEvent.viewInvalidated` 与 `ControlHeroVisibility` 由宿主/封面插件驱动;本包提供协议、默认实现与内置视图。

## 覆盖率统计

- P0: 已覆盖 2 / 2
- P1: 已覆盖 1 / 2
- P2: 已覆盖 0 / 1
- **合计: 3 / 5**

## 优先级说明

- **P0**: 默认实现的注入/清除、替身协议兜底
- **P1**: 视图渲染分支、共享布局信号
- **P2**: 事件广播

## 跨平台说明

- SwiftUI 视图在 iOS 17+ / macOS 14+ 均可用;`@MainActor` 约束要求主线程

## 测试执行

```bash
cd Packages/ProviderControlView
swift test
```

## 维护规则

1. **新增公开 API** → 先在 TestPlan 登记测试用例,再写实现
2. **Bug 修复** → 追加回归用例,标注触发条件
3. **删除用例** → 在 commit message 说明理由
4. **状态同步** → 实现后更新 TestPlan,标记 ✅ 并填写测试方法名
