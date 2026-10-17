# TestPlan — PluginAudioLike

## 包概述

音乐收藏：生产 `AudioLikeProviding`，并向播放控制等消费方提供收藏状态。

公开类型:
- `AudioLikePlugin`
- `AudioLikeModel`
- `AudioLikePluginInfo`
- `AudioLikeRepoError`
- `AudioLikeRepositoryConfiguration`
- `AudioLikeRepo`
- `AudioLikeRootView`
- `AudioLikeSettingsView`

### README 中的测试说明（摘自 `README.md`）

- **Test files**: `Tests/AudioLikePluginTests.swift`.
- **Key scenarios tested**:
  - Metadata: `iconName == "heart"`, `emoji == "❤️"`, `order == 3`; the settings navigation item exposes id `"liked-audio"` and title "Liked audio" (while `addSettingView()` returns nil).
  - Main-thread delivery: like-status notification is delivered on the main thread.
  - `AudioLikeRepo`: unliked audio does not create a stored record; liking then unliking creates then removes the record; the repo honors a reconfigured database URL; persists url/title metadata and backfills missing metadata; matches a symlinked liked audio; does not match distinct dangling symlinks; unlikes a symlinked stored audio; replaces a symlinked duplicate like (single liked entry).
  - `AudioLikeViewModel`: reload applies only the latest generation; scene activation gates like saving (inactive → no save, active → saves and posts, leaving → gates again); observer forwards scene selection without crashing.
- **Running tests**:
  ```bash
  cd /Users/angel/Code/Coffic/Cisum/Packages/PluginAudioLike
  swift test
  ```

## 测试用例清单

下表由 `Tests/` 下的真实 `@Test` 声明自动生成，方法名与代码一一对应。

| ID | 类别 | 描述 | 优先级 | 状态 | 测试文件 | 测试方法 |
|----|------|------|--------|------|----------|----------|
| 1 | 插件 | Plugin info exports registration metadata | P0 | ✅ 已覆盖 | `AudioLikePluginTests.swift` | `pluginInfoExportsRegistrationMetadata` |
| 2 | 插件 | Plugin exposes settings navigation item | P0 | ✅ 已覆盖 | `AudioLikePluginTests.swift` | `pluginExposesSettingsNavigationItem` |
| 3 | 行为 | Audio like status notification is delivered on main thread | P0 | ✅ 已覆盖 | `AudioLikePluginTests.swift` | `audioLikeStatusNotificationIsDeliveredOnMainThread` |
| 4 | 存储 | Unliked audio does not create stored record | P0 | ✅ 已覆盖 | `AudioLikePluginTests.swift` | `unlikedAudioDoesNotCreateStoredRecord` |
| 5 | 行为 | Audio like repo uses reconfigured database u r l | P0 | ✅ 已覆盖 | `AudioLikePluginTests.swift` | `audioLikeRepoUsesReconfiguredDatabaseURL` |
| 6 | 持久化 | Audio like repo persists metadata for settings | P0 | ✅ 已覆盖 | `AudioLikePluginTests.swift` | `audioLikeRepoPersistsMetadataForSettings` |
| 7 | 元数据 | Audio like repo backfills missing metadata | P1 | ✅ 已覆盖 | `AudioLikePluginTests.swift` | `audioLikeRepoBackfillsMissingMetadata` |
| 8 | 行为 | Audio like repo matches symlinked liked audio | P0 | ✅ 已覆盖 | `AudioLikePluginTests.swift` | `audioLikeRepoMatchesSymlinkedLikedAudio` |
| 9 | 行为 | Audio like repo does not match distinct dangling symlinked audio | P1 | ✅ 已覆盖 | `AudioLikePluginTests.swift` | `audioLikeRepoDoesNotMatchDistinctDanglingSymlinkedAudio` |
| 10 | 存储 | Audio like repo unlikes symlinked stored audio | P0 | ✅ 已覆盖 | `AudioLikePluginTests.swift` | `audioLikeRepoUnlikesSymlinkedStoredAudio` |
| 11 | 行为 | Audio like repo replaces symlinked duplicate like | P1 | ✅ 已覆盖 | `AudioLikePluginTests.swift` | `audioLikeRepoReplacesSymlinkedDuplicateLike` |
| 12 | 行为 | Reload applies only latest generation | P0 | ✅ 已覆盖 | `AudioLikePluginTests.swift` | `reloadAppliesOnlyLatestGeneration` |
| 13 | 行为 | Scene change activation gates like saving | P0 | ✅ 已覆盖 | `AudioLikePluginTests.swift` | `sceneChangeActivationGatesLikeSaving` |
| 14 | 视图模型 | Observer forwards scene selection to view model | P2 | ✅ 已覆盖 | `AudioLikePluginTests.swift` | `observerForwardsSceneSelectionToViewModel` |

## 覆盖率统计

- P0: 10 / 10 ✅
- P1: 3 / 3 ✅
- P2: 1 / 1 ✅

**总计: 14 / 14**（本包 `Tests/` 中已声明的 `@Test` 全部登记）

## 测试文件

- `AudioLikePluginTests.swift` — 14 条用例

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
cd Packages/PluginAudioLike
swift test
```

## 维护规则

1. **新增公开 API** → 先在 TestPlan 登记测试用例,再写实现
2. **Bug 修复** → 追加回归用例,标注触发条件
3. **删除用例** → 在 commit message 说明理由
4. **状态同步** → 实现后更新 TestPlan,标记 ✅ 并填写测试方法名
