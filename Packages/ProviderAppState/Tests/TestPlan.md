# TestPlan — ProviderAppState

## 包概述

ProviderAppState 提供应用级状态管理服务,包括 Demo 模式、数据库视图、导入/拖放状态和状态消息。

核心组件:
- `AppStateProviding` - 应用状态服务协议
- `AppStateProvidingEvent` - 状态变更事件枚举
- `AppStateProvidingObserverHandle` - 观察者句柄协议
- `NoopAppStateProvidingObserverHandle` - 默认空实现
- 扩展: `EventObserverHandle` 遵循 `AppStateProvidingObserverHandle`

## 公开 API

### AppStateProvidingEvent (枚举)
- `demoModeChanged(Bool)` - Demo 模式变更
- `dbViewVisibilityChanged(Bool)` - 数据库视图显隐变更
- `importingChanged(Bool)` - 导入状态变更
- `droppingChanged(Bool)` - 拖放状态变更
- `stateMessageChanged(String)` - 状态消息变更

### AppStateProvidingObserverHandle (协议)
- `cancel()` - 取消观察

### AppStateProviding (协议)
属性:
- `isDemoMode: Bool` - 是否处于 Demo 模式
- `isDBViewVisible: Bool` - 数据库视图是否可见
- `isImporting: Bool` - 是否正在导入
- `isDropping: Bool` - 是否有拖放操作
- `hasDragOperation: Bool` - 是否有拖放/拖拽操作
- `stateMessage: String` - 当前状态消息

方法:
- `enterDemoMode()` - 进入 Demo 模式
- `exitDemoMode()` - 退出 Demo 模式
- `showDBView()` - 显示数据库视图
- `hideDBView()` - 隐藏数据库视图
- `closeDBView()` - 关闭数据库视图
- `toggleDBView()` - 切换数据库视图显隐
- `setImporting(_ importing: Bool)` - 设置导入状态
- `setDragOperation(_ active: Bool)` - 设置拖放状态
- `appendStateMessage(_ message: String)` - 追加状态消息
- `clearStateMessages()` - 清空状态消息
- `addObserver(_:) -> AppStateProvidingObserverHandle` - 注册观察者 (默认返回 NoopHandle)

### NoopAppStateProvidingObserverHandle
- `init()` - 初始化
- `cancel()` - 取消观察 (幂等)

## 测试用例清单

| ID | 类别 | 描述 | 前置条件 | 操作步骤 | 预期结果 | 状态 | 测试方法 |
|----|------|------|----------|----------|----------|------|----------|
| 1 | 观察者 | 默认 addObserver 返回 NoopHandle | - | 调用 `addObserver { _ in }` | 返回 `NoopAppStateProvidingObserverHandle` | ✅ 已覆盖 | `defaultObserverRegistrationReturnsSafeNoopHandle` |
| 2 | 观察者 | NoopHandle 可重复取消 | - | 调用 `cancel()` 两次 | 不崩溃 | ✅ 已覆盖 | `explicitNoopObserverHandleCanBeCancelledRepeatedly` |
| 3 | 观察者 | 观察者能收到状态变更事件 | 实现协议的 stub | 注册观察者,调用 `enterDemoMode()` | 收到 `demoModeChanged(true)` | ✅ 已覆盖 | `observerReceivesStateChangeEvents` |
| 4 | 观察者 | 取消后不再收到事件 | 已注册观察者 | 调用 `cancel()` 后触发状态变更 | 不再收到事件 | ✅ 已覆盖 | `observerStopsReceivingEventsAfterCancellation` |
| 5 | 观察者 | 多个观察者同时收到事件 | 注册 2 个观察者 | 触发状态变更 | 两个观察者都收到事件 | ✅ 已覆盖 | `multipleObserversReceiveEvents` |
| 6 | 观察者 | EventObserverHandle 可作为 AppStateProvidingObserverHandle | - | 用 KitEventObservation 的 handle | 能编译、能调 cancel | ✅ 已覆盖 | `eventObserverHandleCanBeUsedAsAppStateProvidingObserverHandle` |
| 7 | 状态 | Stub 实现返回预期状态值 | - | 检查各属性 | 返回预设值 | ✅ 已覆盖 | `stubImplementationReturnsExpectedStateValues` |
| 8 | 状态 | enterDemoMode 切换状态 | 已启动 | 调用 `enterDemoMode()` | `isDemoMode == true` | ✅ 已覆盖 | `enterDemoModeChangesState` |
| 9 | 状态 | exitDemoMode 切换状态 | Demo 模式已开启 | 调用 `exitDemoMode()` | `isDemoMode == false` | ✅ 已覆盖 | `exitDemoModeChangesState` |
| 10 | 状态 | showDBView 切换状态 | - | 调用 `showDBView()` | `isDBViewVisible == true` | ✅ 已覆盖 | `showDBViewChangesState` |
| 11 | 状态 | hideDBView 切换状态 | DBView 已显示 | 调用 `hideDBView()` | `isDBViewVisible == false` | ✅ 已覆盖 | `hideDBViewChangesState` |
| 12 | 状态 | toggleDBView 切换状态 | - | 调用 `toggleDBView()` 两次 | 状态从 false → true → false | ✅ 已覆盖 | `toggleDBViewChangesState` |
| 13 | 状态 | setImporting 设置导入状态 | - | 调用 `setImporting(true)` | `isImporting == true` | ✅ 已覆盖 | `setImportingChangesState` |
| 14 | 状态 | setDragOperation 设置拖放状态 | - | 调用 `setDragOperation(true)` | `isDropping == true`, `hasDragOperation == true` | ✅ 已覆盖 | `setDragOperationChangesState` |
| 15 | 状态 | appendStateMessage 追加消息 | - | 调用 `appendStateMessage("test")` | `stateMessage` 包含 "test" | ✅ 已覆盖 | `appendStateMessageChangesState` |
| 16 | 状态 | clearStateMessages 清空消息 | 已有状态消息 | 调用 `clearStateMessages()` | `stateMessage` 为空 | ✅ 已覆盖 | `clearStateMessagesChangesState` |
| 17 | 兼容性 | hasDragOperation 兼容 isDropping | - | 检查 `hasDragOperation` | 等于 `isDropping` | ✅ 已覆盖 | `hasDragOperationIsCompatibleWithIsDropping` |

## 覆盖率统计

- P0 (核心功能): 6/6 ✅
- P1 (边界情况): 11/11 ✅
- P2 (集成场景): 0/0

**总计: 17/17 (100%)**

## 优先级说明

- **P0**: 核心功能,必须覆盖(观察者模式、默认实现)
- **P1**: 状态管理,建议覆盖(各状态切换方法)
- **P2**: 兼容性,可选覆盖(别名方法)

## 跨平台说明

- 所有功能在 iOS 和 macOS 上行为一致
- 无平台特定代码

## 测试执行

```bash
cd Packages/ProviderAppState
swift test
```

## 维护规则

1. **新增公开 API** → 先在 TestPlan 登记测试用例,再写实现
2. **Bug 修复** → 追加回归用例,标注触发条件
3. **删除用例** → 在 commit message 说明理由
4. **状态同步** → 实现后更新 TestPlan,标记 ✅ 并填写测试方法名
