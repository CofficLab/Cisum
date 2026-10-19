# TestPlan — MagicKit

## 包概述

MagicKit 是 Cisum 的通用工具层，包含两大块：

1. **Shell 封装**（`ShellFile` / `ShellProcess` / `ShellSystem` / `ShellNetwork`）与
   **Git 封装**（`ShellGit` 系列的 add/commit/branch/checkout/clone/diff/log/merge/
   remote/reset/stash/status/tag/config）——重点是**参数字面量传递**，禁止 Shell 展开。
2. **基础设施**（`HttpClient` / `ICloudDirectoryMonitor` / `LocalDirectoryMonitor` /
   `ICloudDownloadControl` / `FileManagerUbiquitousItemDownloader` / `ThumbnailCache` /
   `AvatarView` / `SmartSync` / `TimeFormatter` / `MagicLogger`）与基础协议
   （`SuperLog` / `SuperThread` / `SuperEvent` / `SuperCloudModel` / `SuperSyncDelegate`）。

本包测试呈**双框架混用**：`MagicKitTests` / `ICloudDownloadingTests` /
`CoAuthoredByTest` / `LocalDirectoryMonitorTests` / `MagicKitPerformanceTests` 使用
**XCTest**（`func test*`），其余 22 个 `Shell*` 等文件使用 **Swift Testing**（`@Test`）。

核心组件:
- Shell 封装: `ShellFile` / `ShellProcess` / `ShellSystem` / `ShellNetwork`
- Git 封装: `MagicGitBranch` / `MagicGitCommit` / `MagicGitCommitDetail` / `MagicGitDiffFile` /
  `MagicGitRemote` / `MagicGitStash` / `MagicGitTag` / `CommitWithTag`
- 网络与 iCloud: `HttpClient` / `ICloudDirectoryMonitor` / `ICloudDownloadControl` /
  `FileManagerUbiquitousItemDownloader` / `GlobalDownloadMonitor` / `AvatarDownloadMonitor` /
  `StubUbiquitousItemDownloader` / `ICloudDownloadError` / `CloudState`
- 视图与工具: `AvatarView` / `ThumbnailCache` / `ThumbnailGenerator` / `ThumbnailSource` /
  `AvatarSize` / `AvatarViewShape` / `TimeFormatter` / `MagicLogger` / `MagicLogEntry`
- 策略类型: `URLOpenActionPolicy` / `URLDirectoryContainmentPolicy` /
  `URLDownloadAvailabilityPolicy` / `URLDownloadProgressPolicy` / `DateRelativeTimePolicy`
- 基础协议与枚举: `SuperLog` / `SuperThread` / `SuperEvent` / `SuperCloudModel` /
  `SuperSyncDelegate` / `FileType` / `ShellError` / `HttpError` / `MagicError` / `MagicApp`

## 测试用例清单

