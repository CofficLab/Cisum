# TestPlan — PluginAudioPlayMode

## 包概述

音乐播放模式：列表循环、单曲循环、随机与顺序的模式切换与展示。

公开类型:
- `AudioPlayModePlugin`
- `AudioPlayModePluginInfo`
- `AudioPlayModeStore`
- `AudioPlayModeRootView`

### README 中的测试说明（摘自 `README.md`）

- **Test files**:
  - `Tests/AudioPlayModePluginTests.swift` — registration metadata and fallback defaults.
  - `Tests/AudioPlayModeCoverageTests.swift` — store resolution and view-model behavior.
- **Key scenarios tested**:
  - Metadata: `iconName == "repeat"`, `emoji == "🔄"`, `order == 0`.
  - `AudioPlayModeStore.resolvedPlayMode`: prefers the local value, falls back to cloud, defaults to sequence when both are missing; falls back to cloud when the local value is invalid.
  - Store round-trip: store/get a mode, invalid stored raw value falls back to sequence, reset restores default, available modes are exactly `[.sequence, .repeatAll, .loop, .shuffle]`.
  - `AudioPlayModeViewModel`: entering the target scene activates and restores the stored mode; leaving deactivates and returning reactivates; skips pushing when the stored mode already matches; switching to sequence sorts the queue and stores; switching to shuffle shuffles; loop only stores; inactive mode changes are ignored; sort errors are handled gracefully.
- **Running tests**:
  ```bash
  cd /Users/angel/Code/Coffic/Cisum/Packages/PluginAudioPlayMode
  swift test
  ```

## 测试用例清单

下表由 `Tests/` 下的真实 `@Test` 声明自动生成，方法名与代码一一对应。

| ID | 类别 | 描述 | 优先级 | 状态 | 测试文件 | 测试方法 |
|----|------|------|--------|------|----------|----------|
| 1 | 行为 | Resolved play mode prefers local value | P0 | ✅ 已覆盖 | `AudioPlayModeCoverageTests.swift` | `resolvedPlayModePrefersLocalValue` |
| 2 | 行为 | Resolved play mode falls back to cloud | P0 | ✅ 已覆盖 | `AudioPlayModeCoverageTests.swift` | `resolvedPlayModeFallsBackToCloud` |
| 3 | 行为 | Resolved play mode defaults to sequence | P0 | ✅ 已覆盖 | `AudioPlayModeCoverageTests.swift` | `resolvedPlayModeDefaultsToSequence` |
| 4 | 存储 | Store and get round trip | P0 | ✅ 已覆盖 | `AudioPlayModeCoverageTests.swift` | `storeAndGetRoundTrip` |
| 5 | 存储 | Store raw invalid value falls back | P1 | ✅ 已覆盖 | `AudioPlayModeCoverageTests.swift` | `storeRawInvalidValueFallsBack` |
| 6 | 存储 | Reset restores default | P1 | ✅ 已覆盖 | `AudioPlayModeCoverageTests.swift` | `resetRestoresDefault` |
| 7 | 行为 | Available modes expose supported set | P0 | ✅ 已覆盖 | `AudioPlayModeCoverageTests.swift` | `availableModesExposeSupportedSet` |
| 8 | 存储 | Scene change to target activates and restores mode | P0 | ✅ 已覆盖 | `AudioPlayModeCoverageTests.swift` | `sceneChangeToTargetActivatesAndRestoresMode` |
| 9 | 行为 | Scene change to other scene deactivates | P1 | ✅ 已覆盖 | `AudioPlayModeCoverageTests.swift` | `sceneChangeToOtherSceneDeactivates` |
| 10 | 存储 | Activate skips when stored mode matches current | P0 | ✅ 已覆盖 | `AudioPlayModeCoverageTests.swift` | `activateSkipsWhenStoredModeMatchesCurrent` |
| 11 | 排序 | Play mode changed to sequence sorts queue | P0 | ✅ 已覆盖 | `AudioPlayModeCoverageTests.swift` | `playModeChangedToSequenceSortsQueue` |
| 12 | 行为 | Play mode changed to shuffle shuffles queue | P0 | ✅ 已覆盖 | `AudioPlayModeCoverageTests.swift` | `playModeChangedToShuffleShufflesQueue` |
| 13 | 存储 | Play mode changed to loop only stores | P0 | ✅ 已覆盖 | `AudioPlayModeCoverageTests.swift` | `playModeChangedToLoopOnlyStores` |
| 14 | 行为 | Play mode changed when inactive is ignored | P0 | ✅ 已覆盖 | `AudioPlayModeCoverageTests.swift` | `playModeChangedWhenInactiveIsIgnored` |
| 15 | 排序 | Sort error is handled gracefully | P1 | ✅ 已覆盖 | `AudioPlayModeCoverageTests.swift` | `sortErrorIsHandledGracefully` |
| 16 | 视图模型 | Scene events drive view model activation | P2 | ✅ 已覆盖 | `AudioPlayModeCoverageTests.swift` | `sceneEventsDriveViewModelActivation` |
| 17 | 视图模型 | Playback mode events apply to view model | P2 | ✅ 已覆盖 | `AudioPlayModeCoverageTests.swift` | `playbackModeEventsApplyToViewModel` |
| 18 | 观察者 | Cancelling observer stops updates | P1 | ✅ 已覆盖 | `AudioPlayModeCoverageTests.swift` | `cancellingObserverStopsUpdates` |
| 19 | 插件 | Plugin info exports registration metadata | P0 | ✅ 已覆盖 | `AudioPlayModePluginTests.swift` | `pluginInfoExportsRegistrationMetadata` |
| 20 | 行为 | Audio play mode falls back to cloud when local value is invalid | P1 | ✅ 已覆盖 | `AudioPlayModePluginTests.swift` | `audioPlayModeFallsBackToCloudWhenLocalValueIsInvalid` |
| 21 | 存储 | Audio play mode defaults when stored values are invalid | P1 | ✅ 已覆盖 | `AudioPlayModePluginTests.swift` | `audioPlayModeDefaultsWhenStoredValuesAreInvalid` |

## 覆盖率统计

- P0: 12 / 12 ✅
- P1: 7 / 7 ✅
- P2: 2 / 2 ✅

**总计: 21 / 21**（本包 `Tests/` 中已声明的 `@Test` 全部登记）

## 测试文件

- `AudioPlayModeCoverageTests.swift` — 18 条用例
- `AudioPlayModePluginTests.swift` — 3 条用例

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
cd Packages/PluginAudioPlayMode
swift test
```

## 维护规则

1. **新增公开 API** → 先在 TestPlan 登记测试用例,再写实现
2. **Bug 修复** → 追加回归用例,标注触发条件
3. **删除用例** → 在 commit message 说明理由
4. **状态同步** → 实现后更新 TestPlan,标记 ✅ 并填写测试方法名
