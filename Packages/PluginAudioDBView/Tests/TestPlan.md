# TestPlan — PluginAudioDBView

## 包概述

音乐数据库视图：列表 / 网格布局、筛选排序与选择态的视图与视图模型。

公开类型:
- `AudioDBViewPlugin`
- `AudioLibraryEvent`
- `AudioLibraryObserverHandle`
- `AudioLibraryCapability`
- `AudioLibraryCapabilityAdapter`
- `AudioDBPluginInfo`
- `AudioDBDependencies`
- `AudioDBRootView`
- `AudioDBView`

### README 中的测试说明（摘自 `README.md`）

- **Test files**:
  - `Tests/AudioDBViewPluginTests.swift` — list/pagination/import policy logic and metadata.
  - `Tests/AudioDBViewCoverageTests.swift` — diagnostics factory, tree builder, and tree view model coverage.
  - `Tests/AudioDBViewPluginSceneTests.swift` — scene-provider resolution timing regression.
- **Key scenarios tested**:
  - `AudioDBViewModel.sortMode` parsing trims whitespace and falls back to `.none`.
  - Import cleanup: copied files are removed when a batch fails or the repository is unavailable; symlinked files are copied as standalone regular files; destination names avoid dangling symlinks.
  - `AudioListLoadPolicy`: next-load offset, page advancement, no-skip after displayed rows shrink, page rebasing after deletion, generation checks, symlink dedup, has-more detection, stale-result handling, and load-more triggering by visible index.
  - `AudioListDeletionPolicy`: matches symlinked/dangling-symlink rows, counts only displayed removed rows, updates totals for unloaded deleted rows, and invalidates pending loads.
  - `AudioStorageDiagnosticsFactory`: reads storage root and builds the audio disk path, falling back when storage is missing.
  - `AudioTreeBuilder`: scans files and folders (directories first, hidden and unsupported files skipped), returns empty for a missing directory, case-insensitive extension checks, and `AudioTreeNode` computed properties.
  - Scene regression: the music tab is contributed only with the live scene provider resolved at `onReady`, scene switches gate contribution, and duplicate scene registration throws until unregistered.
- **Running tests**:
  ```bash
  cd /Users/angel/Code/Coffic/Cisum/Packages/PluginAudioDBView
  swift test
  ```

## 测试用例清单

下表由 `Tests/` 下的真实 `@Test` 声明自动生成，方法名与代码一一对应。

