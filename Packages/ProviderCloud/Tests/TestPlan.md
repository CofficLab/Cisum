# TestPlan — ProviderCloud

## 包概述

ProviderCloud 提供 iCloud 云同步服务能力,包装 iCloud 可用性和账户状态变化通知。

核心组件:
- `CloudProviding` - 云同步服务协议
- `CloudProvidingEvent` - 云状态变更事件枚举
- `CloudProvidingObserverHandle` - 观察者句柄协议
- `NoopCloudProvidingObserverHandle` - 默认空实现
- 扩展: `EventObserverHandle` 遵循 `CloudProvidingObserverHandle`

## 公开 API

### CloudProvidingEvent (枚举)
- `availabilityChanged(isICloudAvailable: Bool, isSignedIn: Bool?)` - iCloud 可用性变更

### CloudProvidingObserverHandle (协议)
- `cancel()` - 取消观察

### CloudProviding (协议)
属性:
- `isICloudAvailable: Bool` - iCloud 是否可用
- `isSignedIn: Bool?` - 是否已登录 iCloud 账户(nil 表示未确定)
- `accountStatusDescription: String` - 账户状态的可读描述

方法:
- `addObserver(_:) -> CloudProvidingObserverHandle` - 注册观察者(默认返回 NoopHandle)

### NoopCloudProvidingObserverHandle
- `init()` - 初始化
- `cancel()` - 取消观察(幂等)

## 测试用例清单

| ID | 类别 | 描述 | 前置条件 | 操作步骤 | 预期结果 | 状态 | 测试方法 |
|----|------|------|----------|----------|----------|------|----------|
| 1 | 观察者 | 默认 addObserver 返回 NoopHandle | - | 调用 `addObserver { _ in }` | 返回 `NoopCloudProvidingObserverHandle` | ✅ 已覆盖 | `defaultObserverUsesNoopFallback` |
| 2 | 观察者 | NoopHandle 可重复取消 | - | 调用 `cancel()` 两次 | 不崩溃 | ✅ 已覆盖 | `explicitNoopHandleSupportsRepeatedCancellation` |
| 3 | 观察者 | 观察者能收到状态变更事件 | 实现协议的 stub | 注册观察者,触发 `availabilityChanged` | 收到事件 | ✅ 已覆盖 | `observerReceivesAvailabilityChangedEvents` |
| 4 | 观察者 | 取消后不再收到事件 | 已注册观察者 | 调用 `cancel()` 后触发事件 | 不再收到事件 | ✅ 已覆盖 | `observerStopsReceivingEventsAfterCancellation` |
| 5 | 观察者 | 多个观察者同时收到事件 | 注册 2 个观察者 | 触发事件 | 两个观察者都收到事件 | ✅ 已覆盖 | `multipleObserversReceiveEvents` |
| 6 | 观察者 | EventObserverHandle 可作为 CloudProvidingObserverHandle | - | 用 KitEventObservation 的 handle | 能编译、能调 cancel | ✅ 已覆盖 | `eventObserverHandleCanBeUsedAsCloudProvidingObserverHandle` |
| 7 | 属性 | Stub 实现返回预期初始值 | - | 检查各属性 | 返回预设值 | ✅ 已覆盖 | `stubImplementationReturnsExpectedInitialValues` |
| 8 | 属性 | isICloudAvailable 默认为 false | - | 检查 `isICloudAvailable` | `false` | ✅ 已覆盖 | `isICloudAvailableDefaultsToFalse` |
| 9 | 属性 | isSignedIn 默认为 nil | - | 检查 `isSignedIn` | `nil` | ✅ 已覆盖 | `isSignedInDefaultsToNil` |
| 10 | 属性 | accountStatusDescription 默认为 "unknown" | - | 检查 `accountStatusDescription` | `"unknown"` | ✅ 已覆盖 | `accountStatusDescriptionDefaultsToUnknown` |
| 11 | 事件 | availabilityChanged 事件包含正确的可用性信息 | - | 发送事件 | 事件包含 `isICloudAvailable` 和 `isSignedIn` | ✅ 已覆盖 | `availabilityChangedEventContainsCorrectInformation` |

## 覆盖率统计

- P0 (核心功能): 6/6 ✅
- P1 (边界情况): 5/5 ✅
- P2 (集成场景): 0/0

**总计: 11/11 (100%)**

## 优先级说明

- **P0**: 核心功能,必须覆盖(观察者模式、默认实现)
- **P1**: 属性和事件,建议覆盖(初始值、事件结构)
- **P2**: 集成场景,可选覆盖

## 跨平台说明

- 所有功能在 iOS 和 macOS 上行为一致
- iCloud 可用性依赖系统 API,但协议本身跨平台

## 测试执行

```bash
cd Packages/ProviderCloud
swift test
```

## 维护规则

1. **新增公开 API** → 先在 TestPlan 登记测试用例,再写实现
2. **Bug 修复** → 追加回归用例,标注触发条件
3. **删除用例** → 在 commit message 说明理由
4. **状态同步** → 实现后更新 TestPlan,标记 ✅ 并填写测试方法名
