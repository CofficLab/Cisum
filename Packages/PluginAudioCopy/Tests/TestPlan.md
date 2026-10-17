# TestPlan — PluginAudioCopy

## 包概述

macOS 音乐文件操作：复制路径、复制文件等 Finder 相关动作。

公开类型:
- `CopyPlugin`
- `AudioCopyService`
- `AudioCopyPluginInfo`

### README 中的测试说明（摘自 `README.md`）

- **Test files**: `Tests/AudioCopyPluginTests.swift`.
- **Key scenarios tested**:
  - Metadata: `AudioCopyPluginInfo.iconName`; task-count notification posts synchronously on the main thread.
  - Drag-and-drop: accepts only supported audio files (rejects folders/unsupported types); deduplicates symlinked sources but keeps distinct dangling symlinks; reads `FileURLDataProvider` with URL-object fallbacks (including after invalid/error `FileURLData`).
  - `CopyWorker`: plans unique destination names; avoids dangling-symlink destination names; copies the resolved symlink target; grants access to readable local sources without a security-scoped bookmark.
  - Presentation & list logic: `CopyStatePresentation` messages for pending/failed counts and details button labels; `CopyList.tasksToDelete` mapping index sets; `AudioCopyLimitPolicy` allowed task counts.
  - Guards: no-files alert after preparation failure, partial drop load failure reporting, infrastructure preparation only when sources exist, finished notification only when the queue empties, skip tasks deleted before start, discard completed copies for deleted tasks.
- **Running tests**:
  ```bash
  cd /Users/angel/Code/Coffic/Cisum/Packages/PluginAudioCopy
  swift test
  ```

## 测试用例清单

下表由 `Tests/` 下的真实 `@Test` 声明自动生成，方法名与代码一一对应。

