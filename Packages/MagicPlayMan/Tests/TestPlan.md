# TestPlan — MagicPlayMan

## 包概述

MagicPlayMan 是 Cisum 的媒体播放内核：封装 `AVFoundation` 播放器，负责媒体请求校验、
播放队列、进度/时长归一化、iCloud 下载态与失败分类、以及播放进度条与控制按钮的呈现。

本包把大量易错的边界判定抽成纯函数 `enum` 策略类型（`*Policy`），便于单测直接覆盖；
同时提供 `MagicPlayMan` 播放器主体与 `AssetCache` 磁盘缓存。

核心组件:
- `MagicPlayMan` / `PlaybackState` / `MagicAsset` / `PlaybackSymbol` - 播放主体与状态
- `AssetCache` / `AssetCacheFileSizePolicy` - 磁盘缓存与文件大小读取
- 时间推进策略: `MagicPlayManPlaybackTimePolicy` / `MagicPlayManTimeUpdatePolicy` / `MagicPlayManSeekPolicy`
- 请求校验策略: `MagicPlayManPlaybackRequestPolicy` / `MagicPlayManControlInputPolicy`
- 下载策略: `MagicPlayManDownloadRequestPolicy` / `MagicPlayManDownloadProgressPolicy` /
  `MagicPlayManDownloadObserverPolicy`
- 呈现策略: `MagicProgressBarPolicy` / `MediaPickerButtonAccessibilityPolicy` /
  `AudioContentArtworkLoadPolicy` / `PlaybackPreviewGradient`
- 视图: `AudioPlayerView` / `VideoPlayerView` / `HeroView` / `StateView` / `MagicPlayProgressView` /
  `MagicProgressBar` / `MediaPickerButton` / `PlayModeButton` / `ErrorOverlay` / `LoadingOverlay`
- `SupportedFormat` / `Localization` / `LocalizationKey` - 格式支持与本地化

## 测试用例清单

