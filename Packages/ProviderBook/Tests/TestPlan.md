# TestPlan — ProviderBook

## 包概述

ProviderBook 定义有声书库的跨插件契约,并拆成两个产品:
- `ProviderBook`(契约层)- `BookProviding` / `BookDatabaseProviding` 协议、`BookProvidingEvent`、`BookDTO`、`BookPluginInfo`、`BookPluginError`
- `ProviderBookData`(数据层)- `BookState`(SwiftData 模型)、`BookModel`、`BookDB`、`BookRepo`、`BookCoverRepo`、`BookSettingRepo`、`BookPathContainment`、`BookConfig`、`BookWorker/Read/Update`

其他插件只依赖契约协议;数据库容器/同步/UI 生命周期属于数据层。测试主要落在 `ProviderBookData` 的纯逻辑与文件路径判定上。

## 测试用例清单

### 契约层(ProviderBook)

| ID | 类别 | 描述 | 优先级 | 状态 | 测试方法 |
|----|------|------|------|------|----------|
| B-01 | 元信息 | `BookPluginInfo.dirName == "audios_book"`,支持扩展含 `m4b` | P1 | ✅ 已覆盖 | `bookPluginInfoSeparatesAudiobookFilesFromMusicLibrary` |
| B-02 | 错误 | 各 `BookPluginError` case 提供非空 `errorDescription`/`failureReason`/`recoverySuggestion`,初始化错误携带 reason | P1 | ✅ 已覆盖 | `bookPluginErrorsProvideDescriptionsAndRecoveryHints` |
| B-03 | DTO | `BookDTO` 稳定 identity(`id==url`)、collection/book 判定、`hasChildren`、相等性按 URL | P0 | ✅ 已覆盖 | `bookDTOExposesStableIdentityAndCollectionState` |
| B-04 | DTO | 依文件系统解析兄弟/子项 URL(`getNextURL`/`getChildrenURLs`) | P1 | ✅ 已覆盖 | `bookDTOResolvesSiblingAndChildURLsFromTheFilesystem` |
| B-05 | 协议 | 默认 `addObserver` 返回 `NoopBookProvidingObserverHandle`；默认句柄与显式创建句柄均可重复 cancel | P0 | ✅ 已覆盖 | `defaultBookObserverUsesNoopFallback` / `explicitBookNoopSupportsRepeatedCancellation` |
| B-06 | 事件 | `BookProvidingEvent` 各 case(librarySyncing/librarySynced/libraryChanged/libraryDeleted/playbackStateChanged/storageLocationChanged)由实现广播 | P1 | ❌ 缺失（依赖插件具体实现，默认 Noop 测试不验证广播） | - |
| B-07 | DTO | `BookPlaybackStateDTO` 的可选 URL/时间组合、相等性及跨任务传输保持值完整 | P0 | ✅ 已覆盖 | `playbackStateDTOTransportsOptionalFieldsAcrossTasks` |

### 数据层(ProviderBookData)

