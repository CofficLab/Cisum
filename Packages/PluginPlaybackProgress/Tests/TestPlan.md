# TestPlan — PluginPlaybackProgress

## 包概述

通用播放进度条装配。

公开类型:
- `PlaybackProgressPlugin`

### README 中的测试说明（摘自 `README.md`）

- **Test files:**
  - `Tests/PlaybackProgressTests.swift` — uses a `PlaybackStub` to test direct Provider use, view model, binding, observer, and full plugin lifecycle.
- **Key scenarios tested:**
  - ViewModel reads time/duration and forwards seeks directly through `PlaybackProviding`.
  - ViewModel syncs initial/asset state and normalizes seek input (`-1`/`.nan` become 0).
  - The view's time binding updates the display without triggering a seek, while `handleSeek` forwards to the Provider.
  - Observer routes time/duration/asset events and stops after cancellation; an observer with no playback can still be cancelled safely.
  - Plugin lifecycle: docs registered exactly once, progress view produced, observer count stays 1 across repeated `onReady`, drops to 0 on `onDisable`, returns to 1 on `onEnable`, and clears on shutdown; missing optional providers are tolerated; about/manual views build.
- **Running tests:**
  ```bash
  cd /Users/angel/Code/Coffic/Cisum/Packages/PluginPlaybackProgress
  swift test
  ```
- Tests are among the more thorough in this group: they cover seek normalization, binding semantics, observer cancellation, and the enable/disable lifecycle.

## 测试用例清单

下表由 `Tests/` 下的真实 `@Test` 声明自动生成，方法名与代码一一对应。

| ID | 类别 | 描述 | 优先级 | 状态 | 测试文件 | 测试方法 |
|----|------|------|--------|------|----------|----------|
| 1 | 视图模型 | View model uses playback provider for snapshot and seek | P2 | ✅ 已覆盖 | `PlaybackProgressTests.swift` | `viewModelUsesPlaybackProviderForSnapshotAndSeek` |
| 2 | 视图模型 | View model uses safe snapshot after playback is released | P2 | ✅ 已覆盖 | `PlaybackProgressTests.swift` | `viewModelUsesSafeSnapshotAfterPlaybackIsReleased` |
| 3 | 视图模型 | View model syncs initial and asset state and normalizes seek input | P2 | ✅ 已覆盖 | `PlaybackProgressTests.swift` | `viewModelSyncsInitialAndAssetStateAndNormalizesSeekInput` |
| 4 | 行为 | Progress binding updates display without duplicating playback seek | P1 | ✅ 已覆盖 | `PlaybackProgressTests.swift` | `progressBindingUpdatesDisplayWithoutDuplicatingPlaybackSeek` |
| 5 | 观察者 | Observer routes progress events and stops after cancellation | P1 | ✅ 已覆盖 | `PlaybackProgressTests.swift` | `observerRoutesProgressEventsAndStopsAfterCancellation` |
| 6 | 观察者 | Observer without playback can be cancelled | P1 | ✅ 已覆盖 | `PlaybackProgressTests.swift` | `observerWithoutPlaybackCanBeCancelled` |
| 7 | 观察者 | Plugin registers docs and restores observer across lifecycle | P0 | ✅ 已覆盖 | `PlaybackProgressTests.swift` | `pluginRegistersDocsAndRestoresObserverAcrossLifecycle` |
| 8 | 插件 | Plugin handles missing optional providers | P1 | ✅ 已覆盖 | `PlaybackProgressTests.swift` | `pluginHandlesMissingOptionalProviders` |
| 9 | 行为 | Progress and documentation views build their content | P2 | ✅ 已覆盖 | `PlaybackProgressTests.swift` | `progressAndDocumentationViewsBuildTheirContent` |

## 覆盖率统计

- P0: 1 / 1 ✅
- P1: 4 / 4 ✅
- P2: 4 / 4 ✅

**总计: 9 / 9**（本包 `Tests/` 中已声明的 `@Test` 全部登记）

## 测试文件

- `PlaybackProgressTests.swift` — 9 条用例

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
cd Packages/PluginPlaybackProgress
swift test
```

## 维护规则

1. **新增公开 API** → 先在 TestPlan 登记测试用例,再写实现
2. **Bug 修复** → 追加回归用例,标注触发条件
3. **删除用例** → 在 commit message 说明理由
4. **状态同步** → 实现后更新 TestPlan,标记 ✅ 并填写测试方法名
