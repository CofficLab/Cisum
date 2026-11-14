# TestPlan — PluginBookControlButtons

## 包概述

有声书播放控制按钮组，行为与音乐控制按钮对称。

公开类型:
- `BookControlButtonsPlugin`

### README 中的测试说明（摘自 `README.md`）

- **Test files:**
  - `Tests/BookControlPluginTests.swift` — covers metadata, chapter loader,
    navigation policy, book-root resolver, and view-model integration with probes.
- **Key scenarios tested:**
  - Registration metadata: `iconName == "playpause"`, `order == 8`.
  - Chapter navigation: `repeatAll` wraps around both ends, `sequence` stops at
    boundaries, shuffle excludes the current chapter.
  - Symlink handling: navigation matches a symlinked current chapter, shuffle
    candidates collapse real/symlinked duplicates while keeping distinct dangling
    symlink books separate.
  - Request policies: stale navigation results (generation mismatch, scene
    deactivated, asset switched) are rejected; navigation is rejected for audio
    outside the configured book disk; deletion affects the current chapter only
    when it lies inside a deleted book (through symlinks too).
  - Chapter cache: reuse after load, invalidation on delete/refresh, cache-key
    matching across symlinked roots.
  - Book-root resolution: standalone file at disk root, nested chapter maps to its
    top-level folder, outside-disk fallback to parent, symlinked disk mapping.
  - Chapter loader order (relative paths, skips hidden/unsupported files).
  - ViewModel integration via `BookControlPlaybackProbe` / `BookToastProbe`:
    init reflects playback state, unavailable-capability toasts, storage reset
    applies only in the active scene, deletion of the current chapter resets
    playback, and scene changes invalidate pending resets.
- **Running tests:**
  ```bash
  cd /Users/angel/Code/Coffic/Cisum/Packages/PluginBookControlButtons
  swift test
  ```

## 测试用例清单

下表由 `Tests/` 下的真实 `@Test` 声明自动生成，方法名与代码一一对应。