| ID | 类别 | 描述 | 优先级 | 状态 | 测试文件 | 测试方法 |
|----|------|------|--------|------|----------|----------|
| 1 | 元数据 | Audio copy info exports metadata | P0 | ✅ 已覆盖 | `AudioCopyPluginTests.swift` | `audioCopyInfoExportsMetadata` |
| 2 | 行为 | Copy task count notification posts synchronously on main thread | P0 | ✅ 已覆盖 | `AudioCopyPluginTests.swift` | `copyTaskCountNotificationPostsSynchronouslyOnMainThread` |
| 3 | 行为 | Copy drop accepts only supported audio files | P0 | ✅ 已覆盖 | `AudioCopyPluginTests.swift` | `copyDropAcceptsOnlySupportedAudioFiles` |
| 4 | 行为 | Copy drop deduplicates symlinked audio sources | P1 | ✅ 已覆盖 | `AudioCopyPluginTests.swift` | `copyDropDeduplicatesSymlinkedAudioSources` |
| 5 | 行为 | Copy drop keeps distinct dangling symlink audio sources | P1 | ✅ 已覆盖 | `AudioCopyPluginTests.swift` | `copyDropKeepsDistinctDanglingSymlinkAudioSources` |
| 6 | 行为 | Copy drop reads file u r l data provider | P0 | ✅ 已覆盖 | `AudioCopyPluginTests.swift` | `copyDropReadsFileURLDataProvider` |
| 7 | 行为 | Copy drop reads u r l object provider fallback | P1 | ✅ 已覆盖 | `AudioCopyPluginTests.swift` | `copyDropReadsURLObjectProviderFallback` |
| 8 | 行为 | Copy drop falls back to u r l object after invalid file u r l data | P1 | ✅ 已覆盖 | `AudioCopyPluginTests.swift` | `copyDropFallsBackToURLObjectAfterInvalidFileURLData` |
| 9 | 行为 | Copy drop falls back to u r l object after file u r l data error | P1 | ✅ 已覆盖 | `AudioCopyPluginTests.swift` | `copyDropFallsBackToURLObjectAfterFileURLDataError` |
| 10 | 行为 | Copy worker plans unique destination names | P0 | ✅ 已覆盖 | `AudioCopyPluginTests.swift` | `copyWorkerPlansUniqueDestinationNames` |
| 11 | 行为 | Copy worker avoids dangling symlink destination names | P1 | ✅ 已覆盖 | `AudioCopyPluginTests.swift` | `copyWorkerAvoidsDanglingSymlinkDestinationNames` |
| 12 | 行为 | Copy worker copies resolved symlink target | P0 | ✅ 已覆盖 | `AudioCopyPluginTests.swift` | `copyWorkerCopiesResolvedSymlinkTarget` |
| 13 | 行为 | Copy worker accepts readable local sources without security scope | P1 | ✅ 已覆盖 | `AudioCopyPluginTests.swift` | `copyWorkerAcceptsReadableLocalSourcesWithoutSecurityScope` |
| 14 | 状态 | Copy state message distinguishes pending and failed tasks | P1 | ✅ 已覆盖 | `AudioCopyPluginTests.swift` | `copyStateMessageDistinguishesPendingAndFailedTasks` |
| 15 | 状态 | Copy state details button label tracks popover state | P0 | ✅ 已覆盖 | `AudioCopyPluginTests.swift` | `copyStateDetailsButtonLabelTracksPopoverState` |
| 16 | 行为 | Copy limit counts current library and incoming drop | P0 | ✅ 已覆盖 | `AudioCopyPluginTests.swift` | `copyLimitCountsCurrentLibraryAndIncomingDrop` |
| 17 | 行为 | Copy drop skips no files alert after preparation failure | P1 | ✅ 已覆盖 | `AudioCopyPluginTests.swift` | `copyDropSkipsNoFilesAlertAfterPreparationFailure` |
| 18 | 服务 | Copy drop only checks copy services after finding sources | P0 | ✅ 已覆盖 | `AudioCopyPluginTests.swift` | `copyDropOnlyChecksCopyServicesAfterFindingSources` |
| 19 | 行为 | Copy worker only posts finished when queue is still empty | P1 | ✅ 已覆盖 | `AudioCopyPluginTests.swift` | `copyWorkerOnlyPostsFinishedWhenQueueIsStillEmpty` |
| 20 | 行为 | Copy worker skips tasks deleted before they start | P0 | ✅ 已覆盖 | `AudioCopyPluginTests.swift` | `copyWorkerSkipsTasksDeletedBeforeTheyStart` |
| 21 | 行为 | Copy worker discards completed copy when task was deleted | P0 | ✅ 已覆盖 | `AudioCopyPluginTests.swift` | `copyWorkerDiscardsCompletedCopyWhenTaskWasDeleted` |
| 22 | 行为 | Copy d b sees tasks deleted from separate context | P0 | ✅ 已覆盖 | `AudioCopyPluginTests.swift` | `copyDBSeesTasksDeletedFromSeparateContext` |
| 23 | 行为 | Copy d b new task deduplicates by bookmark | P1 | ✅ 已覆盖 | `AudioCopyPluginTests.swift` | `copyDBNewTaskDeduplicatesByBookmark` |
| 24 | 行为 | Copy d b find and has task match by bookmark | P0 | ✅ 已覆盖 | `AudioCopyPluginTests.swift` | `copyDBFindAndHasTaskMatchByBookmark` |
| 25 | 持久化 | Copy d b set running and error states persist | P1 | ✅ 已覆盖 | `AudioCopyPluginTests.swift` | `copyDBSetRunningAndErrorStatesPersist` |
| 26 | 行为 | Copy d b delete by bookmarks and by id | P0 | ✅ 已覆盖 | `AudioCopyPluginTests.swift` | `copyDBDeleteByBookmarksAndById` |
| 27 | 持久化 | Copy d b d t os expose persisted state | P0 | ✅ 已覆盖 | `AudioCopyPluginTests.swift` | `copyDBDTOsExposePersistedState` |
| 28 | 行为 | Copy worker source access honors scope and readability | P0 | ✅ 已覆盖 | `AudioCopyPluginTests.swift` | `copyWorkerSourceAccessHonorsScopeAndReadability` |
| 29 | 行为 | Copy worker reserves unique names across same folder tasks | P0 | ✅ 已覆盖 | `AudioCopyPluginTests.swift` | `copyWorkerReservesUniqueNamesAcrossSameFolderTasks` |

## 覆盖率统计

- P0: 17 / 17 ✅
- P1: 12 / 12 ✅
- P2: 0 / 0

**总计: 29 / 29**（本包 `Tests/` 中已声明的 `@Test` 全部登记）

## 测试文件

- `AudioCopyPluginTests.swift` — 29 条用例

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
cd Packages/PluginAudioCopy
swift test
```

## 维护规则

1. **新增公开 API** → 先在 TestPlan 登记测试用例,再写实现
2. **Bug 修复** → 追加回归用例,标注触发条件
3. **删除用例** → 在 commit message 说明理由
4. **状态同步** → 实现后更新 TestPlan,标记 ✅ 并填写测试方法名
