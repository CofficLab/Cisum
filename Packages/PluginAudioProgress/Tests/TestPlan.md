# TestPlan — PluginAudioProgress

## 包概述

音乐进度条：进度、时长与拖动 seek 的展示与同步。

公开类型:
- `AudioProgressPlugin`
- `AudioProgressHost`
- `AudioProgressPluginInfo`
- `AudioStateRepo`
- `AudioProgressRootView`

### README 中的测试说明（摘自 `README.md`）

- **Test files**: `Tests/AudioProgressPluginTests.swift`.
- **Key scenarios tested**:
  - Metadata: `AudioProgressPluginInfo.titleKey == "Audio Progress"`.
  - Persistence policy: leaving the audio scene persists progress; entering/staying in the scene does not; nil current URL persists nil; supported URLs persist; unsupported URLs keep the previous.
  - `AudioStateRepo.storedURL`: empty/nil ignored, trims whitespace, parses `file://` and legacy path strings, rejects non-URLs.
  - `AudioStateRepo.storedTime`: local zero overrides stale cloud time; invalid local times fall back to cloud; `normalizedTimeForStorage` clamps NaN/infinity/negative to 0.
  - Play-mode resolution falls back to cloud for invalid local modes.
  - Restore reset/clear: a different current URL resets global time (symlinked URL does not; distinct dangling symlink does); deleted/unplayable stored current clears restore state; restore results apply only when the current audio and scene are unchanged; already-loaded audio is not replayed.
- **Running tests**:
  ```bash
  cd /Users/angel/Code/Coffic/Cisum/Packages/PluginAudioProgress
  swift test
  ```

## 测试用例清单

下表由 `Tests/` 下的真实 `@Test` 声明自动生成，方法名与代码一一对应。

