# TestPlan — PluginStorage

## 包概述

存储插件：存储位置选择、迁移、导入导出与扫描。

公开类型:
- `StorageProvider`
- `StoragePlugin`
- `StoragePluginInfo`
- `StorageSettingView`

### README 中的测试说明（摘自 `README.md`）

- **Test files:**
  - `Tests/StoragePluginTests.swift` — a large suite (~30 tests) covering storage info, file listing, file size/status, migration, and settings behavior.
- **Key scenarios tested:**
  - Plugin info metadata; `FileItem` directory-read failures.
  - File list generation only applies the latest visible-items update (generation guard), refreshes the cache on re-expansion, and tracks repository URL changes.
  - Expand-button accessibility label; file-info cells only apply results for the current file (including symlinked files, and correctly rejecting results across distinct dangling symlinks).
  - File-size policy reads Foundation number attributes, clamps negatives, streams directory sizes, and reads single-file sizes.
  - File status reports missing local files, clamps download percent text, and ignores local directories/hidden files during scans.
  - Repository info only opens existing local paths; storage settings clear the displayed selection after reset and sync the target after external location changes.
  - Migration progress only applies the current generation, normalizes invalid values, preserves download state on failure, completes only after source files leave, ignores unknown files, and disables interactive dismissal only while running.
- **Running tests:**
  ```bash
  cd /Users/angel/Code/Coffic/Cisum/Packages/PluginStorage
  swift test
  ```
- Tests are extensive and focus on the pure, deterministic policies (generation guards, size parsing, symlink handling, migration messaging) rather than on actually copying files.

## 测试用例清单

下表由 `Tests/` 下的真实 `@Test` 声明自动生成，方法名与代码一一对应。