| ID | 类别 | 描述 | 优先级 | 状态 | 测试文件 | 测试方法 |
|----|------|------|--------|------|----------|----------|
| 1 | 插件 | Plugin info exports registration metadata | P0 | ✅ 已覆盖 | `BookControlPluginTests.swift` | `pluginInfoExportsRegistrationMetadata` |
| 2 | 行为 | Repeat all wraps book chapter navigation | P0 | ✅ 已覆盖 | `BookControlPluginTests.swift` | `repeatAllWrapsBookChapterNavigation` |
| 3 | 行为 | Chapter navigation matches symlinked current chapter | P0 | ✅ 已覆盖 | `BookControlPluginTests.swift` | `chapterNavigationMatchesSymlinkedCurrentChapter` |
| 4 | 行为 | Shuffled chapter candidates exclude symlinked current chapter | P0 | ✅ 已覆盖 | `BookControlPluginTests.swift` | `shuffledChapterCandidatesExcludeSymlinkedCurrentChapter` |
| 5 | 行为 | Shuffled chapter candidates keep distinct dangling symlinked chapters | P1 | ✅ 已覆盖 | `BookControlPluginTests.swift` | `shuffledChapterCandidatesKeepDistinctDanglingSymlinkedChapters` |
| 6 | 行为 | Navigation result only applies to unchanged current chapter | P0 | ✅ 已覆盖 | `BookControlPluginTests.swift` | `navigationResultOnlyAppliesToUnchangedCurrentChapter` |
| 7 | 行为 | Navigation result applies to symlinked current chapter | P0 | ✅ 已覆盖 | `BookControlPluginTests.swift` | `navigationResultAppliesToSymlinkedCurrentChapter` |
| 8 | 行为 | Navigation result does not apply to distinct dangling symlinked chapters | P1 | ✅ 已覆盖 | `BookControlPluginTests.swift` | `navigationResultDoesNotApplyToDistinctDanglingSymlinkedChapters` |
| 9 | 行为 | Stale navigation does not apply after scene reactivation | P1 | ✅ 已覆盖 | `BookControlPluginTests.swift` | `staleNavigationDoesNotApplyAfterSceneReactivation` |
| 10 | 行为 | Navigation rejects current audio outside configured book disk | P0 | ✅ 已覆盖 | `BookControlPluginTests.swift` | `navigationRejectsCurrentAudioOutsideConfiguredBookDisk` |
| 11 | 行为 | Deletion affects current chapter inside deleted book | P0 | ✅ 已覆盖 | `BookControlPluginTests.swift` | `deletionAffectsCurrentChapterInsideDeletedBook` |
| 12 | 行为 | Deletion affects current chapter through symlinked book | P0 | ✅ 已覆盖 | `BookControlPluginTests.swift` | `deletionAffectsCurrentChapterThroughSymlinkedBook` |
| 13 | 行为 | Deletion affects current chapter under dangling symlinked book | P1 | ✅ 已覆盖 | `BookControlPluginTests.swift` | `deletionAffectsCurrentChapterUnderDanglingSymlinkedBook` |
| 14 | 行为 | Deletion does not affect distinct dangling symlinked book | P1 | ✅ 已覆盖 | `BookControlPluginTests.swift` | `deletionDoesNotAffectDistinctDanglingSymlinkedBook` |
| 15 | 缓存 | Book deletion invalidates chapter cache even when current chapter survives | P1 | ✅ 已覆盖 | `BookControlPluginTests.swift` | `bookDeletionInvalidatesChapterCacheEvenWhenCurrentChapterSurvives` |
| 16 | 缓存 | Book library refresh invalidates chapter cache for new chapters | P1 | ✅ 已覆盖 | `BookControlPluginTests.swift` | `bookLibraryRefreshInvalidatesChapterCacheForNewChapters` |
| 17 | 行为 | Stale deletion reset does not apply after scene reactivation | P1 | ✅ 已覆盖 | `BookControlPluginTests.swift` | `staleDeletionResetDoesNotApplyAfterSceneReactivation` |
| 18 | 行为 | Storage reset only applies in active book scene | P1 | ✅ 已覆盖 | `BookControlPluginTests.swift` | `storageResetOnlyAppliesInActiveBookScene` |
| 19 | 行为 | Stale book storage reset does not apply after deactivation | P1 | ✅ 已覆盖 | `BookControlPluginTests.swift` | `staleBookStorageResetDoesNotApplyAfterDeactivation` |
| 20 | 行为 | Book root uses standalone book at disk root | P0 | ✅ 已覆盖 | `BookControlPluginTests.swift` | `bookRootUsesStandaloneBookAtDiskRoot` |
| 21 | 行为 | Book root uses top level folder for chapter books | P0 | ✅ 已覆盖 | `BookControlPluginTests.swift` | `bookRootUsesTopLevelFolderForChapterBooks` |
| 22 | 行为 | Book root falls back to parent outside book disk | P0 | ✅ 已覆盖 | `BookControlPluginTests.swift` | `bookRootFallsBackToParentOutsideBookDisk` |
| 23 | 行为 | Book root maps symlinked book disk to configured root | P0 | ✅ 已覆盖 | `BookControlPluginTests.swift` | `bookRootMapsSymlinkedBookDiskToConfiguredRoot` |
| 24 | 行为 | Chapter loader returns playable chapters in relative order | P0 | ✅ 已覆盖 | `BookControlPluginTests.swift` | `chapterLoaderReturnsPlayableChaptersInRelativeOrder` |
| 25 | 缓存 | Chapter cache reuses loaded chapters for navigation | P0 | ✅ 已覆盖 | `BookControlPluginTests.swift` | `chapterCacheReusesLoadedChaptersForNavigation` |
| 26 | 缓存 | Chapter cache matches symlinked book roots | P0 | ✅ 已覆盖 | `BookControlPluginTests.swift` | `chapterCacheMatchesSymlinkedBookRoots` |
| 27 | 行为 | Chapter loader rejects sibling prefix paths | P0 | ✅ 已覆盖 | `BookControlPluginTests.swift` | `chapterLoaderRejectsSiblingPrefixPaths` |
| 28 | 状态 | Init reflects playback state | P0 | ✅ 已覆盖 | `BookControlPluginTests.swift` | `initReflectsPlaybackState` |
| 29 | 能力 | Toggle without capability reports unavailable | P1 | ✅ 已覆盖 | `BookControlPluginTests.swift` | `toggleWithoutCapabilityReportsUnavailable` |
| 30 | 行为 | Previous without current chapter reports unavailable | P1 | ✅ 已覆盖 | `BookControlPluginTests.swift` | `previousWithoutCurrentChapterReportsUnavailable` |
| 31 | 行为 | Storage location reset resets playback in active scene | P1 | ✅ 已覆盖 | `BookControlPluginTests.swift` | `storageLocationResetResetsPlaybackInActiveScene` |
| 32 | 行为 | Storage location reset ignored when scene inactive | P1 | ✅ 已覆盖 | `BookControlPluginTests.swift` | `storageLocationResetIgnoredWhenSceneInactive` |
| 33 | 行为 | Deletion of current chapter resets playback | P1 | ✅ 已覆盖 | `BookControlPluginTests.swift` | `deletionOfCurrentChapterResetsPlayback` |
| 34 | 行为 | Scene change invalidates pending deletion reset | P1 | ✅ 已覆盖 | `BookControlPluginTests.swift` | `sceneChangeInvalidatesPendingDeletionReset` |

## 覆盖率统计

- P0: 18 / 18 ✅
- P1: 16 / 16 ✅
- P2: 0 / 0

**总计: 34 / 34**（本包 `Tests/` 中已声明的 `@Test` 全部登记）

## 测试文件

- `BookControlPluginTests.swift` — 34 条用例

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
cd Packages/PluginBookControlButtons
swift test
```

## 维护规则

1. **新增公开 API** → 先在 TestPlan 登记测试用例,再写实现
2. **Bug 修复** → 追加回归用例,标注触发条件
3. **删除用例** → 在 commit message 说明理由
4. **状态同步** → 实现后更新 TestPlan,标记 ✅ 并填写测试方法名