| ID | 类别 | 描述 | 优先级 | 状态 | 测试文件 | 测试方法 |
|----|------|------|--------|------|----------|----------|
| 1 | 行为 | Make reads storage root and builds audio disk path | P0 | ✅ 已覆盖 | `AudioDBViewCoverageTests.swift` | `makeReadsStorageRootAndBuildsAudioDiskPath` |
| 2 | 行为 | Make falls back when storage missing | P1 | ✅ 已覆盖 | `AudioDBViewCoverageTests.swift` | `makeFallsBackWhenStorageMissing` |
| 3 | 行为 | Build root children scans files and folders | P0 | ✅ 已覆盖 | `AudioDBViewCoverageTests.swift` | `buildRootChildrenScansFilesAndFolders` |
| 4 | 行为 | Build root children returns empty for missing directory | P1 | ✅ 已覆盖 | `AudioDBViewCoverageTests.swift` | `buildRootChildrenReturnsEmptyForMissingDirectory` |
| 5 | 行为 | Is supported audio file checks extensions case insensitively | P0 | ✅ 已覆盖 | `AudioDBViewCoverageTests.swift` | `isSupportedAudioFileChecksExtensionsCaseInsensitively` |
| 6 | 行为 | Tree node computed properties | P0 | ✅ 已覆盖 | `AudioDBViewCoverageTests.swift` | `treeNodeComputedProperties` |
| 7 | 行为 | Handle on appear loads children from disk | P0 | ✅ 已覆盖 | `AudioDBViewCoverageTests.swift` | `handleOnAppearLoadsChildrenFromDisk` |
| 8 | 行为 | Handle on appear without disk stays empty | P1 | ✅ 已覆盖 | `AudioDBViewCoverageTests.swift` | `handleOnAppearWithoutDiskStaysEmpty` |
| 9 | 行为 | Scene change updates music scene flag | P0 | ✅ 已覆盖 | `AudioDBViewCoverageTests.swift` | `sceneChangeUpdatesMusicSceneFlag` |
| 10 | 观察者 | Cancelling observer stops updates | P1 | ✅ 已覆盖 | `AudioDBViewCoverageTests.swift` | `cancellingObserverStopsUpdates` |
| 11 | 行为 | Init without scene keeps current flag | P1 | ✅ 已覆盖 | `AudioDBViewCoverageTests.swift` | `initWithoutSceneKeepsCurrentFlag` |
| 12 | 行为 | Empty defaults are safe | P1 | ✅ 已覆盖 | `AudioDBViewCoverageTests.swift` | `emptyDefaultsAreSafe` |
| 13 | 存储 | Init stores all fields | P0 | ✅ 已覆盖 | `AudioDBViewCoverageTests.swift` | `initStoresAllFields` |
| 14 | 行为 | Applies initial playback u r l on registration | P0 | ✅ 已覆盖 | `AudioDBViewCoverageTests.swift` | `appliesInitialPlaybackURLOnRegistration` |
| 15 | 行为 | Forwards asset changed events | P0 | ✅ 已覆盖 | `AudioDBViewCoverageTests.swift` | `forwardsAssetChangedEvents` |
| 16 | 观察者 | Cancelling observer stops forwards | P1 | ✅ 已覆盖 | `AudioDBViewCoverageTests.swift` | `cancellingObserverStopsForwards` |
| 17 | 状态 | Hides empty repository state until an available repository loads successfully | P1 | ✅ 已覆盖 | `AudioDBViewCoverageTests.swift` | `hidesEmptyRepositoryStateUntilAnAvailableRepositoryLoadsSuccessfully` |
| 18 | 行为 | Storage availability change retries previously unavailable repository | P1 | ✅ 已覆盖 | `AudioDBViewCoverageTests.swift` | `storageAvailabilityChangeRetriesPreviouslyUnavailableRepository` |
| 19 | 视图模型 | Db events forward to sorting and root view models | P2 | ✅ 已覆盖 | `AudioDBViewCoverageTests.swift` | `dbEventsForwardToSortingAndRootViewModels` |
| 20 | 观察者 | Cancelling observer stops forwarding | P1 | ✅ 已覆盖 | `AudioDBViewCoverageTests.swift` | `cancellingObserverStopsForwarding` |
| 21 | 排序 | Sort mode parsing trims and falls back | P0 | ✅ 已覆盖 | `AudioDBViewCoverageTests.swift` | `sortModeParsingTrimsAndFallsBack` |
| 22 | 排序 | Handle sorting normalizes mode | P0 | ✅ 已覆盖 | `AudioDBViewCoverageTests.swift` | `handleSortingNormalizesMode` |
| 23 | 行为 | Contributes music tab with scene provider resolved at ready | P0 | ✅ 已覆盖 | `AudioDBViewPluginSceneTests.swift` | `contributesMusicTabWithSceneProviderResolvedAtReady` |
| 24 | 行为 | Duplicate scene registration throws until unregistered | P1 | ✅ 已覆盖 | `AudioDBViewPluginSceneTests.swift` | `duplicateSceneRegistrationThrowsUntilUnregistered` |
| 25 | 元数据 | Audio d b info exports metadata | P0 | ✅ 已覆盖 | `AudioDBViewPluginTests.swift` | `audioDBInfoExportsMetadata` |
| 26 | 排序 | Audio d b sort mode restores trimmed notification values | P0 | ✅ 已覆盖 | `AudioDBViewPluginTests.swift` | `audioDBSortModeRestoresTrimmedNotificationValues` |
| 27 | 行为 | Audio import cleans copied files when batch fails | P1 | ✅ 已覆盖 | `AudioDBViewPluginTests.swift` | `audioImportCleansCopiedFilesWhenBatchFails` |
| 28 | 行为 | Audio import cleans copied files when repository is unavailable | P1 | ✅ 已覆盖 | `AudioDBViewPluginTests.swift` | `audioImportCleansCopiedFilesWhenRepositoryIsUnavailable` |
| 29 | 行为 | Audio import copies symlinked files as standalone files | P0 | ✅ 已覆盖 | `AudioDBViewPluginTests.swift` | `audioImportCopiesSymlinkedFilesAsStandaloneFiles` |
| 30 | 行为 | Audio import avoids dangling symlink destination names | P1 | ✅ 已覆盖 | `AudioDBViewPluginTests.swift` | `audioImportAvoidsDanglingSymlinkDestinationNames` |
| 31 | 行为 | Audio list rejects stale delete offsets | P1 | ✅ 已覆盖 | `AudioDBViewPluginTests.swift` | `audioListRejectsStaleDeleteOffsets` |
| 32 | 行为 | Audio list loads more from current loaded count | P0 | ✅ 已覆盖 | `AudioDBViewPluginTests.swift` | `audioListLoadsMoreFromCurrentLoadedCount` |
| 33 | 行为 | Audio list load more does not skip after displayed rows shrink | P0 | ✅ 已覆盖 | `AudioDBViewPluginTests.swift` | `audioListLoadMoreDoesNotSkipAfterDisplayedRowsShrink` |
| 34 | 行为 | Audio list deletion rebases pagination to remaining displayed rows | P0 | ✅ 已覆盖 | `AudioDBViewPluginTests.swift` | `audioListDeletionRebasesPaginationToRemainingDisplayedRows` |
| 35 | 行为 | Audio list load more offset advances by fetched pages after deduplication | P0 | ✅ 已覆盖 | `AudioDBViewPluginTests.swift` | `audioListLoadMoreOffsetAdvancesByFetchedPagesAfterDeduplication` |
| 36 | 行为 | Audio list load more trigger uses visible index | P0 | ✅ 已覆盖 | `AudioDBViewPluginTests.swift` | `audioListLoadMoreTriggerUsesVisibleIndex` |
| 37 | 行为 | Audio list only applies current load generation | P0 | ✅ 已覆盖 | `AudioDBViewPluginTests.swift` | `audioListOnlyAppliesCurrentLoadGeneration` |
| 38 | 行为 | Audio list load more deduplicates symlinked rows | P1 | ✅ 已覆盖 | `AudioDBViewPluginTests.swift` | `audioListLoadMoreDeduplicatesSymlinkedRows` |
| 39 | 行为 | Audio list load more tracks fetched page size after deduplication | P0 | ✅ 已覆盖 | `AudioDBViewPluginTests.swift` | `audioListLoadMoreTracksFetchedPageSizeAfterDeduplication` |
| 40 | 状态 | Stale audio list results keep current loading state | P1 | ✅ 已覆盖 | `AudioDBViewPluginTests.swift` | `staleAudioListResultsKeepCurrentLoadingState` |
| 41 | 行为 | Audio list current page refresh clears stale pagination loading | P1 | ✅ 已覆盖 | `AudioDBViewPluginTests.swift` | `audioListCurrentPageRefreshClearsStalePaginationLoading` |
| 42 | 行为 | Audio list deletion invalidates pending loads | P1 | ✅ 已覆盖 | `AudioDBViewPluginTests.swift` | `audioListDeletionInvalidatesPendingLoads` |
| 43 | 行为 | Audio list deletion matches symlinked rows | P0 | ✅ 已覆盖 | `AudioDBViewPluginTests.swift` | `audioListDeletionMatchesSymlinkedRows` |
| 44 | 行为 | Audio list deletion matches dangling symlink rows | P1 | ✅ 已覆盖 | `AudioDBViewPluginTests.swift` | `audioListDeletionMatchesDanglingSymlinkRows` |
| 45 | 行为 | Audio list deletion counts only displayed removed rows | P0 | ✅ 已覆盖 | `AudioDBViewPluginTests.swift` | `audioListDeletionCountsOnlyDisplayedRemovedRows` |
| 46 | 行为 | Audio list deletion updates total for unloaded deleted rows | P0 | ✅ 已覆盖 | `AudioDBViewPluginTests.swift` | `audioListDeletionUpdatesTotalForUnloadedDeletedRows` |
| 47 | 行为 | Audio list deletion counts distinct dangling symlink rows | P1 | ✅ 已覆盖 | `AudioDBViewPluginTests.swift` | `audioListDeletionCountsDistinctDanglingSymlinkRows` |
| 48 | 行为 | Audio list only applies current selection playback | P0 | ✅ 已覆盖 | `AudioDBViewPluginTests.swift` | `audioListOnlyAppliesCurrentSelectionPlayback` |
| 49 | 行为 | Audio list selection treats symlinked audio as same file | P0 | ✅ 已覆盖 | `AudioDBViewPluginTests.swift` | `audioListSelectionTreatsSymlinkedAudioAsSameFile` |
| 50 | 行为 | Audio list selection keeps distinct dangling symlink audio separate | P1 | ✅ 已覆盖 | `AudioDBViewPluginTests.swift` | `audioListSelectionKeepsDistinctDanglingSymlinkAudioSeparate` |
| 51 | 行为 | Audio delete only resets playback for still current deleted audio | P1 | ✅ 已覆盖 | `AudioDBViewPluginTests.swift` | `audioDeleteOnlyResetsPlaybackForStillCurrentDeletedAudio` |
| 52 | 行为 | Audio delete resets playback for symlinked current audio | P1 | ✅ 已覆盖 | `AudioDBViewPluginTests.swift` | `audioDeleteResetsPlaybackForSymlinkedCurrentAudio` |
| 53 | 行为 | Audio delete resets playback for dangling symlink current audio | P1 | ✅ 已覆盖 | `AudioDBViewPluginTests.swift` | `audioDeleteResetsPlaybackForDanglingSymlinkCurrentAudio` |
| 54 | 行为 | Audio delete does not reset playback for distinct dangling symlink audio | P1 | ✅ 已覆盖 | `AudioDBViewPluginTests.swift` | `audioDeleteDoesNotResetPlaybackForDistinctDanglingSymlinkAudio` |
| 55 | 行为 | Audio item only applies current file size | P0 | ✅ 已覆盖 | `AudioDBViewPluginTests.swift` | `audioItemOnlyAppliesCurrentFileSize` |
| 56 | 行为 | Audio item applies file size for symlinked current file | P0 | ✅ 已覆盖 | `AudioDBViewPluginTests.swift` | `audioItemAppliesFileSizeForSymlinkedCurrentFile` |
| 57 | 行为 | Audio item does not apply file size across distinct dangling symlinks | P1 | ✅ 已覆盖 | `AudioDBViewPluginTests.swift` | `audioItemDoesNotApplyFileSizeAcrossDistinctDanglingSymlinks` |
| 58 | 策略 | Audio item file size read policy reads foundation attributes | P0 | ✅ 已覆盖 | `AudioDBViewPluginTests.swift` | `audioItemFileSizeReadPolicyReadsFoundationAttributes` |
| 59 | 策略 | Audio item file size read policy normalizes invalid sizes | P1 | ✅ 已覆盖 | `AudioDBViewPluginTests.swift` | `audioItemFileSizeReadPolicyNormalizesInvalidSizes` |
| 60 | 策略 | Audio item file size display policy separates loading and unavailable | P1 | ✅ 已覆盖 | `AudioDBViewPluginTests.swift` | `audioItemFileSizeDisplayPolicySeparatesLoadingAndUnavailable` |
| 61 | 存储 | Audio item file size cache stores hits and misses | P0 | ✅ 已覆盖 | `AudioDBViewPluginTests.swift` | `audioItemFileSizeCacheStoresHitsAndMisses` |
| 62 | 缓存 | Audio item file size cache allows retry after download completes | P0 | ✅ 已覆盖 | `AudioDBViewPluginTests.swift` | `audioItemFileSizeCacheAllowsRetryAfterDownloadCompletes` |
| 63 | 缓存 | Audio item file size cache matches symlinked files | P0 | ✅ 已覆盖 | `AudioDBViewPluginTests.swift` | `audioItemFileSizeCacheMatchesSymlinkedFiles` |
| 64 | 行为 | Audio item export uses human numbering for duplicate downloads | P1 | ✅ 已覆盖 | `AudioDBViewPluginTests.swift` | `audioItemExportUsesHumanNumberingForDuplicateDownloads` |
| 65 | 行为 | Audio item export avoids dangling symlink destination names | P1 | ✅ 已覆盖 | `AudioDBViewPluginTests.swift` | `audioItemExportAvoidsDanglingSymlinkDestinationNames` |
| 66 | 行为 | Audio item reveal in finder requires existing path entry | P0 | ✅ 已覆盖 | `AudioDBViewPluginTests.swift` | `audioItemRevealInFinderRequiresExistingPathEntry` |
| 67 | 行为 | Audio item export copies symlinked files as standalone files | P0 | ✅ 已覆盖 | `AudioDBViewPluginTests.swift` | `audioItemExportCopiesSymlinkedFilesAsStandaloneFiles` |
| 68 | 行为 | Audio item export creates missing downloads directory | P1 | ✅ 已覆盖 | `AudioDBViewPluginTests.swift` | `audioItemExportCreatesMissingDownloadsDirectory` |
| 69 | 筛选 | Audio import filters unsupported dropped items | P0 | ✅ 已覆盖 | `AudioDBViewPluginTests.swift` | `audioImportFiltersUnsupportedDroppedItems` |
| 70 | 行为 | Audio import deduplicates symlinked import sources | P1 | ✅ 已覆盖 | `AudioDBViewPluginTests.swift` | `audioImportDeduplicatesSymlinkedImportSources` |
| 71 | 行为 | Audio import keeps distinct dangling symlink import sources | P1 | ✅ 已覆盖 | `AudioDBViewPluginTests.swift` | `audioImportKeepsDistinctDanglingSymlinkImportSources` |
| 72 | 行为 | Audio drop reads file u r l data provider | P0 | ✅ 已覆盖 | `AudioDBViewPluginTests.swift` | `audioDropReadsFileURLDataProvider` |
| 73 | 行为 | Audio drop falls back to u r l object after invalid file u r l data | P1 | ✅ 已覆盖 | `AudioDBViewPluginTests.swift` | `audioDropFallsBackToURLObjectAfterInvalidFileURLData` |
| 74 | 行为 | Audio drop falls back to u r l object after file u r l data error | P1 | ✅ 已覆盖 | `AudioDBViewPluginTests.swift` | `audioDropFallsBackToURLObjectAfterFileURLDataError` |
| 75 | 行为 | Audio drop skips empty import after provider failure | P1 | ✅ 已覆盖 | `AudioDBViewPluginTests.swift` | `audioDropSkipsEmptyImportAfterProviderFailure` |
| 76 | 行为 | Audio import does not start while already importing | P0 | ✅ 已覆盖 | `AudioDBViewPluginTests.swift` | `audioImportDoesNotStartWhileAlreadyImporting` |
| 77 | 行为 | Audio import allows readable local files without security scope | P1 | ✅ 已覆盖 | `AudioDBViewPluginTests.swift` | `audioImportAllowsReadableLocalFilesWithoutSecurityScope` |
| 78 | 行为 | Audio tree builder builds nested directory structure | P0 | ✅ 已覆盖 | `AudioDBViewPluginTests.swift` | `audioTreeBuilderBuildsNestedDirectoryStructure` |
| 79 | 行为 | Audio tree builder skips hidden and unsupported files | P0 | ✅ 已覆盖 | `AudioDBViewPluginTests.swift` | `audioTreeBuilderSkipsHiddenAndUnsupportedFiles` |
| 80 | 行为 | Audio tree builder returns empty for missing root | P1 | ✅ 已覆盖 | `AudioDBViewPluginTests.swift` | `audioTreeBuilderReturnsEmptyForMissingRoot` |
| 81 | 行为 | Never overflows available height | P0 | ✅ 已覆盖 | `AudioLibrarySkeletonViewTests.swift` | `neverOverflowsAvailableHeight` |
| 82 | 行为 | Regression window row count | P2 | ✅ 已覆盖 | `AudioLibrarySkeletonViewTests.swift` | `regressionWindowRowCount` |
| 83 | 行为 | Degenerate input still renders one row | P2 | ✅ 已覆盖 | `AudioLibrarySkeletonViewTests.swift` | `degenerateInputStillRendersOneRow` |
| 84 | 行为 | Invalid height falls back to single row | P1 | ✅ 已覆盖 | `AudioLibrarySkeletonViewTests.swift` | `invalidHeightFallsBackToSingleRow` |
| 85 | 行为 | Caps row count for very tall container | P0 | ✅ 已覆盖 | `AudioLibrarySkeletonViewTests.swift` | `capsRowCountForVeryTallContainer` |
| 86 | 行为 | Row count is monotonic | P0 | ✅ 已覆盖 | `AudioLibrarySkeletonViewTests.swift` | `rowCountIsMonotonic` |
| 87 | 行为 | Repository unavailable stays silent during first run onboarding | P1 | ✅ 已覆盖 | `AudioRepositoryUnavailablePolicyTests.swift` | `repositoryUnavailableStaysSilentDuringFirstRunOnboarding` |
| 88 | 行为 | Repository unavailable is reported once storage is configured | P1 | ✅ 已覆盖 | `AudioRepositoryUnavailablePolicyTests.swift` | `repositoryUnavailableIsReportedOnceStorageIsConfigured` |
| 89 | 行为 | Available repository never reports an error | P1 | ✅ 已覆盖 | `AudioRepositoryUnavailablePolicyTests.swift` | `availableRepositoryNeverReportsAnError` |
| 90 | 行为 | Missing storage provider degrades to unconfigured | P1 | ✅ 已覆盖 | `AudioRepositoryUnavailablePolicyTests.swift` | `missingStorageProviderDegradesToUnconfigured` |
| 91 | 存储 | Apply stores progress and reports change | P0 | ✅ 已覆盖 | `CloudDownloadProgressStoreTests.swift` | `applyStoresProgressAndReportsChange` |
| 92 | 行为 | Apply never regresses | P0 | ✅ 已覆盖 | `CloudDownloadProgressStoreTests.swift` | `applyNeverRegresses` |
| 93 | 行为 | Apply clamps out of range and non finite values | P1 | ✅ 已覆盖 | `CloudDownloadProgressStoreTests.swift` | `applyClampsOutOfRangeAndNonFiniteValues` |
| 94 | 行为 | Progress falls back to snapshot when no event recorded | P0 | ✅ 已覆盖 | `CloudDownloadProgressStoreTests.swift` | `progressFallsBackToSnapshotWhenNoEventRecorded` |
| 95 | 行为 | Has active downloads only when progress incomplete | P0 | ✅ 已覆盖 | `CloudDownloadProgressStoreTests.swift` | `hasActiveDownloadsOnlyWhenProgressIncomplete` |
| 96 | 行为 | Remove clears deleted files | P0 | ✅ 已覆盖 | `CloudDownloadProgressStoreTests.swift` | `removeClearsDeletedFiles` |
| 97 | 行为 | Retain only drops entries no longer displayed | P0 | ✅ 已覆盖 | `CloudDownloadProgressStoreTests.swift` | `retainOnlyDropsEntriesNoLongerDisplayed` |
| 98 | 行为 | Identity matches through symbolic link | P0 | ✅ 已覆盖 | `CloudDownloadProgressStoreTests.swift` | `identityMatchesThroughSymbolicLink` |
| 99 | 行为 | Reload token is zero until download completes | P0 | ✅ 已覆盖 | `CloudDownloadProgressStoreTests.swift` | `reloadTokenIsZeroUntilDownloadCompletes` |
| 100 | 行为 | Reload token increments on completion | P0 | ✅ 已覆盖 | `CloudDownloadProgressStoreTests.swift` | `reloadTokenIncrementsOnCompletion` |
| 101 | 行为 | Reload token does not double count repeated completion | P0 | ✅ 已覆盖 | `CloudDownloadProgressStoreTests.swift` | `reloadTokenDoesNotDoubleCountRepeatedCompletion` |
| 102 | 行为 | Reload token allows repeat after eviction | P0 | ✅ 已覆盖 | `CloudDownloadProgressStoreTests.swift` | `reloadTokenAllowsRepeatAfterEviction` |
| 103 | 观察者 | Progress change publishes to observers | P0 | ✅ 已覆盖 | `CloudDownloadProgressStoreTests.swift` | `progressChangePublishesToObservers` |
| 104 | 行为 | 只有进行中的进度才渲染进度环 | P0 | ✅ 已覆盖 | `AudioItemAvatarPolicyTests.swift` | `activeProgressOnlyForInFlightDownloads` / `activeProgressIsNilWhenNotDownloading` / `activeProgressRejectsOutOfRangeValues` |
| 105 | 行为 | 头像重建标记随下载完成次数变化 | P0 | ✅ 已覆盖 | `AudioItemAvatarPolicyTests.swift` | `avatarIdentityChangesWithReloadToken` |
| 106 | 行为 | 仓库有文件且未选择时自动选中第一项 | P0 | ✅ 已覆盖 | `AudioDBViewCoverageTests.swift` | `selectsFirstFileWhenRepositoryHasFilesAndNothingIsSelected` |
| 107 | 行为 | 仓库为空时不自动选中 | P1 | ✅ 已覆盖 | `AudioDBViewCoverageTests.swift` | `doesNotSelectAnythingWhenRepositoryIsEmpty` |
| 108 | 行为 | 已有选中项时不覆盖为第一项 | P0 | ✅ 已覆盖 | `AudioDBViewCoverageTests.swift` | `keepsExistingSelectionInsteadOfOverwritingItWithFirstFile` |

## 覆盖率统计

- P0: 59 / 59 ✅
- P1: 46 / 46 ✅
- P2: 3 / 3 ✅

**总计: 108 / 108**（本包 `Tests/` 中已声明的 `@Test` 全部登记）

## 测试文件

- `AudioDBViewCoverageTests.swift` — 25 条用例
- `AudioDBViewPluginSceneTests.swift` — 2 条用例
- `AudioDBViewPluginTests.swift` — 56 条用例
- `AudioItemAvatarPolicyTests.swift` — 4 条用例
- `AudioLibrarySkeletonViewTests.swift` — 6 条用例
- `AudioRepositoryUnavailablePolicyTests.swift` — 4 条用例
- `CloudDownloadProgressStoreTests.swift` — 13 条用例

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
cd Packages/PluginAudioDBView
swift test
```

## 维护规则

1. **新增公开 API** → 先在 TestPlan 登记测试用例,再写实现
2. **Bug 修复** → 追加回归用例,标注触发条件
3. **删除用例** → 在 commit message 说明理由
4. **状态同步** → 实现后更新 TestPlan,标记 ✅ 并填写测试方法名
