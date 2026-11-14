# TestPlan — PluginBookPlayMode

## 包概述

有声书播放模式：顺序 / 单章 / 全书循环等切换。

公开类型:
- `BookPlayModePlugin`
- `BookPlayModePluginInfo`
- `BookPlayModeStore`
- `BookPlayModeRootView`

### README 中的测试说明（摘自 `README.md`）

- **Test files:**
  - `Tests/BookPlayModeCoverageTests.swift` — probe-based store, view-model, adapter
    and observer tests.
  - `Tests/BookPlayModePluginTests.swift` — metadata and store-resolution edge cases.
- **Key scenarios tested:**
  - `BookPlayModeStore.resolvedPlayMode`: prefers local, falls back to cloud,
    defaults to `.sequence` for missing or bogus values.
  - Store round-trip: `storePlayMode` then `getPlayMode` returns the same mode.
  - ViewModel: entering the target scene activates and restores a stored mode;
    leaving deactivates (no `setPlayMode`); skips applying when stored mode already
    matches; active mode changes are persisted; inactive changes are ignored.
  - Playback mode events are forwarded directly through the provider observer.
  - Observer: scene events drive activation/deactivation; playback mode events reach
    the view model; cancellation stops further updates.
  - Metadata: `iconName == "repeat"`, `order == 7`; invalid local value falls back
    to cloud; both invalid fall back to sequence.
- **Running tests:**
  ```bash
  cd /Users/angel/Code/Coffic/Cisum/Packages/PluginBookPlayMode
  swift test
  ```

## 测试用例清单

下表由 `Tests/` 下的真实 `@Test` 声明自动生成，方法名与代码一一对应。

| ID | 类别 | 描述 | 优先级 | 状态 | 测试文件 | 测试方法 |
|----|------|------|--------|------|----------|----------|
| 1 | 行为 | Resolved play mode prefers local value | P0 | ✅ 已覆盖 | `BookPlayModeCoverageTests.swift` | `resolvedPlayModePrefersLocalValue` |
| 2 | 行为 | Resolved play mode falls back to cloud | P0 | ✅ 已覆盖 | `BookPlayModeCoverageTests.swift` | `resolvedPlayModeFallsBackToCloud` |
| 3 | 行为 | Resolved play mode defaults to sequence | P0 | ✅ 已覆盖 | `BookPlayModeCoverageTests.swift` | `resolvedPlayModeDefaultsToSequence` |
| 4 | 存储 | Store and get round trip | P0 | ✅ 已覆盖 | `BookPlayModeCoverageTests.swift` | `storeAndGetRoundTrip` |
| 5 | 存储 | Scene change to target activates and restores mode | P0 | ✅ 已覆盖 | `BookPlayModeCoverageTests.swift` | `sceneChangeToTargetActivatesAndRestoresMode` |
| 6 | 行为 | Scene change to other scene deactivates | P1 | ✅ 已覆盖 | `BookPlayModeCoverageTests.swift` | `sceneChangeToOtherSceneDeactivates` |
| 7 | 存储 | Activate skips when stored mode matches current | P0 | ✅ 已覆盖 | `BookPlayModeCoverageTests.swift` | `activateSkipsWhenStoredModeMatchesCurrent` |
| 8 | 存储 | Play mode changed stores mode | P0 | ✅ 已覆盖 | `BookPlayModeCoverageTests.swift` | `playModeChangedStoresMode` |
| 9 | 行为 | Play mode changed when inactive is ignored | P0 | ✅ 已覆盖 | `BookPlayModeCoverageTests.swift` | `playModeChangedWhenInactiveIsIgnored` |
| 10 | 视图模型 | Scene events drive view model activation | P2 | ✅ 已覆盖 | `BookPlayModeCoverageTests.swift` | `sceneEventsDriveViewModelActivation` |
| 11 | 视图模型 | Playback mode events apply to view model | P2 | ✅ 已覆盖 | `BookPlayModeCoverageTests.swift` | `playbackModeEventsApplyToViewModel` |
| 12 | 观察者 | Cancelling observer stops updates | P1 | ✅ 已覆盖 | `BookPlayModeCoverageTests.swift` | `cancellingObserverStopsUpdates` |
| 13 | 插件 | Plugin info exports registration metadata | P0 | ✅ 已覆盖 | `BookPlayModePluginTests.swift` | `pluginInfoExportsRegistrationMetadata` |
| 14 | 行为 | Book play mode falls back to cloud when local value is invalid | P1 | ✅ 已覆盖 | `BookPlayModePluginTests.swift` | `bookPlayModeFallsBackToCloudWhenLocalValueIsInvalid` |
| 15 | 存储 | Book play mode defaults when stored values are invalid | P1 | ✅ 已覆盖 | `BookPlayModePluginTests.swift` | `bookPlayModeDefaultsWhenStoredValuesAreInvalid` |

## 覆盖率统计

- P0: 9 / 9 ✅
- P1: 4 / 4 ✅
- P2: 2 / 2 ✅

**总计: 15 / 15**（本包 `Tests/` 中已声明的 `@Test` 全部登记）

## 测试文件

- `BookPlayModeCoverageTests.swift` — 12 条用例
- `BookPlayModePluginTests.swift` — 3 条用例

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
cd Packages/PluginBookPlayMode
swift test
```

## 维护规则

1. **新增公开 API** → 先在 TestPlan 登记测试用例,再写实现
2. **Bug 修复** → 追加回归用例,标注触发条件
3. **删除用例** → 在 commit message 说明理由
4. **状态同步** → 实现后更新 TestPlan,标记 ✅ 并填写测试方法名
