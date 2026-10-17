# TestPlan — PluginAudioDownload

## 包概述

音乐下载：自动下载策略、任务调度与 iCloud 网关集成。

公开类型:
- `AudioDownloadPlugin`
- `AudioDownloadPluginInfo`
- `AudioDownloadRootView`

### README 中的测试说明（摘自 `README.md`）

- **Test files**: `Tests/AudioDownloadPluginTests.swift`.
- **Key scenarios tested**:
  - Registration metadata: `iconName == "icloud.and.arrow.down"`, `order == 2`; music scene identifier `AppScene.music.rawValue == "Music Library"`.
  - `AudioDownloadRequestPolicy`: only starts for an active, missing asset; does not start a duplicate active download; does not restart after a successful download; applies results only to the current asset; stale results do not apply after scene deactivation; results apply for a symlinked current asset but not across distinct dangling symlinks.
  - ViewModel gating: inactive scene ignores asset changes; nil asset in the music scene is ignored; leaving the music scene bumps generation without crashing.
- **Running tests**:
  ```bash
  cd /Users/angel/Code/Coffic/Cisum/Packages/PluginAudioDownload
  swift test
  ```

## 测试用例清单

下表由 `Tests/` 下的真实 `@Test` 声明自动生成，方法名与代码一一对应。

| ID | 类别 | 描述 | 优先级 | 状态 | 测试文件 | 测试方法 |
|----|------|------|--------|------|----------|----------|
| 1 | 行为 | Ensure local availability follows injected stub | P0 | ✅ 已覆盖 | `AudioDownloadGatewayIntegrationTests.swift` | `ensureLocalAvailabilityFollowsInjectedStub` |
| 2 | 行为 | Never completing raises timeout | P0 | ✅ 已覆盖 | `AudioDownloadGatewayIntegrationTests.swift` | `neverCompletingRaisesTimeout` |
| 3 | 行为 | Offline raises request failed | P1 | ✅ 已覆盖 | `AudioDownloadGatewayIntegrationTests.swift` | `offlineRaisesRequestFailed` |
| 4 | 行为 | Repeated trigger downloads once | P0 | ✅ 已覆盖 | `AudioDownloadGatewayIntegrationTests.swift` | `repeatedTriggerDownloadsOnce` |
| 5 | 行为 | Downloaded asset does not start download | P0 | ✅ 已覆盖 | `AudioDownloadGatewayIntegrationTests.swift` | `downloadedAssetDoesNotStartDownload` |
| 6 | 行为 | Stale result is discarded after scene change | P1 | ✅ 已覆盖 | `AudioDownloadGatewayIntegrationTests.swift` | `staleResultIsDiscardedAfterSceneChange` |
| 7 | 插件 | Plugin info exports registration metadata | P0 | ✅ 已覆盖 | `AudioDownloadPluginTests.swift` | `pluginInfoExportsRegistrationMetadata` |
| 8 | 行为 | Audio download uses stable audio scene identifier | P0 | ✅ 已覆盖 | `AudioDownloadPluginTests.swift` | `audioDownloadUsesStableAudioSceneIdentifier` |
| 9 | 行为 | Audio download only starts for active missing asset | P1 | ✅ 已覆盖 | `AudioDownloadPluginTests.swift` | `audioDownloadOnlyStartsForActiveMissingAsset` |
| 10 | 行为 | Audio download does not start duplicate active download | P1 | ✅ 已覆盖 | `AudioDownloadPluginTests.swift` | `audioDownloadDoesNotStartDuplicateActiveDownload` |
| 11 | 行为 | Audio download only applies current asset results | P0 | ✅ 已覆盖 | `AudioDownloadPluginTests.swift` | `audioDownloadOnlyAppliesCurrentAssetResults` |
| 12 | 行为 | Stale audio download results do not apply after scene deactivation | P1 | ✅ 已覆盖 | `AudioDownloadPluginTests.swift` | `staleAudioDownloadResultsDoNotApplyAfterSceneDeactivation` |
| 13 | 行为 | Audio download applies results for symlinked current asset | P0 | ✅ 已覆盖 | `AudioDownloadPluginTests.swift` | `audioDownloadAppliesResultsForSymlinkedCurrentAsset` |
| 14 | 行为 | Audio download does not apply results across distinct dangling symlinks | P1 | ✅ 已覆盖 | `AudioDownloadPluginTests.swift` | `audioDownloadDoesNotApplyResultsAcrossDistinctDanglingSymlinks` |
| 15 | 行为 | Inactive scene ignores asset changes | P0 | ✅ 已覆盖 | `AudioDownloadPluginTests.swift` | `inactiveSceneIgnoresAssetChanges` |
| 16 | 行为 | Nil asset in music scene is ignored | P1 | ✅ 已覆盖 | `AudioDownloadPluginTests.swift` | `nilAssetInMusicSceneIsIgnored` |
| 17 | 行为 | Leaving music scene bumps generation | P0 | ✅ 已覆盖 | `AudioDownloadPluginTests.swift` | `leavingMusicSceneBumpsGeneration` |

## 覆盖率统计

- P0: 10 / 10 ✅
- P1: 7 / 7 ✅
- P2: 0 / 0

**总计: 17 / 17**（本包 `Tests/` 中已声明的 `@Test` 全部登记）

## 测试文件

- `AudioDownloadGatewayIntegrationTests.swift` — 6 条用例
- `AudioDownloadPluginTests.swift` — 11 条用例

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
cd Packages/PluginAudioDownload
swift test
```

## 维护规则

1. **新增公开 API** → 先在 TestPlan 登记测试用例,再写实现
2. **Bug 修复** → 追加回归用例,标注触发条件
3. **删除用例** → 在 commit message 说明理由
4. **状态同步** → 实现后更新 TestPlan,标记 ✅ 并填写测试方法名