| ID | 类别 | 描述 | 前置条件 | 操作步骤 | 预期结果 | 优先级 | 状态 | 测试方法 |
|----|------|------|----------|----------|----------|------|------|----------|
| 1 | 播放时间 | 时长归一化拒绝非有限值 / 负值，保留正值 | - | 传入 NaN、负值、正值 | NaN 被拒；负值归零；正值保留 | P0 | ✅ 已覆盖 | `testNormalizedDurationRejectsNonFiniteValues` / `testNormalizedDurationClampsNegativeValues` / `testNormalizedDurationKeepsPositiveValues` |
| 2 | 播放时间 | 单位进度归一化覆盖拒绝非有限值、越界、合法区间 | - | 传入 NaN、越界、0~1 | 与输入一一对应 | P0 | ✅ 已覆盖 | `testNormalizedUnitProgressRejectsNonFiniteValues` / `testNormalizedUnitProgressClampsOutOfRange` / `testNormalizedUnitProgressKeepsInRange` |
| 3 | 播放时间 | 当前时间归一化：无时长不夹取、超时长夹取、无效时长忽略 | - | 组合当前时间与时长边界 | 各分支符合预期 | P0 | ✅ 已覆盖 | `testNormalizedCurrentTimeRejectsNonFiniteValues` / `testNormalizedCurrentTimeClampsNegativeWithoutDuration` / `testNormalizedCurrentTimeKeepsValueWithoutDuration` / `testNormalizedCurrentTimeClampsToDuration` / `testNormalizedCurrentTimeIgnoresInvalidDuration` |
| 4 | 播放时间 | 进度归一化覆盖无效输入、比值计算、越界夹取 | - | 组合当前时间与时长 | 进度合法且位于 0~1 | P0 | ✅ 已覆盖 | `testNormalizedProgressRejectsInvalidInputs` / `testNormalizedProgressComputesRatio` / `testNormalizedProgressClampsOutOfRange` |
| 5 | 播放时间 | 仅播放完毕才从头重播 | - | 边界时间点求判定 | 仅在结束时为 true | P0 | ✅ 已覆盖 | `testShouldRestartFromBeginningRejectsInvalidInputs` / `testShouldRestartFromBeginningOnlyWhenFinished` |
| 6 | 播放模式 | 模式循环前进、显示名反映当前模式 | - | 连续切换、查显示名 | 循环顺序稳定且文案匹配 | P1 | ✅ 已覆盖 | `testTogglePlayModeCyclesForward` / `testPlayModeDisplayNameReflectsCurrentMode` |
| 7 | 资产 | `MagicAsset` 默认值、完整初始化、按标识判等与计算属性 | - | 构造与比较 | 默认值、判等、派生属性正确 | P1 | ✅ 已覆盖 | `testMetadataDefaults` / `testMetadataFullInit` / `testAssetEqualityComparesIdentity` / `testAssetComputedProperties` |
| 8 | 无障碍 | 媒体选择按钮标签含控制目的，空白名回落纯提示 | - | 传入选中名与提示语 | `Select Media: X` / `Select Media` | P1 | ✅ 已覆盖 | `testMediaPickerAccessibilityLabelIncludesControlPurpose` |
| 9 | 事件归属 | 播放结束通知 / NowPlaying 元数据 / 封面结果必须属于当前条目 | 播放中切换资源 | 触发旧资源事件 | 陈旧事件被拒绝 | P0 | ✅ 已覆盖 | `testPlaybackEndNotificationMustBelongToCurrentItem` / `testNowPlayingMetadataResultMustBelongToCurrentAsset` / `testAudioArtworkResultMustBelongToCurrentAsset` |
| 10 | 事件归属 | NowPlaying 元数据匹配符号链接后的当前资源 | 当前资源为软链 | 触发元数据回填 | 元数据仍归属当前资源 | P1 | ✅ 已覆盖 | `testNowPlayingMetadataMatchesSymlinkedCurrentAsset` |
| 11 | 远程命令 | 注册远程命令替换既有 target，不累积 | 已注册过 | 再次注册 | 替换而非追加 | P1 | ✅ 已覆盖 | `testRemoteCommandRegistrationReplacesExistingTargets` |
| 12 | 请求校验 | 缺失本地文件、不支持格式被拒绝 | - | 提交非法播放请求 | 请求被拒 | P0 | ✅ 已覆盖 | `testPlaybackRequestValidationRejectsMissingLocalFiles` / `testPlaybackRequestValidationRejectsUnsupportedFiles` |
| 13 | 请求校验 | HLS 流与有声书文件被接受 | - | 提交合法请求 | 请求通过 | P0 | ✅ 已覆盖 | `testPlaybackRequestValidationAcceptsHLSStreams` / `testPlaybackRequestValidationAcceptsAudiobookFiles` |
| 14 | seek 策略 | 夹取越界时间，时长未知时允许正时间，规范化可选起始时间 | - | 边界输入 | 结果夹取到 0~时长 | P0 | ✅ 已覆盖 | `testSeekPolicyClampsInvalidAndOutOfRangeTimes` / `testSeekPolicyAllowsPositiveTimeWhenDurationIsUnknown` / `testSeekPolicyNormalizesOptionalStartTime` |
| 15 | 控制输入 | 音量与跳过间隔归一化 | - | 越界输入 | 落入合法区间 | P1 | ✅ 已覆盖 | `testControlInputPolicyNormalizesVolume` / `testControlInputPolicyNormalizesSkipIntervals` |
| 16 | 时间推进 | 推进策略拒绝非法时间/时长，夹取进度，到末尾重启 | - | 边界输入 | 状态迁移正确 | P0 | ✅ 已覆盖 | `testPlaybackTimePolicyRejectsInvalidTimes` / `testPlaybackTimePolicyRejectsInvalidDurations` / `testPlaybackTimePolicyClampsProgress` / `testPlaybackTimePolicyRestartsWhenAtOrPastEnd` |
| 17 | 时间更新 | 时间更新策略归一化负载中的非法值 | - | 传入非法负载 | 非法值被清洗 | P1 | ✅ 已覆盖 | `testTimeUpdatePolicyNormalizesInvalidPayloadValues` |
| 18 | 进度条 | 进度归一化、seek 坐标夹取与非法几何拒绝 | - | 越界与非法尺寸 | 夹取或拒绝 | P0 | ✅ 已覆盖 | `testProgressPolicyNormalizesInvalidAndOutOfRangeValues` / `testSeekPolicyClampsCoordinatesAndRejectsInvalidGeometry` |
| 19 | 进度条 | 时间格式化非负且为分秒格式；binding 夹取并回传有效 seek 时间 | - | 格式化与拖动 | 文案合法、时间在区间内 | P1 | ✅ 已覆盖 | `testFormattedTimeIsNonnegativeAndUsesMinuteSecondFormat` / `testProgressBarBindingClampsAndReportsEffectiveSeekTime` |
| 20 | 资源缓存 | 同名不同 URL 分离；超长签名 URL 可用 | 同名缓存项 | 写入两 URL | 各自独立命中 | P0 | ✅ 已覆盖 | `testSeparatesDifferentURLsWithSameFilename` / `testHandlesLongSignedURLs` |
| 21 | 资源缓存 | 报告缓存数据大小；文件大小读取归一化非法值 | - | 读取属性 | 大小为非负数值 | P1 | ✅ 已覆盖 | `testReportsCachedDataSize` / `testFileSizePolicyReadsFoundationNumberAttributes` / `testFileSizePolicyNormalizesInvalidSizes` |
| 22 | 资源缓存 | 缓存目录位置被替换（含悬空软链） | 缓存目录已存在 | 触发替换 | 旧位置不被误用 | P1 | ✅ 已覆盖 | `testReplacesFileAtCacheDirectory` / `testReplacesDanglingSymlinkAtCacheDirectory` |
| 23 | 下载归属 | 下载结果必须属于当前资源；符号链接场景仍匹配 | 播放中切换资源 | 触发下载回调 | 陈旧结果被丢弃 | P0 | ✅ 已覆盖 | `testResultMustBelongToCurrentAsset` / `testResultMatchesSymlinkedCurrentAsset` |
| 24 | 下载归属 | 观察者清理只使用匹配请求（含符号链接），远程资源需精确 URL 标识 | - | 组合请求与回调 | 只清理匹配观察者 | P0 | ✅ 已覆盖 | `testObserverCleanupOnlyUsesMatchingRequest` / `testObserverCleanupMatchesSymlinkedRequest` / `testRemoteAssetsRequireExactURLIdentity` |
| 25 | iCloud 失败 | iCloud 失败与网络错误互不混淆，下载中不算失败 | - | 构造各错误 | 分类互斥且正确 | P0 | ✅ 已覆盖 | `testICloudFailureIsNotTreatedAsNetworkError` / `testNetworkErrorIsNotICloudFailure` / `testDownloadingStateIsNotFailure` / `testClassificationMapsICloudErrorsToICloudFailure` / `testClassificationLeavesForeignErrorsAsNetworkError` |
| 26 | iCloud 失败 | iCloud 失败文案与网络错误不同，恢复建议指向 iCloud | - | 读取文案 | 文案区分且可操作 | P1 | ✅ 已覆盖 | `testICloudFailureHasDistinctMessageFromNetworkError` / `testFailureReasonAndRecoveryPointAtICloudNotNetwork` / `testRecoverySuggestionMentionsICloudStorage` / `testStandaloneFailureReasonAndRecoveryAreNonEmpty` |
| 27 | 错误文案 | 每个播放错误都有非空描述 | - | 遍历全部错误 case | 描述非空 | P0 | ✅ 已覆盖 | `testEveryPlaybackErrorHasNonEmptyDescription` |
| 28 | 错误文案 | 每个错误 case 的失败原因/恢复建议均有本地化，错误本地化描述可用 | - | 遍历错误 case | 四语文案齐全 | P1 | ✅ 已覆盖 | `testErrorDescriptionsAreAvailableForEveryCase` / `testErrorLocalizedDescription` / `testErrorLocalizedFailureReason` / `testErrorLocalizedRecoverySuggestion` / `testErrorStandardFailureReason` / `testErrorStandardRecoverySuggestion` |
| 29 | 本地化 | iCloud 文案四语齐全且简繁不同 | - | 逐语言取值 | 无缺译且简繁有别 | P1 | ✅ 已覆盖 | `testICloudStringsResolveForEveryLanguage` / `testSimplifiedAndTraditionalDiffer` |
| 30 | 失败呈现 | 失败态呈现不同于播放态，失败态不可 seek | - | 求呈现与能力 | 失败态禁止 seek | P1 | ✅ 已覆盖 | `testFailurePresentationDiffersFromPlaying` / `testFailedStateCannotSeek` |
| 31 | 下载进度 | iCloud 下载等待期进度上升，重复请求仍发布进度，轮询零值不回退 | 等待下载 | 多次轮询 | 进度单调不减 | P0 | ✅ 已覆盖 | `testDownloadProgressRisesWhileWaitingForICloudContent` / `testRepeatedPlayRequestStillPublishesProgress` / `testPollingZeroNeverRegressesPublishedProgress` |
| 32 | 播放状态 | 模式/状态枚举的显示名、短名、图标、别名、循环顺序、rawValue 稳定 | - | 逐项检查 | 与预设一致 | P1 | ✅ 已覆盖 | `testDisplayName` / `testShortName` / `testIconName` / `testIconAlias` / `testNextCyclesCorrectly` / `testAllCases` / `testRawValue` |
| 33 | 播放状态 | 播放状态标志与能力：isPlaying/isLoading/isDownloading/isUnsupportedFormat/canSeek | - | 构造各状态 | 标志互斥且正确 | P0 | ✅ 已覆盖 | `testIsPlaying` / `testIsLoading` / `testIsDownloading` / `testIsUnsupportedFormat` / `testCanSeek` |
| 34 | 播放状态 | 状态文案、下载百分比夹取、本地化状态文本与错误描述 | - | 遍历状态 | 文案齐全、百分比合法 | P1 | ✅ 已覆盖 | `testToastMessage` / `testStateText` / `testDownloadPercentTextClamping` / `testLocalizedStateText` / `testLocalizedErrorDescription` |
| 35 | 播放状态 | 状态判等语义 | - | 比较相等/不等状态 | 判等一致 | P1 | ✅ 已覆盖 | `testStateEquality` / `testErrorEquality` |
| 36 | 播放主体 | `MagicPlayMan` 异步播放/切换/队列/事件发布的端到端行为（62 例） | 注入替身 | 覆盖播放、暂停、切歌、队列、并发 | 行为与事件序列一致 | P0 | ✅ 已覆盖 | `MagicPlayManAsyncTests`（62 个 `func test*`） |
| 37 | 真实播放器视图 | `AudioPlayerView`/`VideoPlayerView`/`HeroView` 端到端渲染与交互 | 需宿主窗口与实机 | 启动、拖动、控制栏操作 | UI 与播放状态同步 | P1 | ❌ 缺失 | - |

