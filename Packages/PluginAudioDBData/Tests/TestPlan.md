# TestPlan — PluginAudioDBData

## 包概述

音乐数据库数据层：聚合曲目、专辑、艺术家与播放统计的读取能力。

公开类型:
- `AudioDBDataPlugin`
- `AudioModelError`
- `AudioPluginError`
- `AudioRecordDBError`
- `AudioRepoError`
- `AudioModel`
- `AudioConfigRepo`
- `AudioRepo`

### README 中的测试说明（摘自 `README.md`）

- **Test files**:
  - `Tests/AudioDBPluginTests.swift` — repository/database behavior.
  - `Tests/AudioFileSystemMonitorTests.swift` — synchronization lifecycle.
  - `Tests/AudioLibraryProviderTests.swift` — provider contract and lifecycle.
  - `Tests/AudioModelBehaviorTests.swift` — model derivation.
  - `Tests/AudioPluginErrorTests.swift` — user-facing error descriptions.
  - `Tests/AudioTrackNavigationProviderTests.swift` — navigation provider forwarding.
- **Key scenarios tested**:
  - Repository/DB: supported player extensions; dangling symlink replacement on disk creation; DB-update notification on the main thread; unique file dedup by resolved identity (keeping distinct dangling symlinks); next/previous ordered navigation with wrap-around at boundaries; skipping symlinked duplicate tracks; delete-by-URL removing files/models and rejecting out-of-library paths, the library root, and mixed batches; stable path-ordered sync; ignoring folders/unsupported files; clamping pagination bounds and random counts; batch download plan stopping at queue end.
  - Filesystem monitor: plugin is always-on; local file changes trigger a full sync; empty full-sync rules; stale monitor runs/events stop after restart; scan errors do not sync empty results; cancellation of a stale run does not stop the replacement.
  - Library provider: unavailable storage returns empty results and rejects required operations; synced library supports queries/navigation/sorting/deletion; storage-availability changes invalidate the repository; plugin lifecycle indexes existing audio; navigation provider reports unavailable when storage was not injected.
  - Model: uses provided metadata and folder flag; derives title/size from file when metadata is missing; falls back to filename for blank titles; fetch descriptors preserve ordering and folder filters.
  - Errors: each error type surfaces user-facing recovery details.
  - Navigation provider: forwards arguments and returns resolved URLs, propagating resolver errors unchanged.
- **Running tests**:
  ```bash
  cd /Users/angel/Code/Coffic/Cisum/Packages/PluginAudioDBData
  swift test
  ```

## 测试用例清单

下表由 `Tests/` 下的真实 `@Test` 声明自动生成，方法名与代码一一对应。

