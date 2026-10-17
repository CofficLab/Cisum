# TestPlan — PluginBook

## 包概述

有声书主插件：注册书籍场景栈、播放器、数据库视图与相关 Provider。

公开类型:
- `BookPlugin`
- `BookRootView`

### README 中的测试说明（摘自 `README.md`）

- **Test files:**
  - `Tests/BookPluginTests.swift` — the single, large test target.
- **Key scenarios tested:**
  - `BookPluginInfo` metadata exports: `dirName == "audios_book"`,
    `iconName == "book"`, `supportedExtensions` includes `m4b` and the full set of
    player-recognized audio extensions.
  - `BookDB.downloadProgressPercentText(forFraction:)` clamps NaN/negative/over-1 to
    `"0"`/`"100"`.
  - `BookDB` emits typed deletion events with the deleted URLs.
  - Library item support: symlinked book folders count as collections, folders with
    only images/notes are rejected, playable-child counting ignores non-audio files.
  - Symlink-aware dedup: `BookDB.uniqueSupportedBookLibraryItems` collapses
    real/symlinked duplicates by resolved identity while keeping distinct dangling
    symlink books separate.
  - `BookCoverRepo.coverCandidates` ordering (named covers first, direct files
    before nested folders, audio chapters ignored) and `BookCoverCache`
    concurrent-load dedup plus clear-invalidation behavior.
  - `BookSettingRepo` URL/time parsing: empty/legacy/whitespace inputs, local zero
    overriding stale cloud time, NaN/inf/-1 fallbacks, storage normalization.
  - `BookDB.contains` delete semantics (nested chapters, sibling books, symlinked
    roots, dangling symlinks, root disk), `BookRepo.isDisplayableLibraryItem`,
    stable path ordering on full/incremental sync, symlink matching, next-book
    traversal, batch deletion, order repair.
  - `BookRootViewModelTests` / `BookStorageObserverTests` use probe providers to
    verify loading completion, "disk not found" errors, storage-event reloads,
    stale-generation guarding, and observer cancellation.
- **Running tests:**
  ```bash
  cd /Users/angel/Code/Coffic/Cisum/Packages/PluginBook
  swift test
  ```

## 测试用例清单

下表由 `Tests/` 下的真实 `@Test` 声明自动生成，方法名与代码一一对应。