| ID | 类别 | 描述 | 优先级 | 状态 | 测试文件 | 测试方法 |
|----|------|------|--------|------|----------|----------|
| 1 | 行为 | Onboarding gate opens only after storage choice is committed | P0 | ✅ 已覆盖 | `OnboardingStorageGateTests.swift` | `onboardingGateOpensOnlyAfterStorageChoiceIsCommitted` |
| 2 | 行为 | Committing unavailable i cloud keeps onboarding gate closed | P1 | ✅ 已覆盖 | `OnboardingStorageGateTests.swift` | `committingUnavailableICloudKeepsOnboardingGateClosed` |
| 3 | 插件 | Storage plugin info is exposed | P0 | ✅ 已覆盖 | `StoragePluginTests.swift` | `storagePluginInfoIsExposed` |
| 4 | 持久化 | Storage provider persists location to injected preferences only | P0 | ✅ 已覆盖 | `StoragePluginTests.swift` | `storageProviderPersistsLocationToInjectedPreferencesOnly` |
| 5 | 行为 | Storage provider exposes lumi contract over the same root | P0 | ✅ 已覆盖 | `StoragePluginTests.swift` | `storageProviderExposesLumiContractOverTheSameRoot` |
| 6 | 插件 | Storage plugin registers one instance under both contracts | P0 | ✅ 已覆盖 | `StoragePluginTests.swift` | `storagePluginRegistersOneInstanceUnderBothContracts` |
| 7 | 行为 | File item reports directory read failures | P1 | ✅ 已覆盖 | `StoragePluginTests.swift` | `fileItemReportsDirectoryReadFailures` |
| 8 | 行为 | File list only applies latest visible items update | P0 | ✅ 已覆盖 | `StoragePluginTests.swift` | `fileListOnlyAppliesLatestVisibleItemsUpdate` |
| 9 | 缓存 | File list refreshes directory cache when expanded again | P0 | ✅ 已覆盖 | `StoragePluginTests.swift` | `fileListRefreshesDirectoryCacheWhenExpandedAgain` |
| 10 | 状态 | File list root state tracks changed repository u r l | P0 | ✅ 已覆盖 | `StoragePluginTests.swift` | `fileListRootStateTracksChangedRepositoryURL` |
| 11 | 状态 | File expand button accessibility label matches state | P0 | ✅ 已覆盖 | `StoragePluginTests.swift` | `fileExpandButtonAccessibilityLabelMatchesState` |
| 12 | 行为 | File info cells only apply current u r l results | P0 | ✅ 已覆盖 | `StoragePluginTests.swift` | `fileInfoCellsOnlyApplyCurrentURLResults` |
| 13 | 行为 | File info cells apply symlinked current u r l results | P0 | ✅ 已覆盖 | `StoragePluginTests.swift` | `fileInfoCellsApplySymlinkedCurrentURLResults` |
| 14 | 行为 | File info cells do not apply results across distinct dangling symlinks | P1 | ✅ 已覆盖 | `StoragePluginTests.swift` | `fileInfoCellsDoNotApplyResultsAcrossDistinctDanglingSymlinks` |
| 15 | 策略 | File size read policy reads foundation number attributes | P0 | ✅ 已覆盖 | `StoragePluginTests.swift` | `fileSizeReadPolicyReadsFoundationNumberAttributes` |
| 16 | 策略 | File size read policy normalizes negative attributes | P0 | ✅ 已覆盖 | `StoragePluginTests.swift` | `fileSizeReadPolicyNormalizesNegativeAttributes` |
| 17 | 行为 | File size calculation streams directory files | P0 | ✅ 已覆盖 | `StoragePluginTests.swift` | `fileSizeCalculationStreamsDirectoryFiles` |
| 18 | 行为 | File size calculation reads single file size | P0 | ✅ 已覆盖 | `StoragePluginTests.swift` | `fileSizeCalculationReadsSingleFileSize` |
| 19 | 行为 | File status reports missing local files | P1 | ✅ 已覆盖 | `StoragePluginTests.swift` | `fileStatusReportsMissingLocalFiles` |
| 20 | 行为 | File status download percent text is clamped | P1 | ✅ 已覆盖 | `StoragePluginTests.swift` | `fileStatusDownloadPercentTextIsClamped` |
| 21 | 行为 | File status directory scan ignores local directories and hidden files | P0 | ✅ 已覆盖 | `StoragePluginTests.swift` | `fileStatusDirectoryScanIgnoresLocalDirectoriesAndHiddenFiles` |
| 22 | 行为 | Repository info only opens existing local paths | P0 | ✅ 已覆盖 | `StoragePluginTests.swift` | `repositoryInfoOnlyOpensExistingLocalPaths` |
| 23 | 行为 | Direct storage switch uses accurate completion message | P0 | ✅ 已覆盖 | `StoragePluginTests.swift` | `directStorageSwitchUsesAccurateCompletionMessage` |
| 24 | 迁移 | Migration warning text uses english resource keys | P0 | ✅ 已覆盖 | `StoragePluginTests.swift` | `migrationWarningTextUsesEnglishResourceKeys` |
| 25 | 迁移 | Migration error alert uses english recovery guidance | P1 | ✅ 已覆盖 | `StoragePluginTests.swift` | `migrationErrorAlertUsesEnglishRecoveryGuidance` |
| 26 | 迁移 | Migration error alert includes cancellation recovery note | P1 | ✅ 已覆盖 | `StoragePluginTests.swift` | `migrationErrorAlertIncludesCancellationRecoveryNote` |
| 27 | 迁移 | Migration error alert falls back for blank errors | P1 | ✅ 已覆盖 | `StoragePluginTests.swift` | `migrationErrorAlertFallsBackForBlankErrors` |
| 28 | 行为 | Storage settings clears displayed selection after reset | P1 | ✅ 已覆盖 | `StoragePluginTests.swift` | `storageSettingsClearsDisplayedSelectionAfterReset` |
| 29 | 行为 | Storage settings syncs target after external location change | P0 | ✅ 已覆盖 | `StoragePluginTests.swift` | `storageSettingsSyncsTargetAfterExternalLocationChange` |
| 30 | 迁移 | Migration progress only applies current generation updates | P0 | ✅ 已覆盖 | `StoragePluginTests.swift` | `migrationProgressOnlyAppliesCurrentGenerationUpdates` |
| 31 | 归一化 | Migration progress normalizes invalid values | P1 | ✅ 已覆盖 | `StoragePluginTests.swift` | `migrationProgressNormalizesInvalidValues` |
| 32 | 状态 | Migration status update preserves download state on failure | P1 | ✅ 已覆盖 | `StoragePluginTests.swift` | `migrationStatusUpdatePreservesDownloadStateOnFailure` |
| 33 | 迁移 | Migration status update completes only after source file leaves | P0 | ✅ 已覆盖 | `StoragePluginTests.swift` | `migrationStatusUpdateCompletesOnlyAfterSourceFileLeaves` |
| 34 | 迁移 | Migration status update ignores unknown files | P0 | ✅ 已覆盖 | `StoragePluginTests.swift` | `migrationStatusUpdateIgnoresUnknownFiles` |
| 35 | 迁移 | Migration sheet only disables dismiss while running | P0 | ✅ 已覆盖 | `StoragePluginTests.swift` | `migrationSheetOnlyDisablesDismissWhileRunning` |
| 36 | 迁移 | Missing source storage does not attempt migration | P1 | ✅ 已覆盖 | `StoragePluginTests.swift` | `missingSourceStorageDoesNotAttemptMigration` |
| 37 | 迁移 | Migration action requires existing source storage | P0 | ✅ 已覆盖 | `StoragePluginTests.swift` | `migrationActionRequiresExistingSourceStorage` |
| 38 | 迁移 | Migration uses displayed source and target roots | P0 | ✅ 已覆盖 | `StoragePluginTests.swift` | `migrationUsesDisplayedSourceAndTargetRoots` |
| 39 | 迁移 | Migration root resolution reports missing displayed roots | P1 | ✅ 已覆盖 | `StoragePluginTests.swift` | `migrationRootResolutionReportsMissingDisplayedRoots` |
| 40 | 迁移 | Migration preview skips d s store like migration manager | P2 | ✅ 已覆盖 | `StoragePluginTests.swift` | `migrationPreviewSkipsDSStoreLikeMigrationManager` |
| 41 | 迁移 | Migration moves contents but keeps source root | P0 | ✅ 已覆盖 | `StoragePluginTests.swift` | `migrationMovesContentsButKeepsSourceRoot` |
| 42 | 迁移 | Migration rejects target inside source root before moving files | P0 | ✅ 已覆盖 | `StoragePluginTests.swift` | `migrationRejectsTargetInsideSourceRootBeforeMovingFiles` |
| 43 | 迁移 | Migration treats root source as containing target | P0 | ✅ 已覆盖 | `StoragePluginTests.swift` | `migrationTreatsRootSourceAsContainingTarget` |
| 44 | 迁移 | Migration treats symlinked target root as same source | P0 | ✅ 已覆盖 | `StoragePluginTests.swift` | `migrationTreatsSymlinkedTargetRootAsSameSource` |
| 45 | 迁移 | Migration rejects target inside source through symlink | P0 | ✅ 已覆盖 | `StoragePluginTests.swift` | `migrationRejectsTargetInsideSourceThroughSymlink` |
| 46 | 迁移 | Migration reports local availability before moving files | P0 | ✅ 已覆盖 | `StoragePluginTests.swift` | `migrationReportsLocalAvailabilityBeforeMovingFiles` |
| 47 | 迁移 | Migration reports local availability for visible folder descendants | P0 | ✅ 已覆盖 | `StoragePluginTests.swift` | `migrationReportsLocalAvailabilityForVisibleFolderDescendants` |
| 48 | 迁移 | Migration renames conflicting target files | P0 | ✅ 已覆盖 | `StoragePluginTests.swift` | `migrationRenamesConflictingTargetFiles` |
| 49 | 迁移 | Migration renames when target has dangling symlink | P1 | ✅ 已覆盖 | `StoragePluginTests.swift` | `migrationRenamesWhenTargetHasDanglingSymlink` |
| 50 | 迁移 | Migration copies symlinked files as standalone files | P0 | ✅ 已覆盖 | `StoragePluginTests.swift` | `migrationCopiesSymlinkedFilesAsStandaloneFiles` |
| 51 | 迁移 | Migration reports completion only after move finishes | P0 | ✅ 已覆盖 | `StoragePluginTests.swift` | `migrationReportsCompletionOnlyAfterMoveFinishes` |
| 52 | 迁移 | Empty migration reports complete progress | P1 | ✅ 已覆盖 | `StoragePluginTests.swift` | `emptyMigrationReportsCompleteProgress` |
| 53 | 迁移 | Migration cancellation stops before moving files | P1 | ✅ 已覆盖 | `StoragePluginTests.swift` | `migrationCancellationStopsBeforeMovingFiles` |
| 54 | 迁移 | Migration cancellation keeps preexisting empty target directory | P1 | ✅ 已覆盖 | `StoragePluginTests.swift` | `migrationCancellationKeepsPreexistingEmptyTargetDirectory` |
| 55 | 迁移 | Migration cancellation requested from progress stops before moving current file | P1 | ✅ 已覆盖 | `StoragePluginTests.swift` | `migrationCancellationRequestedFromProgressStopsBeforeMovingCurrentFile` |
| 56 | 观察者 | Storage observer performs initial sync | P0 | ✅ 已覆盖 | `StoragePluginTests.swift` | `storageObserverPerformsInitialSync` |
| 57 | 视图模型 | Storage observer forwards location change to view model | P2 | ✅ 已覆盖 | `StoragePluginTests.swift` | `storageObserverForwardsLocationChangeToViewModel` |
| 58 | 视图模型 | Storage observer cancel stops view model updates | P1 | ✅ 已覆盖 | `StoragePluginTests.swift` | `storageObserverCancelStopsViewModelUpdates` |
| 59 | 插件 | Plugin data directory resolves under database root and creates | P0 | ✅ 已覆盖 | `StoragePluginTests.swift` | `pluginDataDirectoryResolvesUnderDatabaseRootAndCreates` |
| 60 | 插件 | Plugin data directory keeps per plugin subdirectories | P0 | ✅ 已覆盖 | `StoragePluginTests.swift` | `pluginDataDirectoryKeepsPerPluginSubdirectories` |
| 61 | 视图模型 | Storage plugin binds preexisting settings view model when provider becomes available | P2 | ✅ 已覆盖 | `StoragePluginTests.swift` | `storagePluginBindsPreexistingSettingsViewModelWhenProviderBecomesAvailable` |

## 覆盖率统计

- P0: 39 / 39 ✅
- P1: 19 / 19 ✅
- P2: 3 / 3 ✅

**总计: 61 / 61**（本包 `Tests/` 中已声明的 `@Test` 全部登记）

## 测试文件

- `OnboardingStorageGateTests.swift` — 2 条用例
- `StoragePluginTests.swift` — 59 条用例

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
cd Packages/PluginStorage
swift test
```

## 维护规则

1. **新增公开 API** → 先在 TestPlan 登记测试用例,再写实现
2. **Bug 修复** → 追加回归用例,标注触发条件
3. **删除用例** → 在 commit message 说明理由
4. **状态同步** → 实现后更新 TestPlan,标记 ✅ 并填写测试方法名