| ID | 类别 | 描述 | 优先级 | 状态 | 测试文件 | 测试方法 |
|----|------|------|--------|------|----------|----------|
| 1 | 插件 | Audio plugin info exports metadata | P0 | ✅ 已覆盖 | `AudioDBPluginTests.swift` | `audioPluginInfoExportsMetadata` |
| 2 | 插件 | Audio plugin supports player recognized audio extensions | P0 | ✅ 已覆盖 | `AudioDBPluginTests.swift` | `audioPluginSupportsPlayerRecognizedAudioExtensions` |
| 3 | 行为 | Audio disk creation replaces dangling symlink | P1 | ✅ 已覆盖 | `AudioDBPluginTests.swift` | `audioDiskCreationReplacesDanglingSymlink` |
| 4 | 行为 | Audio d b unique supported files deduplicates by resolved identity | P1 | ✅ 已覆盖 | `AudioDBPluginTests.swift` | `audioDBUniqueSupportedFilesDeduplicatesByResolvedIdentity` |
| 5 | 行为 | Audio d b unique supported files keeps distinct dangling symlink audio | P1 | ✅ 已覆盖 | `AudioDBPluginTests.swift` | `audioDBUniqueSupportedFilesKeepsDistinctDanglingSymlinkAudio` |
| 6 | 行为 | Audio d b next of returns following ordered track | P0 | ✅ 已覆盖 | `AudioDBPluginTests.swift` | `audioDBNextOfReturnsFollowingOrderedTrack` |
| 7 | 行为 | Audio d b next of returns nil at last track | P1 | ✅ 已覆盖 | `AudioDBPluginTests.swift` | `audioDBNextOfReturnsNilAtLastTrack` |
| 8 | 行为 | Audio repo navigation wraps at audio d b boundaries | P0 | ✅ 已覆盖 | `AudioDBPluginTests.swift` | `audioRepoNavigationWrapsAtAudioDBBoundaries` |
| 9 | 行为 | Audio d b next of skips symlinked duplicate track | P1 | ✅ 已覆盖 | `AudioDBPluginTests.swift` | `audioDBNextOfSkipsSymlinkedDuplicateTrack` |
| 10 | 行为 | Audio d b prev of skips symlinked duplicate track | P1 | ✅ 已覆盖 | `AudioDBPluginTests.swift` | `audioDBPrevOfSkipsSymlinkedDuplicateTrack` |
| 11 | 行为 | Audio d b delete returns following track after symlinked duplicate | P1 | ✅ 已覆盖 | `AudioDBPluginTests.swift` | `audioDBDeleteReturnsFollowingTrackAfterSymlinkedDuplicate` |
| 12 | 行为 | Audio d b batch delete skips tracks deleted later in same batch | P0 | ✅ 已覆盖 | `AudioDBPluginTests.swift` | `audioDBBatchDeleteSkipsTracksDeletedLaterInSameBatch` |
| 13 | 行为 | Audio d b last audio returns highest ordered track | P0 | ✅ 已覆盖 | `AudioDBPluginTests.swift` | `audioDBLastAudioReturnsHighestOrderedTrack` |
| 14 | 模型 | Audio d b delete audios by u r l removes files and models | P0 | ✅ 已覆盖 | `AudioDBPluginTests.swift` | `audioDBDeleteAudiosByURLRemovesFilesAndModels` |
| 15 | 行为 | Audio d b contains handles root and sibling prefix paths | P0 | ✅ 已覆盖 | `AudioDBPluginTests.swift` | `audioDBContainsHandlesRootAndSiblingPrefixPaths` |
| 16 | 行为 | Audio d b contains resolves symlinked library roots | P0 | ✅ 已覆盖 | `AudioDBPluginTests.swift` | `audioDBContainsResolvesSymlinkedLibraryRoots` |
| 17 | 行为 | Audio d b contains allows dangling symlink entries inside library | P1 | ✅ 已覆盖 | `AudioDBPluginTests.swift` | `audioDBContainsAllowsDanglingSymlinkEntriesInsideLibrary` |
| 18 | 行为 | Audio d b delete audios by u r l removes dangling symlink entries | P1 | ✅ 已覆盖 | `AudioDBPluginTests.swift` | `audioDBDeleteAudiosByURLRemovesDanglingSymlinkEntries` |
| 19 | 行为 | Audio d b delete audios by u r l rejects files outside library | P0 | ✅ 已覆盖 | `AudioDBPluginTests.swift` | `audioDBDeleteAudiosByURLRejectsFilesOutsideLibrary` |
| 20 | 行为 | Audio repo single delete rejects files outside library | P0 | ✅ 已覆盖 | `AudioDBPluginTests.swift` | `audioRepoSingleDeleteRejectsFilesOutsideLibrary` |
| 21 | 行为 | Audio d b delete audios by u r l rejects library root | P0 | ✅ 已覆盖 | `AudioDBPluginTests.swift` | `audioDBDeleteAudiosByURLRejectsLibraryRoot` |
| 22 | 行为 | Audio d b delete audios by u r l rejects mixed batch before deleting | P0 | ✅ 已覆盖 | `AudioDBPluginTests.swift` | `audioDBDeleteAudiosByURLRejectsMixedBatchBeforeDeleting` |
| 23 | 行为 | Audio d b sync appends new files in stable path order | P0 | ✅ 已覆盖 | `AudioDBPluginTests.swift` | `audioDBSyncAppendsNewFilesInStablePathOrder` |
| 24 | 行为 | Audio d b sync matches existing track through symlink | P0 | ✅ 已覆盖 | `AudioDBPluginTests.swift` | `audioDBSyncMatchesExistingTrackThroughSymlink` |
| 25 | 行为 | Audio d b sync removes distinct dangling symlink audio entries | P1 | ✅ 已覆盖 | `AudioDBPluginTests.swift` | `audioDBSyncRemovesDistinctDanglingSymlinkAudioEntries` |
| 26 | 行为 | Audio d b full sync keeps symlinked existing track | P0 | ✅ 已覆盖 | `AudioDBPluginTests.swift` | `audioDBFullSyncKeepsSymlinkedExistingTrack` |
| 27 | 行为 | Audio d b full sync deduplicates symlinked scan items | P1 | ✅ 已覆盖 | `AudioDBPluginTests.swift` | `audioDBFullSyncDeduplicatesSymlinkedScanItems` |
| 28 | 存储 | Audio d b delete by u r l matches symlinked stored track | P0 | ✅ 已覆盖 | `AudioDBPluginTests.swift` | `audioDBDeleteByURLMatchesSymlinkedStoredTrack` |
| 29 | 行为 | Audio d b sync ignores folders and unsupported files | P0 | ✅ 已覆盖 | `AudioDBPluginTests.swift` | `audioDBSyncIgnoresFoldersAndUnsupportedFiles` |
| 30 | 行为 | Audio d b full sync repairs duplicate legacy audio orders | P1 | ✅ 已覆盖 | `AudioDBPluginTests.swift` | `audioDBFullSyncRepairsDuplicateLegacyAudioOrders` |
| 31 | 行为 | Audio d b keeps unique existing audio orders | P0 | ✅ 已覆盖 | `AudioDBPluginTests.swift` | `audioDBKeepsUniqueExistingAudioOrders` |
| 32 | 行为 | Audio d b clamps invalid pagination bounds | P1 | ✅ 已覆盖 | `AudioDBPluginTests.swift` | `audioDBClampsInvalidPaginationBounds` |
| 33 | 行为 | Audio d b clamps invalid random audio count | P1 | ✅ 已覆盖 | `AudioDBPluginTests.swift` | `audioDBClampsInvalidRandomAudioCount` |
| 34 | 行为 | Audio d b next batch download plan stops at end of queue | P0 | ✅ 已覆盖 | `AudioDBPluginTests.swift` | `audioDBNextBatchDownloadPlanStopsAtEndOfQueue` |
| 35 | 模型 | Audio model uses provided title when available | P0 | ✅ 已覆盖 | `AudioDBPluginTests.swift` | `audioModelUsesProvidedTitleWhenAvailable` |
| 36 | 插件 | Audio database plugin is always on for library synchronization | P0 | ✅ 已覆盖 | `AudioFileSystemMonitorTests.swift` | `audioDatabasePluginIsAlwaysOnForLibrarySynchronization` |
| 37 | 行为 | Local file changes use full sync | P0 | ✅ 已覆盖 | `AudioFileSystemMonitorTests.swift` | `localFileChangesUseFullSync` |
| 38 | 行为 | Empty full sync is only allowed for a readable empty directory | P1 | ✅ 已覆盖 | `AudioFileSystemMonitorTests.swift` | `emptyFullSyncIsOnlyAllowedForAReadableEmptyDirectory` |
| 39 | 行为 | Empty full sync is rejected without resolved directory | P1 | ✅ 已覆盖 | `AudioFileSystemMonitorTests.swift` | `emptyFullSyncIsRejectedWithoutResolvedDirectory` |
| 40 | 行为 | Stale monitor run stops after restart | P1 | ✅ 已覆盖 | `AudioFileSystemMonitorTests.swift` | `staleMonitorRunStopsAfterRestart` |
| 41 | 行为 | Stale monitor events are ignored after restart | P1 | ✅ 已覆盖 | `AudioFileSystemMonitorTests.swift` | `staleMonitorEventsAreIgnoredAfterRestart` |
| 42 | 行为 | Monitor scan errors do not sync empty results | P1 | ✅ 已覆盖 | `AudioFileSystemMonitorTests.swift` | `monitorScanErrorsDoNotSyncEmptyResults` |
| 43 | 行为 | Stale monitor cancellation does not stop replacement run | P1 | ✅ 已覆盖 | `AudioFileSystemMonitorTests.swift` | `staleMonitorCancellationDoesNotStopReplacementRun` |
| 44 | 行为 | Unavailable storage returns empty results and rejects required operations | P1 | ✅ 已覆盖 | `AudioLibraryProviderTests.swift` | `unavailableStorageReturnsEmptyResultsAndRejectsRequiredOperations` |
| 45 | 排序 | Synced library supports queries navigation sorting and deletion | P0 | ✅ 已覆盖 | `AudioLibraryProviderTests.swift` | `syncedLibrarySupportsQueriesNavigationSortingAndDeletion` |
| 46 | 行为 | Emits repository empty after confirmed empty sync and when last track is deleted | P1 | ✅ 已覆盖 | `AudioLibraryProviderTests.swift` | `emitsRepositoryEmptyAfterConfirmedEmptySyncAndWhenLastTrackIsDeleted` |
| 47 | 观察者 | Storage availability changes invalidate repository and shutdown cancels observer | P1 | ✅ 已覆盖 | `AudioLibraryProviderTests.swift` | `storageAvailabilityChangesInvalidateRepositoryAndShutdownCancelsObserver` |
| 48 | 插件 | Plugin lifecycle indexes existing audio and registers navigation | P0 | ✅ 已覆盖 | `AudioLibraryProviderTests.swift` | `pluginLifecycleIndexesExistingAudioAndRegistersNavigation` |
| 49 | 行为 | Navigation provider is installed after storage arrives between boot and ready | P0 | ✅ 已覆盖 | `AudioLibraryProviderTests.swift` | `navigationProviderIsInstalledAfterStorageArrivesBetweenBootAndReady` |
| 50 | 行为 | Navigation provider is not installed when storage was never injected | P0 | ✅ 已覆盖 | `AudioLibraryProviderTests.swift` | `navigationProviderIsNotInstalledWhenStorageWasNeverInjected` |
| 51 | 元数据 | Audio model uses provided metadata and folder flag | P0 | ✅ 已覆盖 | `AudioModelBehaviorTests.swift` | `audioModelUsesProvidedMetadataAndFolderFlag` |
| 52 | 元数据 | Audio model derives title and size from file when metadata is missing | P1 | ✅ 已覆盖 | `AudioModelBehaviorTests.swift` | `audioModelDerivesTitleAndSizeFromFileWhenMetadataIsMissing` |
| 53 | 模型 | Audio model falls back to filename for blank titles | P0 | ✅ 已覆盖 | `AudioModelBehaviorTests.swift` | `audioModelFallsBackToFilenameForBlankTitles` |
| 54 | 模型 | Audio model fetch descriptors preserve ordering and folder filters | P0 | ✅ 已覆盖 | `AudioModelBehaviorTests.swift` | `audioModelFetchDescriptorsPreserveOrderingAndFolderFilters` |
| 55 | 插件 | Audio plugin errors provide user facing recovery details | P1 | ✅ 已覆盖 | `AudioPluginErrorTests.swift` | `audioPluginErrorsProvideUserFacingRecoveryDetails` |
| 56 | 行为 | Audio record database errors describe underlying failures | P1 | ✅ 已覆盖 | `AudioPluginErrorTests.swift` | `audioRecordDatabaseErrorsDescribeUnderlyingFailures` |
| 57 | 模型 | Audio model errors provide specific recovery details | P1 | ✅ 已覆盖 | `AudioPluginErrorTests.swift` | `audioModelErrorsProvideSpecificRecoveryDetails` |
| 58 | 行为 | Audio repository errors provide operational recovery details | P1 | ✅ 已覆盖 | `AudioPluginErrorTests.swift` | `audioRepositoryErrorsProvideOperationalRecoveryDetails` |
| 59 | 行为 | Forwards arguments and returns resolved u r ls | P0 | ✅ 已覆盖 | `AudioTrackNavigationProviderTests.swift` | `forwardsArgumentsAndReturnsResolvedURLs` |
| 60 | 行为 | Propagates resolver errors without changing them | P1 | ✅ 已覆盖 | `AudioTrackNavigationProviderTests.swift` | `propagatesResolverErrorsWithoutChangingThem` |
| 61 | 行为 | Produces valid r i f f header | P0 | ✅ 已覆盖 | `UITestAudioSeedToneTests.swift` | `producesValidRIFFHeader` |
| 62 | 行为 | Chunk sizes match payload | P0 | ✅ 已覆盖 | `UITestAudioSeedToneTests.swift` | `chunkSizesMatchPayload` |
| 63 | 行为 | Duration scales payload | P0 | ✅ 已覆盖 | `UITestAudioSeedToneTests.swift` | `durationScalesPayload` |
| 64 | 行为 | Invalid duration falls back to default | P1 | ✅ 已覆盖 | `UITestAudioSeedToneTests.swift` | `invalidDurationFallsBackToDefault` |
| 65 | 行为 | Decodes with a v audio file | P0 | ✅ 已覆盖 | `UITestAudioSeedToneTests.swift` | `decodesWithAVAudioFile` |

## 覆盖率统计

- P0: 35 / 35 ✅
- P1: 30 / 30 ✅
- P2: 0 / 0

**总计: 65 / 65**（本包 `Tests/` 中已声明的 `@Test` 全部登记）

## 测试文件

- `AudioDBPluginTests.swift` — 35 条用例
- `AudioFileSystemMonitorTests.swift` — 8 条用例
- `AudioLibraryProviderTests.swift` — 7 条用例
- `AudioModelBehaviorTests.swift` — 4 条用例
- `AudioPluginErrorTests.swift` — 4 条用例
- `AudioTrackNavigationProviderTests.swift` — 2 条用例
- `UITestAudioSeedToneTests.swift` — 5 条用例

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
cd Packages/PluginAudioDBData
swift test
```

## 维护规则

1. **新增公开 API** → 先在 TestPlan 登记测试用例,再写实现
2. **Bug 修复** → 追加回归用例,标注触发条件
3. **删除用例** → 在 commit message 说明理由
4. **状态同步** → 实现后更新 TestPlan,标记 ✅ 并填写测试方法名
