# TestPlan — PluginBookProgress

## 包概述

有声书进度：章节级播放位置、恢复时间的持久化策略。

公开类型:
- `BookProgressPlugin`
- `BookProgressPluginInfo`
- `BookProgressRootView`

### README 中的测试说明（摘自 `README.md`）

- **Test files:**
  - `Tests/BookProgressPluginTests.swift` — extensive policy unit tests plus
    view-model integration with a playback probe.
  - `Tests/BookProgressStatePersistence.swift` — helper that upserts a `BookState`
    (current chapter + time) into an in-memory SwiftData container.
- **Key scenarios tested:**
  - Snapshot semantics: URL-only changes don't overwrite saved time; position changes
    normalize NaN/inf/-1 to 0; a different book URL resets global time; unchanged URL
    doesn't re-persist.
  - Symlink handling: symlinked real chapters are treated as the same file (no reset,
    no re-persist, seek-only restore), while distinct dangling symlink books are kept
    separate.
  - Delete cleanup: stored current chapter is cleared when its file/book (through
    symlinks) is deleted; a distinct dangling symlink book is untouched.
  - Disk boundary: progress is only persisted for URLs inside the configured book
    disk; symlink escapes outside the disk are rejected; outside-disk audio is
    ignored.
  - Restore guards: stale generations and scene deactivation discard results; an
    already-loaded chapter is seeked rather than replayed; nested chapters resolve to
    their top-level book folder; root-level files and root disk containment.
  - `BookState` persistence: upsert updates existing state in place and dedupes
    symlinked book records.
  - ViewModel integration: scene activation restores stored progress with the right
    start time, already-loaded assets only seek, paused playback persists time, and
    deletion of the current book clears stored URL/time.
- **Running tests:**
  ```bash
  cd /Users/angel/Code/Coffic/Cisum/Packages/PluginBookProgress
  swift test
  ```

## 测试用例清单

下表由 `Tests/` 下的真实 `@Test` 声明自动生成，方法名与代码一一对应。