| ID | 类别 | 描述 | 前置条件 | 操作步骤 | 预期结果 | 优先级 | 状态 | 测试方法 |
|----|------|------|----------|----------|----------|------|------|----------|
| 1 | Shell 核心 | 同步执行支持并发调用者 | - | 多线程并发 `runSync` | 结果一致、无串扰 | P0 | ✅ 已覆盖 | `shellRunSyncHandlesConcurrentCallers` |
| 2 | Shell 核心 | 命令查表对用户输入加引号，且不展开 Shell 语法 | 含空格/元字符的输入 | 构造命令 | 输入被引号包裹且不展开 | P0 | ✅ 已覆盖 | `shellCommandLookupQuotesUserInput` / `shellCommandLookupDoesNotExpandShellSyntax` |
| 3 | 文件命令 | 写入/文件命令保留字面路径，支持前导 `-` 路径 | 含特殊字符路径 | 执行命令 | 路径不被当作选项 | P0 | ✅ 已覆盖 | `shellFileMakeFileWritesLiteralContent` / `shellFileCommandsPreserveLiteralPaths` / `shellFileCommandsHandleLeadingDashPaths` |
| 4 | 进程命令 | `top` 使用 macOS sort 参数；负数数量被夹取；拒绝非法 PID；按精确 PID 查找 | - | 组合 PID 与数量 | 输出合法、非法输入被拒 | P1 | ✅ 已覆盖 | `shellProcessTopCommandsUseMacOSSortFlags` / `shellProcessTopCommandsClampNegativeCount` / `shellProcessCommandsPreserveLiteralInputs` / `shellProcessCommandsRejectInvalidPIDs` / `shellProcessFindProcessUsesExactPIDLookup` / `shellProcessTopQueriesReturnProcessesOnMacOS` |
| 5 | 系统命令 | 系统/磁盘/环境命令保留字面输入，不做 Shell 展开 | - | 含特殊字符输入 | 输入被字面传递 | P0 | ✅ 已覆盖 | `shellSystemCommandsPreserveLiteralInputs` / `shellSystemDiskUsageHandlesLeadingDashPaths` / `shellSystemEnvironmentReadsWithoutShellExpansion` |
| 6 | 网络命令 | 网络命令保留字面输入；ping 次数在合法区间；非法端口被拒；失败文案为可读英文 | - | 越界与非法输入 | 夹取或拒绝，文案可读 | P1 | ✅ 已覆盖 | `shellNetworkCommandsPreserveLiteralInputs` / `shellNetworkPingCountsStayInValidRange` / `shellNetworkPortCommandsRejectInvalidPorts` / `shellNetworkFailureMessagesAreReadableEnglish` |
| 7 | Git 日志 | 日志/提交详情/recent commit 解析器保留主题与正文中的 `\|`，使用安全分隔符 | 含竖线提交 | 解析 porcelain 输出 | 竖线不被误切分 | P0 | ✅ 已覆盖 | `shellGitLogParserPreservesPipesInSubjects` / `shellGitCommitDetailParserPreservesPipesInBody` / `shellGitCommitDetailParserPreservesPipesInSubjects` / `shellGitRecentCommitParserPreservesPipesWithSafeSeparator` |
| 8 | Git 日志 | 装饰解析提取真实 tag；跳过残缺 recent commit 行；拒绝非法时间戳；ISO8601 提交日期解析拒绝畸形日期 | 含 tag 的仓库 | 解析日志 | 解析结果准确，残缺行被跳过 | P1 | ✅ 已覆盖 | `shellGitLogDecorationParserExtractsRealTagDecorations` / `shellGitLogParserSkipsMalformedRecentCommitRows` / `shellGitCommitDetailParserRejectsInvalidTimestamp` / `shellGitISO8601DateParserRejectsMalformedDates` |
| 9 | Git 日志 | 日志命令保留字面 ref，限制与分页夹取负数 | - | 负数限制/大小 | 夹取为合法值 | P1 | ✅ 已覆盖 | `shellGitLogCommandsPreserveLiteralRefs` / `shellGitLogCommandsClampNegativeLimits` / `shellGitLogPaginationClampsNegativeSizeBeforeSkip` |
| 10 | Git 状态 | 未暂存文件含未跟踪文件；porcelain 解析忽略仅暂存行与重命名源记录 | 含未跟踪/重命名的工作区 | 解析状态 | 未跟踪计入，重命名取目标路径 | P0 | ✅ 已覆盖 | `shellGitUnstagedFilesIncludesUntrackedFiles` / `shellGitUnstagedPorcelainParserIgnoresStagedOnlyRows` / `shellGitUnstagedPorcelainZParserSkipsRenameSourceRecords` / `shellGitUnstagedPorcelainZParserSkipsWorktreeRenameSourceRecords` / `shellGitUnstagedFilesUseRenamedDestinationOnly` |
| 11 | Git 暂存 | add/reset 使用 pathspec 分隔符，保留字面文件名并处理前导 `-` | 含特殊字符文件 | add/reset | 文件路径不被误解析 | P0 | ✅ 已覆盖 | `shellGitAddCommandsUsePathspecSeparator` / `shellGitAddAndResetPreserveLiteralFileNames` / `shellGitAddAndResetHandleLeadingDashFileNames` |
| 12 | Git 检出 | 空选择时文件检出跳过且为 no-op；保留字面分支与文件名 | - | 空选择与特殊分支名 | 空选择无副作用，名称字面传递 | P1 | ✅ 已覆盖 | `shellGitCheckoutFilesCommandSkipsEmptySelection` / `shellGitCheckoutFilesNoOpsForEmptySelection` / `shellGitCheckoutPreservesLiteralBranchAndFileNames` |
| 13 | Git 分支 | 保留字面分支名（含 `$`、反引号等 shell 元字符） | `feature/$HOME-\`uname\`` | 创建/查询/删除分支 | 分支名原样保留 | P0 | ✅ 已覆盖 | `shellGitBranchPreservesLiteralBranchNames` |
| 14 | Git 标签 | 保留字面 tag 消息与 ref | - | 打标签 | 消息原样保留 | P1 | ✅ 已覆盖 | `shellGitTagPreservesLiteralMessage` / `shellGitTagCommandsPreserveLiteralRefs` |
| 15 | Git remote | 保留字面输入；解析忽略残缺 verbose 行，保留 URL 中的空格 | 含空格 URL | 添加/解析 remote | URL 不被切分 | P1 | ✅ 已覆盖 | `shellGitRemoteCommandsPreserveLiteralInputs` / `shellGitRemoteParserIgnoresMalformedVerboseRows` / `shellGitRemoteParserPreservesSpacesInURLs` |
| 16 | Git config | 保留字面用户名 | 含空格/元字符 | 设置 user | 值原样保存 | P1 | ✅ 已覆盖 | `shellGitConfigUserPreservesLiteralValues` |
| 17 | Git clone/merge/reset/stash/commit | 保留字面输入（URL、消息、文件名与 ref） | - | 执行各命令 | 输入字面传递，状态文案为可读英文 | P1 | ✅ 已覆盖 | `shellGitCloneCommandsPreserveLiteralInputs` / `shellGitMergeCommandsPreserveLiteralInputs` / `shellGitMergeStatusMessagesAreReadableEnglish` / `shellGitResetCommandsPreserveLiteralFileAndRefNames` / `shellGitStashPreservesLiteralMessage` / `shellGitCommitPreservesLiteralMessage` |
| 18 | Git diff | name-status 对重命名/复制取新路径，简单变更取路径，跳过残缺行；`-z` 解析保留特殊路径；引号路径可解析 | 含重命名与特殊字符路径 | 解析 diff | 路径与状态正确 | P0 | ✅ 已覆盖 | `shellGitNameStatusParserUsesNewPathForRenamesAndCopies` / `shellGitNameStatusParserUsesPathForSimpleChanges` / `shellGitNameStatusParserSkipsMalformedRows` / `shellGitNameStatusZParserPreservesSpecialPaths` / `shellGitDiffHandlesQuotedFilePaths` |
| 19 | Git diff | 命令保留字面 ref 与路径；工作目录读取留在仓库内 | - | 含空格/引号路径，切换 cwd | 路径不被误解析，读取不越界 | P0 | ✅ 已覆盖 | `shellGitDiffCommandsPreserveLiteralRefsAndPaths` / `shellGitWorkingDirectoryReadsStayInsideRepository` |
| 20 | Git commit 详情 | co-author 解析、无 co-author、无邮箱 co-author、详情与提交转换 | 多作者提交 | 解析详情 | 作者信息完整 | P1 | ✅ 已覆盖 | `testCoAuthorsParsing` / `testNoCoAuthors` / `testCoAuthorWithoutEmail` / `testGitCommitDetailCoAuthors` / `testGitCommitFromDetail` |
| 21 | iCloud 目录监控 | 生命周期抑制已取消的延迟启动；陈旧取消后保留替换 run | - | 取消后触发 | 不产生陈旧回调 | P0 | ✅ 已覆盖 | `iCloudDirectoryMonitorLifecycleSuppressesCancelledDelayedStart` / `iCloudDirectoryMonitorLifecycleKeepsReplacementRunAfterStaleCancel` |
| 22 | iCloud 目录监控 | 直接扫描枚举嵌套占位符文件；接受可读空目录；非空目录不接受空快照 | 占位符目录 | 直接扫描 | 快照与真实内容一致 | P0 | ✅ 已覆盖 | `iCloudDirectoryMonitorDirectScanEnumeratesNestedPlaceholderLikeFiles` / `iCloudDirectoryMonitorDirectScanAcceptsAReadableEmptyDirectory` / `iCloudDirectoryMonitorDoesNotAcceptAnEmptySnapshotForNonemptyDirectory` |
| 23 | iCloud 下载 | 已有本地内容/非 iCloud 文件直接返回不启动下载 | - | 调用下载 | 不重复下载 | P0 | ✅ 已覆盖 | `testLocalContentFileReturnsWithoutStartingDownload` / `testNonICloudFileReturnsWithoutDownload` |
| 24 | iCloud 下载 | 轮询后完成；超时抛 `timedOut` 并带文件名；启动失败归类为 `requestFailed`；外部错误被包装 | 注入 stub | 组合失败场景 | 错误类型正确 | P0 | ✅ 已覆盖 | `testDownloadCompletesAfterExpectedPolls` / `testTimeoutThrowsTimedOutErrorWithFileName` / `testStartFailureIsClassifiedAsRequestFailed` / `testForeignErrorIsWrappedIntoRequestFailed` |
| 25 | iCloud 下载 | 同步变体抛同类错误、可用时成功；超时覆盖优先于调用方传值 | - | 调用同步 API | 行为与异步一致 | P1 | ✅ 已覆盖 | `testSyncVariantThrowsSameErrorTypeAsAsync` / `testSyncVariantSucceedsWhenContentArrives` / `testTimeoutOverrideWinsOverCallerValue` |
| 26 | iCloud 下载 | bootstrap 行为解析：忽略缺省、安装成功行为、安装超时与离线行为、拒绝未知值、接受空格分隔 | - | 解析 bootstrap 参数 | 行为正确映射或拒绝 | P1 | ✅ 已覆盖 | `testBootstrapIgnoresAbsentArgument` / `testBootstrapInstallsSuccessBehavior` / `testBootstrapInstallsTimeoutAndOfflineBehaviors` / `testBootstrapRejectsUnknownValue` / `testBootstrapAcceptsSpaceSeparatedValue` |
| 27 | iCloud 错误 | 所有 iCloud 下载错误归类为 iCloud 失败；每个错误描述非空 | - | 遍历错误 | 分类与文案齐全 | P0 | ✅ 已覆盖 | `testICloudDownloadErrorsAreAllICloudFailures` / `testEveryErrorHasNonEmptyDescription` |
| 28 | stub 进度 | stub 进度单调且收敛；零轮询立即完成 | - | 轮询 stub | 进度单调不减 | P1 | ✅ 已覆盖 | `testStubProgressIsMonotonicAndConverges` / `testStubZeroPollsIsImmediatelyComplete` |
| 29 | URL 工具 | `toURL` 保留合法 URL，非法字符串回落 file URL；HTML 转 Markdown；样例 URL 保留远程 scheme | - | 解析字符串 | 结果符合预期 | P1 | ✅ 已覆盖 | `testToURLKeepsValidURL` / `testToURLFallsBackToFileURLForInvalidURLString` / `testToMarkdownConvertsCommonHtmlElements` / `testSampleURLsKeepRemoteSchemes` |
| 30 | 本地可用性 | 本地文件/空本地文件均有本地内容；iCloud 占位符不因存在即视为已下载 | 占位符文件 | 查询可用性 | 占位符不算已下载 | P0 | ✅ 已覆盖 | `testEnsureLocalAvailabilityReturnsForLocalFile` / `testLocalFileHasLocalContent` / `testEmptyLocalFileHasLocalContent` / `testICloudPlaceholderIsNotTreatedAsDownloadedJustBecauseItExists` |
| 31 | 下载进度策略 | 下载进度夹取非法值 | - | 传入非法值 | 进度合法 | P1 | ✅ 已覆盖 | `testDownloadProgressPolicyClampsInvalidValues` |
| 32 | 复制语义 | 复制到自身/复制到子目录被拒且不删除源；符号链接文件复制为独立文件；替换目标悬空软链 | - | 组合复制场景 | 拒绝时源保留，替换成功 | P0 | ✅ 已覆盖 | `testCopyToRejectsCopyingFileOntoItselfWithoutDeletingSource` / `testCopyToRejectsCopyingFolderIntoDescendantWithoutDeletingChild` / `testCopyToCopiesSymlinkedFileAsStandaloneFile` / `testCopyToReplacesDanglingDestinationSymlink` |
| 33 | 同文件位置 | 归一化相对片段；保持互异悬空软链分离 | 含 `..` 的路径 | 判定同位置 | 同位置判定正确 | P0 | ✅ 已覆盖 | `testSameFileLocationNormalizesRelativeSegments` / `testSameFileLocationKeepsDistinctDanglingSymlinksSeparate` |
| 34 | 目录包含 | 不匹配兄弟前缀；根目录视为绝对路径父级 | - | 判定包含 | 前缀不误判，根判定正确 | P0 | ✅ 已覆盖 | `testDirectoryContainmentDoesNotMatchSiblingPrefix` / `testDirectoryContainmentTreatsRootAsParentOfAbsolutePaths` |
| 35 | 打开/在 Finder 中显示 | 打开动作仅允许已存在本地文件；Finder 仅允许已存在路径与软链 | - | 对不存在的路径调用 | 动作被拒 | P0 | ✅ 已覆盖 | `testOpenActionOnlyAllowsExistingLocalFiles` / `testRevealInFinderAllowsExistingPathsAndSymlinksOnly` / `revealInFinderOnlyAllowsLocalPaths` |
| 36 | 无障碍与统计 | 打开按钮无障碍标签描述目标；目录大小与计数跳过隐藏文件 | - | 读取统计 | 文案可读、统计不含隐藏项 | P1 | ✅ 已覆盖 | `openButtonAccessibilityLabelDescribesTarget` / `directorySizeAndCountSkipHiddenFiles` |
| 37 | 兄弟文件导航 | 上一/下一个文件解析规范化目录项；当前文件非目录子项时返回 nil | - | 在目录内导航 | 解析正确 | P1 | ✅ 已覆盖 | `nextAndPreviousFileResolveCanonicalizedDirectoryEntries` / `siblingNavigationReturnsNilWhenTheCurrentFileIsNotAChild` |
| 38 | 日志 | 后台清理日志在主线程生效；事件后台投递回落主线程 | - | 后台 emit | 回调在主线程 | P0 | ✅ 已覆盖 | `testMagicLoggerClearLogsFromBackgroundClearsOnMainThread` / `superEventDeliversBackgroundEmitsOnMainThread` |
| 39 | 时间格式化 | 时长格式化合法值并归一化非法值；相对时间格式化过去/未来并归一化非法日期 | - | 格式化边界值 | 文案合法且非负 | P1 | ✅ 已覆盖 | `timeFormatterFormatsValidDurations` / `timeFormatterNormalizesInvalidDurations` / `relativeTimeFormatsPastAndFutureDates` / `relativeTimeNormalizesInvalidDates` |
| 40 | CGSize 描述 | 有限值沿用既有整数格式；非有限值归一化不崩溃；单侧非有限时保留另一侧 | - | 构造 CGSize | 描述字符串合法 | P1 | ✅ 已覆盖 | `finiteDescription` / `nonFiniteDescription` / `mixedFiniteDescription` |
| 41 | 本地目录监控 | 文件列表变更检测 | - | 改动目录 | 变更被检测 | P1 | ✅ 已覆盖 | `testFileListChangeDetection` |
| 42 | 缩略图 | 图片裁剪正确性 | - | 裁剪图片 | 尺寸符合预期 | P1 | ✅ 已覆盖 | `testImageCropping` |
| 43 | 缩略图 | 图片裁剪性能不退化 | - | 基准裁剪 | 耗时在阈值内 | P2 | ✅ 已覆盖 | `testImageCroppingPerformance` |
| 44 | 智能同步 | `SmartSync` actor 的增量同步与 `SuperSyncDelegate` 回调语义 | 需真实 iCloud 容器 | 触发同步 | 回调与数据一致 | P2 | ❌ 缺失 | - |