| ID | 类别 | 描述 | 优先级 | 状态 | 测试文件 | 测试方法 |
|----|------|------|--------|------|----------|----------|
| 1 | 插件 | Book plugin info exports metadata | P0 | ✅ 已覆盖 | `BookPluginTests.swift` | `bookPluginInfoExportsMetadata` |
| 2 | 插件 | Book plugin supports player recognized audiobook extensions | P0 | ✅ 已覆盖 | `BookPluginTests.swift` | `bookPluginSupportsPlayerRecognizedAudiobookExtensions` |
| 3 | 行为 | Book d b download progress percent text uses fraction input | P0 | ✅ 已覆盖 | `BookPluginTests.swift` | `bookDBDownloadProgressPercentTextUsesFractionInput` |
| 4 | 行为 | Book disk creation replaces dangling symlink | P1 | ✅ 已覆盖 | `BookPluginTests.swift` | `bookDiskCreationReplacesDanglingSymlink` |
| 5 | 行为 | Symlinked book folder is supported library item | P0 | ✅ 已覆盖 | `BookPluginTests.swift` | `symlinkedBookFolderIsSupportedLibraryItem` |
| 6 | 行为 | Book library item support counts playable children without images | P1 | ✅ 已覆盖 | `BookPluginTests.swift` | `bookLibraryItemSupportCountsPlayableChildrenWithoutImages` |
| 7 | 行为 | Book library item support rejects folders without playable children | P1 | ✅ 已覆盖 | `BookPluginTests.swift` | `bookLibraryItemSupportRejectsFoldersWithoutPlayableChildren` |
| 8 | 行为 | Book d b unique supported items deduplicates by resolved identity | P1 | ✅ 已覆盖 | `BookPluginTests.swift` | `bookDBUniqueSupportedItemsDeduplicatesByResolvedIdentity` |
| 9 | 行为 | Book d b unique supported items keeps distinct dangling symlink books | P1 | ✅ 已覆盖 | `BookPluginTests.swift` | `bookDBUniqueSupportedItemsKeepsDistinctDanglingSymlinkBooks` |
| 10 | 行为 | Book path containment keeps distinct chapters under dangling symlink books | P1 | ✅ 已覆盖 | `BookPluginTests.swift` | `bookPathContainmentKeepsDistinctChaptersUnderDanglingSymlinkBooks` |
| 11 | 模型 | Book model treats symlinked book folder as collection | P0 | ✅ 已覆盖 | `BookPluginTests.swift` | `bookModelTreatsSymlinkedBookFolderAsCollection` |
| 12 | 行为 | Book cover candidates include standalone book file | P0 | ✅ 已覆盖 | `BookPluginTests.swift` | `bookCoverCandidatesIncludeStandaloneBookFile` |
| 13 | 行为 | Book cover candidates scan direct files before nested folders | P0 | ✅ 已覆盖 | `BookPluginTests.swift` | `bookCoverCandidatesScanDirectFilesBeforeNestedFolders` |
| 14 | 行为 | Book cover candidates ignore audio chapters in folders | P0 | ✅ 已覆盖 | `BookPluginTests.swift` | `bookCoverCandidatesIgnoreAudioChaptersInFolders` |
| 15 | 行为 | Book cover candidates prefer named cover images | P0 | ✅ 已覆盖 | `BookPluginTests.swift` | `bookCoverCandidatesPreferNamedCoverImages` |
| 16 | 缓存 | Book cover cache deduplicates concurrent loads and caches missing covers | P1 | ✅ 已覆盖 | `BookPluginTests.swift` | `bookCoverCacheDeduplicatesConcurrentLoadsAndCachesMissingCovers` |
| 17 | 存储 | Clearing book cover cache prevents in flight result from being restored | P0 | ✅ 已覆盖 | `BookPluginTests.swift` | `clearingBookCoverCachePreventsInFlightResultFromBeingRestored` |
| 18 | 行为 | Empty cloud book u r l is ignored | P1 | ✅ 已覆盖 | `BookPluginTests.swift` | `emptyCloudBookURLIsIgnored` |
| 19 | 行为 | Local zero book time overrides stale cloud time | P1 | ✅ 已覆盖 | `BookPluginTests.swift` | `localZeroBookTimeOverridesStaleCloudTime` |
| 20 | 行为 | Invalid local book times fall back to cloud | P1 | ✅ 已覆盖 | `BookPluginTests.swift` | `invalidLocalBookTimesFallBackToCloud` |
| 21 | 归一化 | Book times are normalized before storage | P0 | ✅ 已覆盖 | `BookPluginTests.swift` | `bookTimesAreNormalizedBeforeStorage` |
| 22 | 行为 | Deleted book folder contains nested records | P0 | ✅ 已覆盖 | `BookPluginTests.swift` | `deletedBookFolderContainsNestedRecords` |
| 23 | 状态 | Deleted book folder contains saved state | P0 | ✅ 已覆盖 | `BookPluginTests.swift` | `deletedBookFolderContainsSavedState` |
| 24 | 状态 | Book state does not match distinct dangling symlinked current chapter | P1 | ✅ 已覆盖 | `BookPluginTests.swift` | `bookStateDoesNotMatchDistinctDanglingSymlinkedCurrentChapter` |
| 25 | 行为 | Deleted symlinked book folder contains real path records | P0 | ✅ 已覆盖 | `BookPluginTests.swift` | `deletedSymlinkedBookFolderContainsRealPathRecords` |
| 26 | 行为 | Deleted dangling symlink book folder contains lexical child records | P1 | ✅ 已覆盖 | `BookPluginTests.swift` | `deletedDanglingSymlinkBookFolderContainsLexicalChildRecords` |
| 27 | 行为 | Deleted root book folder contains nested records | P0 | ✅ 已覆盖 | `BookPluginTests.swift` | `deletedRootBookFolderContainsNestedRecords` |
| 28 | 行为 | Displayable library items include top level standalone books | P0 | ✅ 已覆盖 | `BookPluginTests.swift` | `displayableLibraryItemsIncludeTopLevelStandaloneBooks` |
| 29 | 行为 | Displayable library items include real books under symlinked library root | P0 | ✅ 已覆盖 | `BookPluginTests.swift` | `displayableLibraryItemsIncludeRealBooksUnderSymlinkedLibraryRoot` |
| 30 | 行为 | Displayable library items exclude nested chapters | P0 | ✅ 已覆盖 | `BookPluginTests.swift` | `displayableLibraryItemsExcludeNestedChapters` |
| 31 | 行为 | Displayable library items exclude empty top level folders | P1 | ✅ 已覆盖 | `BookPluginTests.swift` | `displayableLibraryItemsExcludeEmptyTopLevelFolders` |
| 32 | 行为 | Book repo waits for initial disk sync before returning books | P0 | ✅ 已覆盖 | `BookPluginTests.swift` | `bookRepoWaitsForInitialDiskSyncBeforeReturningBooks` |
| 33 | 行为 | Book d b full sync inserts books in stable path order | P0 | ✅ 已覆盖 | `BookPluginTests.swift` | `bookDBFullSyncInsertsBooksInStablePathOrder` |
| 34 | 行为 | Book d b update sync appends new books in stable path order | P0 | ✅ 已覆盖 | `BookPluginTests.swift` | `bookDBUpdateSyncAppendsNewBooksInStablePathOrder` |
| 35 | 行为 | Book d b update sync matches existing book through symlink | P0 | ✅ 已覆盖 | `BookPluginTests.swift` | `bookDBUpdateSyncMatchesExistingBookThroughSymlink` |
| 36 | 状态 | Book d b full sync keeps symlinked existing book state | P0 | ✅ 已覆盖 | `BookPluginTests.swift` | `bookDBFullSyncKeepsSymlinkedExistingBookState` |
| 37 | 行为 | Book d b full sync deduplicates symlinked scan items | P1 | ✅ 已覆盖 | `BookPluginTests.swift` | `bookDBFullSyncDeduplicatesSymlinkedScanItems` |
| 38 | 状态 | Book d b finds book state through symlink | P0 | ✅ 已覆盖 | `BookPluginTests.swift` | `bookDBFindsBookStateThroughSymlink` |
| 39 | 行为 | Book d b sync keeps symlinked book folder displayable | P0 | ✅ 已覆盖 | `BookPluginTests.swift` | `bookDBSyncKeepsSymlinkedBookFolderDisplayable` |
| 40 | 行为 | Book d b full sync ignores unsupported files | P0 | ✅ 已覆盖 | `BookPluginTests.swift` | `bookDBFullSyncIgnoresUnsupportedFiles` |
| 41 | 行为 | Book d b update sync ignores unsupported files and folders | P0 | ✅ 已覆盖 | `BookPluginTests.swift` | `bookDBUpdateSyncIgnoresUnsupportedFilesAndFolders` |
| 42 | 行为 | Book d b next book uses current book order | P0 | ✅ 已覆盖 | `BookPluginTests.swift` | `bookDBNextBookUsesCurrentBookOrder` |
| 43 | 行为 | Book d b next book skips symlinked duplicate book | P1 | ✅ 已覆盖 | `BookPluginTests.swift` | `bookDBNextBookSkipsSymlinkedDuplicateBook` |
| 44 | 行为 | Book d b delete returns nil when only next book is symlinked duplicate | P1 | ✅ 已覆盖 | `BookPluginTests.swift` | `bookDBDeleteReturnsNilWhenOnlyNextBookIsSymlinkedDuplicate` |
| 45 | 行为 | Book d b batch delete skips books deleted later in same batch | P0 | ✅ 已覆盖 | `BookPluginTests.swift` | `bookDBBatchDeleteSkipsBooksDeletedLaterInSameBatch` |
| 46 | 行为 | Book d b delete by i d publishes typed deleted u r ls | P0 | ✅ 已覆盖 | `BookPluginTests.swift` | `bookDBDeleteByIDPublishesTypedDeletedURLs` |
| 47 | 行为 | Book d b find or create returns inserted book | P0 | ✅ 已覆盖 | `BookPluginTests.swift` | `bookDBFindOrCreateReturnsInsertedBook` |
| 48 | 行为 | Book d b full sync repairs duplicate legacy book orders | P1 | ✅ 已覆盖 | `BookPluginTests.swift` | `bookDBFullSyncRepairsDuplicateLegacyBookOrders` |
| 49 | 行为 | Book d b keeps unique existing book orders | P0 | ✅ 已覆盖 | `BookPluginTests.swift` | `bookDBKeepsUniqueExistingBookOrders` |
| 50 | 行为 | Reload with available provider finishes loading | P0 | ✅ 已覆盖 | `BookPluginTests.swift` | `reloadWithAvailableProviderFinishesLoading` |
| 51 | 行为 | Reload without provider reports disk not found | P1 | ✅ 已覆盖 | `BookPluginTests.swift` | `reloadWithoutProviderReportsDiskNotFound` |
| 52 | 行为 | Storage change reloads and emits new notice | P0 | ✅ 已覆盖 | `BookPluginTests.swift` | `storageChangeReloadsAndEmitsNewNotice` |
| 53 | 行为 | Stale reload result does not override newer generation | P1 | ✅ 已覆盖 | `BookPluginTests.swift` | `staleReloadResultDoesNotOverrideNewerGeneration` |
| 54 | 观察者 | Observer drives reload on storage events | P0 | ✅ 已覆盖 | `BookPluginTests.swift` | `observerDrivesReloadOnStorageEvents` |
| 55 | 观察者 | Observer cancellation is idempotent | P1 | ✅ 已覆盖 | `BookPluginTests.swift` | `observerCancellationIsIdempotent` |

## 覆盖率统计

- P0: 35 / 35 ✅
- P1: 20 / 20 ✅
- P2: 0 / 0

**总计: 55 / 55**（本包 `Tests/` 中已声明的 `@Test` 全部登记）

## 测试文件

- `BookPluginTests.swift` — 55 条用例

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
cd Packages/PluginBook
swift test
```

## 维护规则

1. **新增公开 API** → 先在 TestPlan 登记测试用例,再写实现
2. **Bug 修复** → 追加回归用例,标注触发条件
3. **删除用例** → 在 commit message 说明理由
4. **状态同步** → 实现后更新 TestPlan,标记 ✅ 并填写测试方法名