| ID | 类别 | 描述 | 优先级 | 状态 | 测试文件 | 测试方法 |
|----|------|------|--------|------|----------|----------|
| 1 | 元数据 | Audio progress info exports metadata | P0 | ✅ 已覆盖 | `AudioProgressPluginTests.swift` | `audioProgressInfoExportsMetadata` |
| 2 | 持久化 | Leaving audio scene persists progress | P0 | ✅ 已覆盖 | `AudioProgressPluginTests.swift` | `leavingAudioScenePersistsProgress` |
| 3 | 持久化 | Entering audio scene does not persist stale progress | P1 | ✅ 已覆盖 | `AudioProgressPluginTests.swift` | `enteringAudioSceneDoesNotPersistStaleProgress` |
| 4 | 行为 | Staying in audio scene does not duplicate progress save | P1 | ✅ 已覆盖 | `AudioProgressPluginTests.swift` | `stayingInAudioSceneDoesNotDuplicateProgressSave` |
| 5 | 持久化 | Clearing current audio u r l persists nil current audio | P1 | ✅ 已覆盖 | `AudioProgressPluginTests.swift` | `clearingCurrentAudioURLPersistsNilCurrentAudio` |
| 6 | 持久化 | Supported current audio u r l persists current audio | P0 | ✅ 已覆盖 | `AudioProgressPluginTests.swift` | `supportedCurrentAudioURLPersistsCurrentAudio` |
| 7 | 行为 | Unsupported current u r l keeps previous audio | P0 | ✅ 已覆盖 | `AudioProgressPluginTests.swift` | `unsupportedCurrentURLKeepsPreviousAudio` |
| 8 | 行为 | Empty cloud audio u r l is ignored | P1 | ✅ 已覆盖 | `AudioProgressPluginTests.swift` | `emptyCloudAudioURLIsIgnored` |
| 9 | 行为 | Local zero audio time overrides stale cloud time | P1 | ✅ 已覆盖 | `AudioProgressPluginTests.swift` | `localZeroAudioTimeOverridesStaleCloudTime` |
| 10 | 行为 | Invalid local audio times fall back to cloud | P1 | ✅ 已覆盖 | `AudioProgressPluginTests.swift` | `invalidLocalAudioTimesFallBackToCloud` |
| 11 | 归一化 | Audio times are normalized before storage | P0 | ✅ 已覆盖 | `AudioProgressPluginTests.swift` | `audioTimesAreNormalizedBeforeStorage` |
| 12 | 行为 | Invalid local audio play mode falls back to cloud mode | P1 | ✅ 已覆盖 | `AudioProgressPluginTests.swift` | `invalidLocalAudioPlayModeFallsBackToCloudMode` |
| 13 | 存储 | Different current audio u r l resets global restore time | P1 | ✅ 已覆盖 | `AudioProgressPluginTests.swift` | `differentCurrentAudioURLResetsGlobalRestoreTime` |
| 14 | 存储 | Symlinked current audio u r l does not reset global restore time | P1 | ✅ 已覆盖 | `AudioProgressPluginTests.swift` | `symlinkedCurrentAudioURLDoesNotResetGlobalRestoreTime` |
| 15 | 存储 | Distinct dangling symlink current audio u r l resets global restore time | P1 | ✅ 已覆盖 | `AudioProgressPluginTests.swift` | `distinctDanglingSymlinkCurrentAudioURLResetsGlobalRestoreTime` |
| 16 | 存储 | Invalid restored audio u r l should clear current audio | P1 | ✅ 已覆盖 | `AudioProgressPluginTests.swift` | `invalidRestoredAudioURLShouldClearCurrentAudio` |
| 17 | 状态 | Deleted stored current audio should clear restore state | P0 | ✅ 已覆盖 | `AudioProgressPluginTests.swift` | `deletedStoredCurrentAudioShouldClearRestoreState` |
| 18 | 状态 | Symlinked deleted stored current audio should clear restore state | P0 | ✅ 已覆盖 | `AudioProgressPluginTests.swift` | `symlinkedDeletedStoredCurrentAudioShouldClearRestoreState` |
| 19 | 状态 | Dangling symlink stored current audio should clear restore state | P1 | ✅ 已覆盖 | `AudioProgressPluginTests.swift` | `danglingSymlinkStoredCurrentAudioShouldClearRestoreState` |
| 20 | 状态 | Distinct dangling symlink deleted audio does not clear restore state | P1 | ✅ 已覆盖 | `AudioProgressPluginTests.swift` | `distinctDanglingSymlinkDeletedAudioDoesNotClearRestoreState` |
| 21 | 存储 | Restore result only applies when current audio did not change | P0 | ✅ 已覆盖 | `AudioProgressPluginTests.swift` | `restoreResultOnlyAppliesWhenCurrentAudioDidNotChange` |
| 22 | 存储 | Stale audio restore request does not apply after scene change | P1 | ✅ 已覆盖 | `AudioProgressPluginTests.swift` | `staleAudioRestoreRequestDoesNotApplyAfterSceneChange` |
| 23 | 存储 | Restore does not replay already loaded audio | P0 | ✅ 已覆盖 | `AudioProgressPluginTests.swift` | `restoreDoesNotReplayAlreadyLoadedAudio` |
| 24 | 存储 | Restore treats symlinked current audio as already loaded | P0 | ✅ 已覆盖 | `AudioProgressPluginTests.swift` | `restoreTreatsSymlinkedCurrentAudioAsAlreadyLoaded` |
| 25 | 存储 | Restore does not treat distinct dangling symlinks as current audio | P1 | ✅ 已覆盖 | `AudioProgressPluginTests.swift` | `restoreDoesNotTreatDistinctDanglingSymlinksAsCurrentAudio` |
| 26 | 行为 | Stale widget clear does not overwrite new audio | P1 | ✅ 已覆盖 | `AudioProgressPluginTests.swift` | `staleWidgetClearDoesNotOverwriteNewAudio` |
| 27 | 行为 | Stale current audio u r l change does not overwrite new track | P1 | ✅ 已覆盖 | `AudioProgressPluginTests.swift` | `staleCurrentAudioURLChangeDoesNotOverwriteNewTrack` |
| 28 | 校验 | Stale current audio u r l change does not apply after scene invalidation | P1 | ✅ 已覆盖 | `AudioProgressPluginTests.swift` | `staleCurrentAudioURLChangeDoesNotApplyAfterSceneInvalidation` |
| 29 | 元数据 | Widget metadata result only applies to still current audio | P2 | ✅ 已覆盖 | `AudioProgressPluginTests.swift` | `widgetMetadataResultOnlyAppliesToStillCurrentAudio` |
| 30 | 行为 | Play mode round trip | P0 | ✅ 已覆盖 | `AudioProgressPluginTests.swift` | `playModeRoundTrip` |
| 31 | 行为 | Current u r l round trip and clear | P0 | ✅ 已覆盖 | `AudioProgressPluginTests.swift` | `currentURLRoundTripAndClear` |
| 32 | 归一化 | Current time round trip and normalization | P0 | ✅ 已覆盖 | `AudioProgressPluginTests.swift` | `currentTimeRoundTripAndNormalization` |
| 33 | 存储 | Stored u r l parses schemes and paths | P0 | ✅ 已覆盖 | `AudioProgressPluginTests.swift` | `storedURLParsesSchemesAndPaths` |
| 34 | 行为 | Resolved play mode prefers local over cloud | P0 | ✅ 已覆盖 | `AudioProgressPluginTests.swift` | `resolvedPlayModePrefersLocalOverCloud` |

## 覆盖率统计

- P0: 15 / 15 ✅
- P1: 18 / 18 ✅
- P2: 1 / 1 ✅

**总计: 34 / 34**（本包 `Tests/` 中已声明的 `@Test` 全部登记）

## 测试文件

- `AudioProgressPluginTests.swift` — 34 条用例

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
cd Packages/PluginAudioProgress
swift test
```

## 维护规则

1. **新增公开 API** → 先在 TestPlan 登记测试用例,再写实现
2. **Bug 修复** → 追加回归用例,标注触发条件
3. **删除用例** → 在 commit message 说明理由
4. **状态同步** → 实现后更新 TestPlan,标记 ✅ 并填写测试方法名