## 覆盖率统计

- P0: 已覆盖 16 / 16
- P1: 已覆盖 26 / 26
- P2: 已覆盖 1 / 2
- **合计: 43 / 44**（仅表示清单场景，非源码覆盖率）

> 统计仅表示清单场景，不是源码覆盖率。MagicKit 存在 Swift Testing / XCTest 双框架混用，
> `swift test` 两者都会执行。ID 44 的 `SmartSync` 需真实 iCloud 容器，标注为 ❌ 缺失而非虚假打勾。

## 优先级说明

- **P0**: Shell/Git 命令的**字面量传递**与解析器正确性（注入风险最高：命令注入、路径误解析）、
  iCloud 下载错误分类、目录包含与同文件位置判定、日志线程语义
- **P1**: 数量/分页夹取、文案可读性、无障碍标签、统计与格式化
- **P2**: 性能基准、需真实 iCloud 容器的集成路径

## 跨平台说明

- iOS 17+ / macOS 14+；**Shell / Git 测试整体被 `#if os(macOS)` 包裹**，
  仅在 macOS CI 执行，iOS 侧无覆盖（见 `ShellGitBranchTests.swift` 等文件头部）
- `ShellProcess` 的 `top` 命令使用 macOS 专有 sort 参数，行为与 Linux 不一致
- `ThumbnailCache` / `AvatarView` 的图像裁剪路径两端一致

## 测试执行

```bash
cd Packages/MagicKit
swift test
```

## 维护规则

1. **新增公开 API** → 先在 TestPlan 登记测试用例，再写实现
2. **新增 Shell/Git 命令** → 必须登记「字面量传递」用例（含空格、`-` 开头、`$`、反引号、竖线）
3. **Bug 修复** → 追加回归用例，标注触发条件
4. **删除用例** → 在 commit message 说明理由
5. **状态同步** → 实现后更新 TestPlan，标记 ✅ 并填写测试方法名
