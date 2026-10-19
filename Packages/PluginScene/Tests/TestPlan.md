# TestPlan — PluginScene

## 包概述

场景系统插件：生产 `SceneProviding`，管理场景栈与场景切换。

公开类型:
- `SceneProvider`
- `ScenePlugin`

### README 中的测试说明（摘自 `README.md`）

- **Test files:**
  - `Tests/PluginSceneTests/ScenePluginTests.swift` — provider registration, persistence, observer/view-model wiring, and plugin boot ordering.
  - `Tests/PluginSceneTests/SceneSettingsTests.swift` — view model behavior against a `SceneProbe`.
- **Key scenarios tested:**
  - Provider registers/unregisters as `SceneProviding`; the settings navigation item has id `"scene"`, title `"Scene"`, icon `"rectangle.3.group"`.
  - A scene-dependent probe plugin boots successfully after `ScenePlugin` (provider available).
  - Scenes are the fixed built-in list (`[.music, .audiobooks]`).
  - Current scene persists to `current-scene.json` and restores across instances; unknown persisted scenes fall back to `.music`; observers are notified on change and stop after cancellation.
  - Observer performs initial sync, forwards events, and stops after cancel.
  - ViewModel loads scenes/current state, delegates `select`, refreshes on `handleProviderChanged`, freezes the last observed snapshot when observation is cancelled, and safely becomes empty after the weak provider is released.
  - Plugin assembly survives enable/disable cycles and reuses the long-lived view model.
- **Running tests:**
  ```bash
  cd /Users/angel/Code/Coffic/Cisum/Packages/PluginScene
  swift test
  ```
- Tests are thorough: they cover real JSON persistence, legacy UserDefaults fallback, observer cancellation, and boot ordering.

## 测试用例清单

下表由 `Tests/` 下的真实 `@Test` 声明自动生成，方法名与代码一一对应。

| ID | 类别 | 描述 | 优先级 | 状态 | 测试文件 | 测试方法 |
|----|------|------|--------|------|----------|----------|
| 1 | 行为 | Registers and unregisters scene provider | P0 | ✅ 已覆盖 | `PluginSceneTests/ScenePluginTests.swift` | `registersAndUnregistersSceneProvider` |
| 2 | 行为 | Contributes scene switcher after boot dependencies are ready | P0 | ✅ 已覆盖 | `PluginSceneTests/ScenePluginTests.swift` | `contributesSceneSwitcherAfterBootDependenciesAreReady` |
| 3 | 行为 | Contributes scene settings navigation item | P0 | ✅ 已覆盖 | `PluginSceneTests/ScenePluginTests.swift` | `contributesSceneSettingsNavigationItem` |
| 4 | 插件 | Boots before same order scene dependent plugins | P0 | ✅ 已覆盖 | `PluginSceneTests/ScenePluginTests.swift` | `bootsBeforeSameOrderSceneDependentPlugins` |
| 5 | 行为 | Exposes fixed built in scenes | P0 | ✅ 已覆盖 | `PluginSceneTests/ScenePluginTests.swift` | `exposesFixedBuiltInScenes` |
| 6 | 持久化 | Persists and restores current scene from disk | P0 | ✅ 已覆盖 | `PluginSceneTests/ScenePluginTests.swift` | `persistsAndRestoresCurrentSceneFromDisk` |
| 7 | 持久化 | Falls back to first scene when persisted scene is unknown | P0 | ✅ 已覆盖 | `PluginSceneTests/ScenePluginTests.swift` | `fallsBackToFirstSceneWhenPersistedSceneIsUnknown` |
| 8 | 观察者 | Notifies observers after scene changes and supports cancellation | P1 | ✅ 已覆盖 | `PluginSceneTests/ScenePluginTests.swift` | `notifiesObserversAfterSceneChangesAndSupportsCancellation` |
| 9 | 观察者 | Observer performs initial sync before installing listener | P0 | ✅ 已覆盖 | `PluginSceneTests/ScenePluginTests.swift` | `observerPerformsInitialSyncBeforeInstallingListener` |
| 10 | 视图模型 | Observer forwards provider events to view model | P2 | ✅ 已覆盖 | `PluginSceneTests/ScenePluginTests.swift` | `observerForwardsProviderEventsToViewModel` |
| 11 | 视图模型 | Observer cancel stops view model updates | P1 | ✅ 已覆盖 | `PluginSceneTests/ScenePluginTests.swift` | `observerCancelStopsViewModelUpdates` |
| 12 | 插件 | Plugin assembly survives enable disable cycles | P0 | ✅ 已覆盖 | `PluginSceneTests/ScenePluginTests.swift` | `pluginAssemblySurvivesEnableDisableCycles` |
| 13 | 行为 | Forwards read write through provider | P0 | ✅ 已覆盖 | `PluginSceneTests/SceneSettingsTests.swift` | `forwardsReadWriteThroughProvider` |
| 14 | 行为 | Degrades gracefully when provider is absent | P1 | ✅ 已覆盖 | `PluginSceneTests/SceneSettingsTests.swift` | `degradesGracefullyWhenProviderIsAbsent` |
| 15 | 观察者 | Observer forwards provider events and stops after cancel | P1 | ✅ 已覆盖 | `PluginSceneTests/SceneSettingsTests.swift` | `observerForwardsProviderEventsAndStopsAfterCancel` |
| 16 | 行为 | Init loads scenes and current from provider | P0 | ✅ 已覆盖 | `PluginSceneTests/SceneSettingsTests.swift` | `initLoadsScenesAndCurrentFromProvider` |
| 17 | 行为 | Init without provider falls back to empty | P1 | ✅ 已覆盖 | `PluginSceneTests/SceneSettingsTests.swift` | `initWithoutProviderFallsBackToEmpty` |
| 18 | 行为 | Select delegates to provider and refreshes | P0 | ✅ 已覆盖 | `PluginSceneTests/SceneSettingsTests.swift` | `selectDelegatesToProviderAndRefreshes` |
| 19 | 状态 | Handle provider changed refreshes state | P0 | ✅ 已覆盖 | `PluginSceneTests/SceneSettingsTests.swift` | `handleProviderChangedRefreshesState` |
| 20 | 行为 | Select without provider is no op | P1 | ✅ 已覆盖 | `PluginSceneTests/SceneSettingsTests.swift` | `selectWithoutProviderIsNoOp` |
| 21 | 视图模型 | View model weakly holds provider and falls back when released | P2 | ✅ 已覆盖 | `PluginSceneTests/SceneSettingsTests.swift` | `viewModelWeaklyHoldsProviderAndFallsBackWhenReleased` |

## 覆盖率统计

- P0: 13 / 13 ✅
- P1: 6 / 6 ✅
- P2: 2 / 2 ✅

**总计: 21 / 21**（本包 `Tests/` 中已声明的 `@Test` 全部登记）

## 测试文件

- `PluginSceneTests/ScenePluginTests.swift` — 12 条用例
- `PluginSceneTests/SceneSettingsTests.swift` — 9 条用例

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
cd Packages/PluginScene
swift test
```

## 维护规则

1. **新增公开 API** → 先在 TestPlan 登记测试用例,再写实现
2. **Bug 修复** → 追加回归用例,标注触发条件
3. **删除用例** → 在 commit message 说明理由
4. **状态同步** → 实现后更新 TestPlan,标记 ✅ 并填写测试方法名
