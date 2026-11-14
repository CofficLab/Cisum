# TestPlan — PluginBookDBView

## 包概述

有声书数据库视图：书籍列表、筛选排序与选择态。

公开类型:
- `BookDBViewPlugin`
- `BookLibraryEvent`
- `BookLibraryObserverHandle`
- `BookLibraryCapability`
- `BookLibraryCapabilityAdapter`
- `BookDBViewPluginInfo`
- `BookDBDependencies`
- `BookDBView`
- `BookDBViewDependencies`

### README 中的测试说明（摘自 `README.md`）

- **Test files:**
  - `Tests/BookDBViewPluginTests.swift` — metadata, import pipeline, drop handling,
    ordering, tile policies, tree builder, settings item.
  - `Tests/BookDBViewCoverageTests.swift` — probe-based adapter/observer/view-model
    and policy unit tests.
  - `Tests/BookDBViewBookStateLookup.swift` — helper that fetches a `BookState` by
    book URL (including symlink fallback) from a `ModelContext`.
- **Key scenarios tested:**
  - Import filtering: unsupported top-level files skipped, folders require playable
    files, skipped-source warnings, nested-in-selected-folder pruning, symlinked
    folders/files copied as real files, symlinked source dedup, dangling-symlink
    destination name collision handling, batch-failure cleanup, and rejection of
    destinations nested inside the source (including symlinked destinations).
  - Drop handling: `NSItemProvider` fileURL-data decoding with fallback to URL
    objects, error/partial-failure reporting, and no-op when no URLs load.
  - `BookPlaybackOrdering`: relative-path ordering across discs, sibling-prefix
    rejection, playable-child containment without scanning, symlinked children
    matching, and distinct dangling symlinks kept separate.
  - `BookTreeBuilder`: nested directory structure, hidden/unsupported file skipping,
    missing-root empty result.
  - Grid view model (via `PlaybackProbe`/`BookProbe`/`CapabilityProbe`): books load
    on appear, asset changes select/clear the matching book, taps play with and
    without saved resume state, sync flags toggle, disappear invalidates pending
    updates, and generation/selection guards block stale playback results.
  - Policies and tile color/reload identity determinism; settings navigation item
    metadata (`id == "bookdb"`).
- **Running tests:**
  ```bash
  cd /Users/angel/Code/Coffic/Cisum/Packages/PluginBookDBView
  swift test
  ```

## 测试用例清单

下表由 `Tests/` 下的真实 `@Test` 声明自动生成，方法名与代码一一对应。

