# TestPlan — PluginPluginManager

## 包概述

插件管理器：查看、启用 / 禁用与重置插件。

公开类型:
- `PluginPluginManager`

### README 中的测试说明（摘自 `README.md`）

- **Test files:**
  - `Tests/PluginPluginManagerTests/PluginManagementCoverageTests.swift` — uses `ProbeConfigurablePlugin`/`ProbeAlwaysOnPlugin`, a `PluginManaging` probe, and a real `KernelCoreContainer` with an injected `PluginManagerStateStore`.
  - `Tests/PluginPluginManagerTests/PluginManagerStateStoreTests.swift` — exercises the plist persistence and legacy UserDefaults migration.
- **Key scenarios tested:**
  - ViewModel sources plugins and routes enable/disable directly through `PluginManaging`, falls back safely when the Provider is released, and bumps revision.
  - Observer increments revision on manager events and stops after cancellation.
  - `PluginManagerProvider` exposes the registry, filters configurable plugins, performs enable/disable round-trips, fails to enable unknown plugins, fails to disable an alwaysOn plugin (policy-protected), and supports idempotent observer cancellation.
  - Plugin lifecycle: safe `onRegister` without docs, navigation item is `nil` before boot but non-nil after boot even without storage, and shutdown tears down state.
  - `PluginManagerStateStore` persists overrides to the plist and reloads them across instances, clears entries, resets all, and migrates the legacy UserDefaults key once.
- **Running tests:**
  ```bash
  cd /Users/angel/Code/Coffic/Cisum/Packages/PluginPluginManager
  swift test
  ```
- Tests are comprehensive for a manager-sized package: they cover the real kernel-backed enable/disable flow and the on-disk override persistence.

## 测试用例清单

下表由 `Tests/` 下的真实 `@Test` 声明自动生成，方法名与代码一一对应。

| ID | 类别 | 描述 | 优先级 | 状态 | 测试文件 | 测试方法 |
|----|------|------|--------|------|----------|----------|
| 1 | 插件 | Plugins come from provider | P0 | ✅ 已覆盖 | `PluginPluginManagerTests/PluginManagementCoverageTests.swift` | `pluginsComeFromProvider` |
| 2 | 视图模型 | Empty view model falls back to empty | P1 | ✅ 已覆盖 | `PluginPluginManagerTests/PluginManagementCoverageTests.swift` | `emptyViewModelFallsBackToEmpty` |
| 3 | 路由 | Set enabled routes to enable and disable | P0 | ✅ 已覆盖 | `PluginPluginManagerTests/PluginManagementCoverageTests.swift` | `setEnabledRoutesToEnableAndDisable` |
| 4 | 行为 | Increment revision bumps version | P0 | ✅ 已覆盖 | `PluginPluginManagerTests/PluginManagementCoverageTests.swift` | `incrementRevisionBumpsVersion` |
| 5 | 视图模型 | View model falls back when provider released | P2 | ✅ 已覆盖 | `PluginPluginManagerTests/PluginManagementCoverageTests.swift` | `viewModelFallsBackWhenProviderReleased` |
| 6 | 视图模型 | View model fails to enable after provider released | P1 | ✅ 已覆盖 | `PluginPluginManagerTests/PluginManagementCoverageTests.swift` | `viewModelFailsToEnableAfterProviderReleased` |
| 7 | 行为 | Manager events increment revision | P0 | ✅ 已覆盖 | `PluginPluginManagerTests/PluginManagementCoverageTests.swift` | `managerEventsIncrementRevision` |
| 8 | 观察者 | Cancelling observer stops increments | P1 | ✅ 已覆盖 | `PluginPluginManagerTests/PluginManagementCoverageTests.swift` | `cancellingObserverStopsIncrements` |
| 9 | 行为 | On register with no docs is safe | P0 | ✅ 已覆盖 | `PluginPluginManagerTests/PluginManagementCoverageTests.swift` | `onRegisterWithNoDocsIsSafe` |
| 10 | 行为 | On boot without storage keeps kernel reference | P1 | ✅ 已覆盖 | `PluginPluginManagerTests/PluginManagementCoverageTests.swift` | `onBootWithoutStorageKeepsKernelReference` |
| 11 | 行为 | Navigation item before boot is nil | P1 | ✅ 已覆盖 | `PluginPluginManagerTests/PluginManagementCoverageTests.swift` | `navigationItemBeforeBootIsNil` |
| 12 | 状态 | Shutdown tears down state | P0 | ✅ 已覆盖 | `PluginPluginManagerTests/PluginManagementCoverageTests.swift` | `shutdownTearsDownState` |

## 覆盖率统计

- P0: 6 / 6 ✅
- P1: 5 / 5 ✅
- P2: 1 / 1 ✅

**总计: 12 / 12**（本包 `Tests/` 中已声明的 `@Test` 全部登记）

## 测试文件

- `PluginPluginManagerTests/PluginManagementCoverageTests.swift` — 12 条用例

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
cd Packages/PluginPluginManager
swift test
```

## 维护规则

1. **新增公开 API** → 先在 TestPlan 登记测试用例,再写实现
2. **Bug 修复** → 追加回归用例,标注触发条件
3. **删除用例** → 在 commit message 说明理由
4. **状态同步** → 实现后更新 TestPlan,标记 ✅ 并填写测试方法名