## 覆盖率统计

- P0: 已覆盖 15 / 15
- P1: 已覆盖 20 / 21
- **合计: 35 / 36**（仅表示清单场景，非源码覆盖率）

> 统计仅表示清单场景，不是源码覆盖率。163 个测试方法已在 macOS 运行，iOS 未实跑。

## 优先级说明

- **P0**: 时间/进度归一化、请求校验、事件归属、下载归属、iCloud 失败分类、异步播放主体
- **P1**: 播放模式与状态枚举、本地化文案、进度条与缓存呈现
- **P2**: 视图端到端交互（需实机/宿主窗口）

## 跨平台说明

- iOS 17+ / macOS 14+；`AVFoundation` 播放能力两端一致
- 纯函数 `*Policy` 策略在本机（macOS CI）即可覆盖 iOS / macOS 两条分支
- `MagicPlayManAsyncTests` 依赖 `AVPlayer` 真实时序，iOS 模拟器未实跑

## 测试执行

```bash
cd Packages/MagicPlayMan
swift test
```

## 维护规则

1. **新增公开 API** → 先在 TestPlan 登记测试用例，再写实现
2. **Bug 修复** → 追加回归用例，标注触发条件
3. **删除用例** → 在 commit message 说明理由
4. **状态同步** → 实现后更新 TestPlan，标记 ✅ 并填写测试方法名