| ID | 类别 | 描述 | 优先级 | 状态 | 测试文件 | 测试方法 |
|----|------|------|--------|------|----------|----------|
| 1 | 行为 | Applies initial asset on registration | P0 | ✅ 已覆盖 | `BookDBViewCoverageTests.swift` | `appliesInitialAssetOnRegistration` |
| 2 | 行为 | Forwards asset changed events | P0 | ✅ 已覆盖 | `BookDBViewCoverageTests.swift` | `forwardsAssetChangedEvents` |
| 3 | 观察者 | Cancelling observer stops forwarding | P1 | ✅ 已覆盖 | `BookDBViewCoverageTests.swift` | `cancellingObserverStopsForwarding` |
| 4 | 视图模型 | Forwards library events to grid view model | P2 | ✅ 已覆盖 | `BookDBViewCoverageTests.swift` | `forwardsLibraryEventsToGridViewModel` |
| 5 | 观察者 | Cancelling observer stops forwarding | P1 | ✅ 已覆盖 | `BookDBViewCoverageTests.swift` | `cancellingObserverStopsForwarding` |
| 6 | 状态 | Handle on appear without provider keeps safe state | P1 | ✅ 已覆盖 | `BookDBViewCoverageTests.swift` | `handleOnAppearWithoutProviderKeepsSafeState` |
| 7 | 行为 | Handle on appear loads books from provider | P0 | ✅ 已覆盖 | `BookDBViewCoverageTests.swift` | `handleOnAppearLoadsBooksFromProvider` |
| 8 | 行为 | Handle asset changed selects matching loaded book | P0 | ✅ 已覆盖 | `BookDBViewCoverageTests.swift` | `handleAssetChangedSelectsMatchingLoadedBook` |
| 9 | 行为 | Handle asset changed nil clears selection | P1 | ✅ 已覆盖 | `BookDBViewCoverageTests.swift` | `handleAssetChangedNilClearsSelection` |
| 10 | 状态 | Handle book tap plays file when no saved state | P0 | ✅ 已覆盖 | `BookDBViewCoverageTests.swift` | `handleBookTapPlaysFileWhenNoSavedState` |
| 11 | 状态 | Handle book tap restores saved playback state | P0 | ✅ 已覆盖 | `BookDBViewCoverageTests.swift` | `handleBookTapRestoresSavedPlaybackState` |
| 12 | 行为 | Sync events update is syncing | P0 | ✅ 已覆盖 | `BookDBViewCoverageTests.swift` | `syncEventsUpdateIsSyncing` |
| 13 | 状态 | State updated event records u r l | P0 | ✅ 已覆盖 | `BookDBViewCoverageTests.swift` | `stateUpdatedEventRecordsURL` |
| 14 | 行为 | Handle on disappear invalidates pending updates | P1 | ✅ 已覆盖 | `BookDBViewCoverageTests.swift` | `handleOnDisappearInvalidatesPendingUpdates` |
| 15 | 缓存 | Load scans directory and caches | P0 | ✅ 已覆盖 | `BookDBViewCoverageTests.swift` | `loadScansDirectoryAndCaches` |
| 16 | 缓存 | Invalidate cache clears all entries | P1 | ✅ 已覆盖 | `BookDBViewCoverageTests.swift` | `invalidateCacheClearsAllEntries` |
| 17 | 策略 | Update policy applies only matching generation | P0 | ✅ 已覆盖 | `BookDBViewCoverageTests.swift` | `updatePolicyAppliesOnlyMatchingGeneration` |
| 18 | 策略 | Playback request policy checks generation and selection | P0 | ✅ 已覆盖 | `BookDBViewCoverageTests.swift` | `playbackRequestPolicyChecksGenerationAndSelection` |
| 19 | 策略 | Selection policy matches by same file | P0 | ✅ 已覆盖 | `BookDBViewCoverageTests.swift` | `selectionPolicyMatchesBySameFile` |
| 20 | 元数据 | Book d b info exports metadata | P0 | ✅ 已覆盖 | `BookDBViewPluginTests.swift` | `bookDBInfoExportsMetadata` |
| 21 | 行为 | Book tile placeholder color is stable and title dependent | P0 | ✅ 已覆盖 | `BookDBViewPluginTests.swift` | `bookTilePlaceholderColorIsStableAndTitleDependent` |
| 22 | 行为 | Folder import requires playable files | P0 | ✅ 已覆盖 | `BookDBViewPluginTests.swift` | `folderImportRequiresPlayableFiles` |
| 23 | 筛选 | Book import filters unsupported top level files before import | P0 | ✅ 已覆盖 | `BookDBViewPluginTests.swift` | `bookImportFiltersUnsupportedTopLevelFilesBeforeImport` |
| 24 | 行为 | Book import reports skipped unsupported sources | P0 | ✅ 已覆盖 | `BookDBViewPluginTests.swift` | `bookImportReportsSkippedUnsupportedSources` |
| 25 | 行为 | Folder import accepts symlinked book folders | P0 | ✅ 已覆盖 | `BookDBViewPluginTests.swift` | `folderImportAcceptsSymlinkedBookFolders` |
| 26 | 行为 | Folder import avoids dangling symlink destination names | P1 | ✅ 已覆盖 | `BookDBViewPluginTests.swift` | `folderImportAvoidsDanglingSymlinkDestinationNames` |
| 27 | 行为 | Book import copies symlinked audio files as standalone files | P0 | ✅ 已覆盖 | `BookDBViewPluginTests.swift` | `bookImportCopiesSymlinkedAudioFilesAsStandaloneFiles` |
| 28 | 行为 | Book import deduplicates symlinked audio sources | P1 | ✅ 已覆盖 | `BookDBViewPluginTests.swift` | `bookImportDeduplicatesSymlinkedAudioSources` |
| 29 | 行为 | Book import skips files already covered by selected folder | P0 | ✅ 已覆盖 | `BookDBViewPluginTests.swift` | `bookImportSkipsFilesAlreadyCoveredBySelectedFolder` |
| 30 | 行为 | Folder import deduplicates symlinked book folders | P1 | ✅ 已覆盖 | `BookDBViewPluginTests.swift` | `folderImportDeduplicatesSymlinkedBookFolders` |
| 31 | 行为 | Book import avoids dangling symlink collection names | P1 | ✅ 已覆盖 | `BookDBViewPluginTests.swift` | `bookImportAvoidsDanglingSymlinkCollectionNames` |
| 32 | 行为 | Book import cleans copied items when batch fails | P1 | ✅ 已覆盖 | `BookDBViewPluginTests.swift` | `bookImportCleansCopiedItemsWhenBatchFails` |
| 33 | 行为 | Book import rejects destination inside source folder before copying | P0 | ✅ 已覆盖 | `BookDBViewPluginTests.swift` | `bookImportRejectsDestinationInsideSourceFolderBeforeCopying` |
| 34 | 行为 | Book import treats root source as containing destination | P0 | ✅ 已覆盖 | `BookDBViewPluginTests.swift` | `bookImportTreatsRootSourceAsContainingDestination` |
| 35 | 行为 | Book import rejects symlinked destination inside source folder | P0 | ✅ 已覆盖 | `BookDBViewPluginTests.swift` | `bookImportRejectsSymlinkedDestinationInsideSourceFolder` |
| 36 | 行为 | Book drop reads file u r l data provider | P0 | ✅ 已覆盖 | `BookDBViewPluginTests.swift` | `bookDropReadsFileURLDataProvider` |
| 37 | 行为 | Book drop falls back to u r l object after invalid file u r l data | P1 | ✅ 已覆盖 | `BookDBViewPluginTests.swift` | `bookDropFallsBackToURLObjectAfterInvalidFileURLData` |
| 38 | 行为 | Book drop falls back to u r l object after file u r l data error | P1 | ✅ 已覆盖 | `BookDBViewPluginTests.swift` | `bookDropFallsBackToURLObjectAfterFileURLDataError` |
| 39 | 行为 | Book drop skips empty import after provider failure | P1 | ✅ 已覆盖 | `BookDBViewPluginTests.swift` | `bookDropSkipsEmptyImportAfterProviderFailure` |
| 40 | 行为 | Book import does not start while already importing | P0 | ✅ 已覆盖 | `BookDBViewPluginTests.swift` | `bookImportDoesNotStartWhileAlreadyImporting` |
| 41 | 行为 | Book import allows readable local items without security scope | P1 | ✅ 已覆盖 | `BookDBViewPluginTests.swift` | `bookImportAllowsReadableLocalItemsWithoutSecurityScope` |
| 42 | 行为 | Book playback ordering uses relative paths | P0 | ✅ 已覆盖 | `BookDBViewPluginTests.swift` | `bookPlaybackOrderingUsesRelativePaths` |
| 43 | 行为 | Book playback ordering rejects sibling prefix paths | P0 | ✅ 已覆盖 | `BookDBViewPluginTests.swift` | `bookPlaybackOrderingRejectsSiblingPrefixPaths` |
| 44 | 行为 | Book playback ordering checks playable child containment without scanning | P1 | ✅ 已覆盖 | `BookDBViewPluginTests.swift` | `bookPlaybackOrderingChecksPlayableChildContainmentWithoutScanning` |
| 45 | 行为 | Book playback ordering matches symlinked playable children | P0 | ✅ 已覆盖 | `BookDBViewPluginTests.swift` | `bookPlaybackOrderingMatchesSymlinkedPlayableChildren` |
| 46 | 行为 | Book grid loads playable children asynchronously | P0 | ✅ 已覆盖 | `BookDBViewPluginTests.swift` | `bookGridLoadsPlayableChildrenAsynchronously` |
| 47 | 行为 | Book playback ordering separates distinct dangling symlinked chapters | P1 | ✅ 已覆盖 | `BookDBViewPluginTests.swift` | `bookPlaybackOrderingSeparatesDistinctDanglingSymlinkedChapters` |
| 48 | 行为 | Book tile reloads when database root changes | P0 | ✅ 已覆盖 | `BookDBViewPluginTests.swift` | `bookTileReloadsWhenDatabaseRootChanges` |
| 49 | 状态 | Book tile reloads when matching book state changes | P0 | ✅ 已覆盖 | `BookDBViewPluginTests.swift` | `bookTileReloadsWhenMatchingBookStateChanges` |
| 50 | 状态 | Book d b view finds symlinked book state | P2 | ✅ 已覆盖 | `BookDBViewPluginTests.swift` | `bookDBViewFindsSymlinkedBookState` |
| 51 | 行为 | Book grid only applies current update generation | P0 | ✅ 已覆盖 | `BookDBViewPluginTests.swift` | `bookGridOnlyAppliesCurrentUpdateGeneration` |
| 52 | 行为 | Book grid scheduling refresh invalidates pending update results | P1 | ✅ 已覆盖 | `BookDBViewPluginTests.swift` | `bookGridSchedulingRefreshInvalidatesPendingUpdateResults` |
| 53 | 行为 | Book grid only applies current playback request generation | P0 | ✅ 已覆盖 | `BookDBViewPluginTests.swift` | `bookGridOnlyAppliesCurrentPlaybackRequestGeneration` |
| 54 | 行为 | Book grid invalidates pending playback when disappearing | P1 | ✅ 已覆盖 | `BookDBViewPluginTests.swift` | `bookGridInvalidatesPendingPlaybackWhenDisappearing` |
| 55 | 行为 | Book grid only reports no playable chapters for current selection | P0 | ✅ 已覆盖 | `BookDBViewPluginTests.swift` | `bookGridOnlyReportsNoPlayableChaptersForCurrentSelection` |
| 56 | 行为 | Book grid selection matches symlinked book u r ls | P0 | ✅ 已覆盖 | `BookDBViewPluginTests.swift` | `bookGridSelectionMatchesSymlinkedBookURLs` |
| 57 | 行为 | Book grid selection uses readable accessibility label | P0 | ✅ 已覆盖 | `BookDBViewPluginTests.swift` | `bookGridSelectionUsesReadableAccessibilityLabel` |
| 58 | 插件 | Book d b plugin contributes settings entry through contract | P0 | ✅ 已覆盖 | `BookDBViewPluginTests.swift` | `bookDBPluginContributesSettingsEntryThroughContract` |
| 59 | 行为 | Book tree builder builds nested directory structure | P0 | ✅ 已覆盖 | `BookDBViewPluginTests.swift` | `bookTreeBuilderBuildsNestedDirectoryStructure` |
| 60 | 行为 | Book tree builder skips hidden and unsupported files | P0 | ✅ 已覆盖 | `BookDBViewPluginTests.swift` | `bookTreeBuilderSkipsHiddenAndUnsupportedFiles` |
| 61 | 行为 | Book tree builder returns empty for missing root | P1 | ✅ 已覆盖 | `BookDBViewPluginTests.swift` | `bookTreeBuilderReturnsEmptyForMissingRoot` |

## 覆盖率统计

- P0: 39 / 39 ✅
- P1: 20 / 20 ✅
- P2: 2 / 2 ✅

**总计: 61 / 61**（本包 `Tests/` 中已声明的 `@Test` 全部登记）

## 测试文件

- `BookDBViewCoverageTests.swift` — 19 条用例
- `BookDBViewPluginTests.swift` — 42 条用例

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
cd Packages/PluginBookDBView
swift test
```

## 维护规则

1. **新增公开 API** → 先在 TestPlan 登记测试用例,再写实现
2. **Bug 修复** → 追加回归用例,标注触发条件
3. **删除用例** → 在 commit message 说明理由
4. **状态同步** → 实现后更新 TestPlan,标记 ✅ 并填写测试方法名
