# TestPlan — PluginPlayBack

## 包概述

通用播放插件：注册 `PlaybackProviding` 与导航能力，驱动实际播放引擎。

公开类型:
- `PluginPlayBack`
- `PlaybackProvider`
- `PlaybackStateStore`

### README 中的测试说明（摘自 `README.md`）

- **Test files:**
  - `Tests/PlaybackSettingsTests.swift` — uses a `PlaybackStub` and `SceneProviderStub` to test direct Provider injection, settings view model, observers, and provider registration/unregistration.
  - `Tests/PlaybackStateStoreTests.swift` — exercises the plist persistence against a temporary directory.
- **Key scenarios tested:**
  - Settings view model initializes from `PlaybackProviding`, tracks scene/asset/state/time/duration events, and reads per-scene last files.
  - Playback and scene observers forward events and stop after cancellation; repeated cancel is idempotent.
  - Plugin boot registers both `PlaybackProviding` and `PlaybackMediaProviding`, and shutdown unregisters both.
  - `PlaybackStateStore` persists scene files independently, deletes the plist when all slots are cleared, migrates the legacy global `"url"` key exactly once, discards the legacy value on a scene-specific write, and returns `nil` for missing/malformed files (write failures do not escape).
- **Running tests:**
  ```bash
  cd /Users/angel/Code/Coffic/Cisum/Packages/PluginPlayBack
  swift test
  ```
- Tests are thorough: they cover the real plist persistence and legacy migration, the observer wiring, and provider lifecycle, without booting a real audio engine.

## 测试用例清单

下表由 `Tests/` 下的真实 `@Test` 声明自动生成，方法名与代码一一对应。

| ID | 类别 | 描述 | 优先级 | 状态 | 测试文件 | 测试方法 |
|----|------|------|--------|------|----------|----------|
| 1 | 能力 | View model weakly holds playback capability | P2 | ✅ 已覆盖 | `PlaybackSettingsTests.swift` | `viewModelWeaklyHoldsPlaybackCapability` |
| 2 | 视图模型 | Settings view model initializes from provider and tracks events | P2 | ✅ 已覆盖 | `PlaybackSettingsTests.swift` | `settingsViewModelInitializesFromProviderAndTracksEvents` |
| 3 | 观察者 | Playback observer forwards events and stops after cancellation | P1 | ✅ 已覆盖 | `PlaybackSettingsTests.swift` | `playbackObserverForwardsEventsAndStopsAfterCancellation` |
| 4 | 观察者 | Scene observer synchronizes initial state and cancels updates | P1 | ✅ 已覆盖 | `PlaybackSettingsTests.swift` | `sceneObserverSynchronizesInitialStateAndCancelsUpdates` |
| 5 | 插件 | Plugin shutdown unregisters both playback provider contracts | P0 | ✅ 已覆盖 | `PlaybackSettingsTests.swift` | `pluginShutdownUnregistersBothPlaybackProviderContracts` |
| 6 | 持久化 | Scene files persist independently and delete when all are cleared | P0 | ✅ 已覆盖 | `PlaybackStateStoreTests.swift` | `sceneFilesPersistIndependentlyAndDeleteWhenAllAreCleared` |
| 7 | 行为 | Legacy global record migrates once to the first requested scene | P0 | ✅ 已覆盖 | `PlaybackStateStoreTests.swift` | `legacyGlobalRecordMigratesOnceToTheFirstRequestedScene` |
| 8 | 行为 | Saving scene specific record discards unmigrated legacy value | P0 | ✅ 已覆盖 | `PlaybackStateStoreTests.swift` | `savingSceneSpecificRecordDiscardsUnmigratedLegacyValue` |
| 9 | 行为 | Scene specific record takes priority and purges coexisting legacy value | P0 | ✅ 已覆盖 | `PlaybackStateStoreTests.swift` | `sceneSpecificRecordTakesPriorityAndPurgesCoexistingLegacyValue` |
| 10 | 状态 | Missing or malformed state returns nil | P1 | ✅ 已覆盖 | `PlaybackStateStoreTests.swift` | `missingOrMalformedStateReturnsNil` |
| 11 | 行为 | Write failure does not escape into playback | P1 | ✅ 已覆盖 | `PlaybackStateStoreTests.swift` | `writeFailureDoesNotEscapeIntoPlayback` |

## 覆盖率统计

- P0: 5 / 5 ✅
- P1: 4 / 4 ✅
- P2: 2 / 2 ✅

**总计: 11 / 11**（本包 `Tests/` 中已声明的 `@Test` 全部登记）

## 测试文件

- `PlaybackSettingsTests.swift` — 5 条用例
- `PlaybackStateStoreTests.swift` — 6 条用例

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
cd Packages/PluginPlayBack
swift test
```

## 维护规则

1. **新增公开 API** → 先在 TestPlan 登记测试用例,再写实现
2. **Bug 修复** → 追加回归用例,标注触发条件
3. **删除用例** → 在 commit message 说明理由
4. **状态同步** → 实现后更新 TestPlan,标记 ✅ 并填写测试方法名
