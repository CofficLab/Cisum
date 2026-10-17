# TestPlan — KitAppEvents

## 包概述

应用事件总线：`EventManager` 负责事件的注册、发布与订阅，`EventObserverStore` 提供同步投递的观察者存储。

公开类型:
- `CisumKernelEvent`
- `EventManager`

## 测试用例清单

下表由 `Tests/` 下的真实 `@Test` 声明自动生成，方法名与代码一一对应。

| ID | 类别 | 描述 | 优先级 | 状态 | 测试文件 | 测试方法 |
|----|------|------|--------|------|----------|----------|
| 1 | 行为 | Post delivers notification with payload | P0 | ✅ 已覆盖 | `EventManagerTests.swift` | `EventManagerTests.postDeliversNotificationWithPayload` |
| 2 | 行为 | Post theme did change uses stable notification name | P0 | ✅ 已覆盖 | `EventManagerTests.swift` | `EventManagerTests.postThemeDidChangeUsesStableNotificationName` |
| 3 | 状态 | Post playback state did change carries is playing payload | P0 | ✅ 已覆盖 | `EventManagerTests.swift` | `EventManagerTests.postPlaybackStateDidChangeCarriesIsPlayingPayload` |
| 4 | 行为 | Post playback progress did update carries numeric payload | P0 | ✅ 已覆盖 | `EventManagerTests.swift` | `EventManagerTests.postPlaybackProgressDidUpdateCarriesNumericPayload` |
| 5 | 行为 | Post app lifecycle did change carries phase payload | P0 | ✅ 已覆盖 | `EventManagerTests.swift` | `EventManagerTests.postAppLifecycleDidChangeCarriesPhasePayload` |
| 6 | 行为 | All event raw values are stable | P0 | ✅ 已覆盖 | `EventManagerTests.swift` | `EventManagerTests.allEventRawValuesAreStable` |
| 7 | 行为 | Notification name matches raw value | P0 | ✅ 已覆盖 | `EventManagerTests.swift` | `EventManagerTests.notificationNameMatchesRawValue` |

## 覆盖率统计

- P0: 7 / 7 ✅
- P1: 0 / 0
- P2: 0 / 0

**总计: 7 / 7**（本包 `Tests/` 中已声明的 `@Test` 全部登记）

## 测试文件

- `EventManagerTests.swift` — 7 条用例

## 优先级说明

- **P0**: 主路径行为（状态推导、事件翻译、核心策略判定）
- **P1**: 边界与退化（Provider 缺失、取消、失效、并发、竞态）
- **P2**: 视图 / 布局 / 系统集成相关，依赖真实窗口或系统环境

## 跨平台说明

- 测试以 `swift test`（macOS 主机）运行为基准
- 平台判定通过注入 `isMacOS` 一类参数在单测内同时覆盖 iOS / macOS 两条分支
- 视图层端到端行为需在 iOS 模拟器或真机验证，不在单测清单内

## 测试执行

```bash
cd Packages/KitAppEvents
swift test
```

## 维护规则

1. **新增公开 API** → 先在 TestPlan 登记测试用例,再写实现
2. **Bug 修复** → 追加回归用例,标注触发条件
3. **删除用例** → 在 commit message 说明理由
4. **状态同步** → 实现后更新 TestPlan,标记 ✅ 并填写测试方法名