| ID | 类别 | 描述 | 优先级 | 状态 | 测试文件 | 测试方法 |
|----|------|------|--------|------|----------|----------|
| 1 | 插件 | Plugin info exports registration metadata | P0 | ✅ 已覆盖 | `BookProgressPluginTests.swift` | `pluginInfoExportsRegistrationMetadata` |
| 2 | 行为 | Current u r l changes do not overwrite saved playback time | P0 | ✅ 已覆盖 | `BookProgressPluginTests.swift` | `currentURLChangesDoNotOverwriteSavedPlaybackTime` |
| 3 | 状态 | Clearing current u r l clears global book without saving chapter state | P1 | ✅ 已覆盖 | `BookProgressPluginTests.swift` | `clearingCurrentURLClearsGlobalBookWithoutSavingChapterState` |
| 4 | 归一化 | Playback position snapshot normalizes invalid times | P1 | ✅ 已覆盖 | `BookProgressPluginTests.swift` | `playbackPositionSnapshotNormalizesInvalidTimes` |
| 5 | 存储 | Different current book u r l resets global restore time | P1 | ✅ 已覆盖 | `BookProgressPluginTests.swift` | `differentCurrentBookURLResetsGlobalRestoreTime` |
| 6 | 存储 | Symlinked current book u r l does not reset global restore time | P1 | ✅ 已覆盖 | `BookProgressPluginTests.swift` | `symlinkedCurrentBookURLDoesNotResetGlobalRestoreTime` |
| 7 | 存储 | Distinct dangling symlinked current book u r l resets global restore time | P1 | ✅ 已覆盖 | `BookProgressPluginTests.swift` | `distinctDanglingSymlinkedCurrentBookURLResetsGlobalRestoreTime` |
| 8 | 持久化 | Unchanged current book u r l does not persist again | P0 | ✅ 已覆盖 | `BookProgressPluginTests.swift` | `unchangedCurrentBookURLDoesNotPersistAgain` |
| 9 | 存储 | Invalid restored book u r l should clear current book | P1 | ✅ 已覆盖 | `BookProgressPluginTests.swift` | `invalidRestoredBookURLShouldClearCurrentBook` |
| 10 | 状态 | Deleted stored current book chapter should clear restore state | P0 | ✅ 已覆盖 | `BookProgressPluginTests.swift` | `deletedStoredCurrentBookChapterShouldClearRestoreState` |
| 11 | 状态 | Symlinked deleted stored current book chapter should clear restore state | P0 | ✅ 已覆盖 | `BookProgressPluginTests.swift` | `symlinkedDeletedStoredCurrentBookChapterShouldClearRestoreState` |
| 12 | 状态 | Dangling symlinked stored current book chapter should clear restore state | P1 | ✅ 已覆盖 | `BookProgressPluginTests.swift` | `danglingSymlinkedStoredCurrentBookChapterShouldClearRestoreState` |
| 13 | 状态 | Distinct dangling symlinked stored current book chapter should not clear restore state | P1 | ✅ 已覆盖 | `BookProgressPluginTests.swift` | `distinctDanglingSymlinkedStoredCurrentBookChapterShouldNotClearRestoreState` |
| 14 | 持久化 | Playback position changes persist current time | P0 | ✅ 已覆盖 | `BookProgressPluginTests.swift` | `playbackPositionChangesPersistCurrentTime` |
| 15 | 持久化 | Playback position does not persist for audio outside book disk | P0 | ✅ 已覆盖 | `BookProgressPluginTests.swift` | `playbackPositionDoesNotPersistForAudioOutsideBookDisk` |
| 16 | 存储 | Restore result only applies when current book did not change | P0 | ✅ 已覆盖 | `BookProgressPluginTests.swift` | `restoreResultOnlyAppliesWhenCurrentBookDidNotChange` |
| 17 | 存储 | Stale restore request does not apply after scene change | P1 | ✅ 已覆盖 | `BookProgressPluginTests.swift` | `staleRestoreRequestDoesNotApplyAfterSceneChange` |
| 18 | 存储 | Restore does not replay already loaded book chapter | P0 | ✅ 已覆盖 | `BookProgressPluginTests.swift` | `restoreDoesNotReplayAlreadyLoadedBookChapter` |
| 19 | 存储 | Restore treats symlinked current chapter as already loaded | P0 | ✅ 已覆盖 | `BookProgressPluginTests.swift` | `restoreTreatsSymlinkedCurrentChapterAsAlreadyLoaded` |
| 20 | 存储 | Restore does not treat distinct dangling symlinked chapter as already loaded | P1 | ✅ 已覆盖 | `BookProgressPluginTests.swift` | `restoreDoesNotTreatDistinctDanglingSymlinkedChapterAsAlreadyLoaded` |
| 21 | 行为 | Stale current u r l change does not overwrite new book chapter | P1 | ✅ 已覆盖 | `BookProgressPluginTests.swift` | `staleCurrentURLChangeDoesNotOverwriteNewBookChapter` |
| 22 | 校验 | Stale current u r l change does not apply after book scene invalidation | P1 | ✅ 已覆盖 | `BookProgressPluginTests.swift` | `staleCurrentURLChangeDoesNotApplyAfterBookSceneInvalidation` |
| 23 | 行为 | Root level book file resolves to itself | P0 | ✅ 已覆盖 | `BookProgressPluginTests.swift` | `rootLevelBookFileResolvesToItself` |
| 24 | 行为 | Nested book chapter resolves to top level book folder | P0 | ✅ 已覆盖 | `BookProgressPluginTests.swift` | `nestedBookChapterResolvesToTopLevelBookFolder` |
| 25 | 行为 | Outside book disk falls back to parent folder | P0 | ✅ 已覆盖 | `BookProgressPluginTests.swift` | `outsideBookDiskFallsBackToParentFolder` |
| 26 | 行为 | Root book disk contains nested playback u r l | P0 | ✅ 已覆盖 | `BookProgressPluginTests.swift` | `rootBookDiskContainsNestedPlaybackURL` |
| 27 | 行为 | Symlinked book disk resolves real playback u r l to configured root | P0 | ✅ 已覆盖 | `BookProgressPluginTests.swift` | `symlinkedBookDiskResolvesRealPlaybackURLToConfiguredRoot` |
| 28 | 行为 | Book lookup finds standalone book files | P0 | ✅ 已覆盖 | `BookProgressPluginTests.swift` | `bookLookupFindsStandaloneBookFiles` |
| 29 | 行为 | Book lookup rejects unsupported standalone files | P0 | ✅ 已覆盖 | `BookProgressPluginTests.swift` | `bookLookupRejectsUnsupportedStandaloneFiles` |
| 30 | 行为 | Book lookup rejects files outside configured book disk | P0 | ✅ 已覆盖 | `BookProgressPluginTests.swift` | `bookLookupRejectsFilesOutsideConfiguredBookDisk` |
| 31 | 行为 | Book progress rejects current audio outside configured book disk | P0 | ✅ 已覆盖 | `BookProgressPluginTests.swift` | `bookProgressRejectsCurrentAudioOutsideConfiguredBookDisk` |
| 32 | 行为 | Book lookup rejects symlink escapes outside configured book disk | P0 | ✅ 已覆盖 | `BookProgressPluginTests.swift` | `bookLookupRejectsSymlinkEscapesOutsideConfiguredBookDisk` |
| 33 | 行为 | Book lookup finds folder books for nested chapters | P0 | ✅ 已覆盖 | `BookProgressPluginTests.swift` | `bookLookupFindsFolderBooksForNestedChapters` |
| 34 | 持久化 | Book progress state persistence updates on main actor | P0 | ✅ 已覆盖 | `BookProgressPluginTests.swift` | `bookProgressStatePersistenceUpdatesOnMainActor` |
| 35 | 持久化 | Book progress state persistence updates symlinked book state | P0 | ✅ 已覆盖 | `BookProgressPluginTests.swift` | `bookProgressStatePersistenceUpdatesSymlinkedBookState` |
| 36 | 存储 | Scene activation restores stored progress | P0 | ✅ 已覆盖 | `BookProgressPluginTests.swift` | `sceneActivationRestoresStoredProgress` |
| 37 | 行为 | Already loaded asset only seeks | P0 | ✅ 已覆盖 | `BookProgressPluginTests.swift` | `alreadyLoadedAssetOnlySeeks` |
| 38 | 持久化 | Paused playback in active scene persists progress | P0 | ✅ 已覆盖 | `BookProgressPluginTests.swift` | `pausedPlaybackInActiveScenePersistsProgress` |
| 39 | 存储 | Deletion of current book clears stored progress | P0 | ✅ 已覆盖 | `BookProgressPluginTests.swift` | `deletionOfCurrentBookClearsStoredProgress` |

## 覆盖率统计

- P0: 27 / 27 ✅
- P1: 12 / 12 ✅
- P2: 0 / 0

**总计: 39 / 39**（本包 `Tests/` 中已声明的 `@Test` 全部登记）

## 测试文件

- `BookProgressPluginTests.swift` — 39 条用例

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
cd Packages/PluginBookProgress
swift test
```

## 维护规则

1. **新增公开 API** → 先在 TestPlan 登记测试用例,再写实现
2. **Bug 修复** → 追加回归用例,标注触发条件
3. **删除用例** → 在 commit message 说明理由
4. **状态同步** → 实现后更新 TestPlan,标记 ✅ 并填写测试方法名