| ID | 类别 | 描述 | 优先级 | 状态 | 测试方法 |
|----|------|------|------|------|----------|
| D-01 | 模型 | `BookState` 安全默认值与当前章节标题(空态→"None") | P0 | ✅ 已覆盖 | `bookStateProvidesSafeDefaultsAndCurrentChapterTitle` |
| D-02 | 模型 | `BookState.descriptorAll`/`descriptorOf(_:)` 抓取全部与匹配单书 | P0 | ✅ 已覆盖 | `bookStateDescriptorsFetchAllAndMatchTheRequestedBook` |
| D-03 | 身份 | `representsSameBookURL` 处理 nil/自身/符号链接别名 | P0 | ✅ 已覆盖 | `bookStateIdentityHandlesMissingAndAliasedURLs` |
| D-04 | 路径 | `BookPathContainment.contains` 含根与后代,排除同级前缀(`-old`) | P0 | ✅ 已覆盖 | `containmentIncludesRootAndDescendantsButNotSiblingPrefixes` |
| D-05 | 路径 | `canonicalIdentity`:缺失文件用标准化路径,远程用标准化 absoluteString | P0 | ✅ 已覆盖 | `canonicalIdentityUsesStandardizedPathForMissingFilesAndURLsForRemoteAssets` |
| D-06 | 路径 | 符号链接别名解析到同一书籍且保持在解析后的库内 | P0 | ✅ 已覆盖 | `symlinkAliasesResolveToTheSameBookAndStayWithinTheResolvedLibrary` |
| D-07 | 路径 | `hasSameResolvedParent` 识别软链目录 | P1 | ✅ 已覆盖 | `sameResolvedParentRecognizesSymlinkedDirectory` |
| D-08 | 库策略 | `downloadProgressPercentText` 夹取分数并处理非有限值(NaN/inf→"0",>1→"100") | P1 | ✅ 已覆盖 | `progressTextClampsFractionsAndHandlesNonFiniteValues` |
| D-09 | 库策略 | `isSupportedBookLibraryItem`/`BookLibraryItemSupport` 区分可播文件与集合并计数 | P0 | ✅ 已覆盖 | `libraryItemSupportDistinguishesPlayableFilesAndCollections` |
| D-10 | 库策略 | 支持项按解析后文件身份去重(别名折叠) | P0 | ✅ 已覆盖 | `supportedItemsAreDeduplicatedByResolvedFileIdentity` |
| D-11 | 库策略 | 稳定插入排序与重复 order 检测(`sortedForStableInsertion`/`needsStableOrderRepair`) | P1 | ✅ 已覆盖 | `insertionOrderIsStableAndDuplicateOrdersAreDetected` |
| D-12 | 库策略 | 包含性同时校验存储书籍与当前章节路径 | P1 | ✅ 已覆盖 | `bookContainmentChecksBothStoredBookAndCurrentChapterPaths` |
| D-13 | 模型 | `BookModel` 派生文件/文件夹元数据(标题/order/isCollection/childCount/parent) | P1 | ✅ 已覆盖 | `bookModelDerivesFileAndFolderMetadata` |
| D-14 | 封面 | `BookCoverRepo.getCoverData(for:)` 仅对目录返回图片数据,单文件返回 nil | P1 | ✅ 已覆盖 | `coverDataReturnsOnlyImageFiles` |
| D-15 | 仓库 | `BookRepo.shutdown()` 释放初始同步等待者,关停后读取为空且可重复 | P0 | ✅ 已覆盖 | `bookRepositoryShutdownReleasesInitialSyncWaiters` |
| D-16 | 偏好 | `BookSettingRepo.storedURL` 解析绝对 URL/本地路径,拒绝 nil/空白/非路径,并 trim | P0 | ✅ 已覆盖 | `storedURLParsesAbsoluteURLStrings` / `storedURLParsesLocalPaths` / `storedURLRejectsNilEmptyAndNonPathInputs` / `storedURLTrimsWhitespace` |
| D-17 | 偏好 | `storedTime` 优先本地合法值,非法回落云端,拒绝本地/云端非法值 | P0 | ✅ 已覆盖 | `storedTimePrefersValidLocalValue` / `storedTimeFallsBackToCloudWhenLocalInvalid` / `storedTimeRejectsInvalidLocalAndCloud` |
| D-18 | 偏好 | `normalizedTimeForStorage` 过滤非有限与非正值 | P1 | ✅ 已覆盖 | `normalizedTimeForStorageFiltersNonFiniteAndNonPositive` |
| D-19 | 偏好 | 当前书籍 URL/时间的存取往返,nil 清除,无记录返回 nil | P0 | ✅ 已覆盖 | `storeAndGetCurrentURLRoundTrips` / `storeNilCurrentURLClearsIt` / `storeAndGetCurrentTimeRoundTrips` / `getCurrentTimeReturnsNilWhenNothingStored` |
| D-20 | 偏好 | 本地已存 0 优先于云端；缺失本地记录时忽略 double 默认值，云端 0 有效、无值返回 nil | P0 | ✅ 已覆盖 | `storedTimeDistinguishesStoredZeroFromMissingLocalValue` |
| D-21 | 偏好 | 本地负值/NaN/正负无穷回落合法云端；云端缺失、空字符串、非数字、负值和非有限值均拒绝 | P0 | ✅ 已覆盖 | `storedTimeValidatesNonFiniteLocalValuesAndCloudBoundaries` |

## 覆盖率统计

- 契约层:6 / 7（缺 B-06）
- 数据层:21 / 21（仅指本表已列出的场景，不代表整个数据层全覆盖）
- **合计: 27 / 28**（场景清单统计，不是源码行/分支覆盖率）

## 优先级说明

- **P0**: 身份/路径判定、可播项识别、仓库关停、播放偏好读写、DTO/State identity
- **P1**: 展示派生、封面、去重排序、错误/元信息、事件广播
- **P2**: 性能/便利性,可选

## 跨平台说明

- SwiftData 容器与 iCloud 键值存储在 iOS 17+ / macOS 14+ 可用
- 路径判定用真实文件系统临时目录,跨平台一致;远程 URL 走 absoluteString 归一

## 测试执行

从仓库根目录执行：

```bash
swift test --package-path Packages/ProviderBook --disable-automatic-resolution
```

本轮 macOS Debug 验证：36 个测试通过；iOS 与 Release 配置未运行。构建仍有基线已存在的多 target 未处理源码文件警告。

偏好读写测试在串行 suite 中执行，备份并恢复本地及 iCloud 键值存储的两个书籍偏好键；这些测试仍调用系统键值存储，不代表验证了真实跨设备同步。新增时间边界测试只调用纯函数。

## 维护规则

1. **新增公开 API** → 先在 TestPlan 登记测试用例,再写实现
2. **Bug 修复** → 追加回归用例,标注触发条件
3. **删除用例** → 在 commit message 说明理由
4. **状态同步** → 实现后更新 TestPlan,标记 ✅ 并填写测试方法名
