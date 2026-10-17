# TestPlan — PluginPlaybackHero

## 包概述

播放主视觉（hero）：展示封面、标题与当前曲目的头部区域。

公开类型:
- `PlaybackHeroPlugin`

### README 中的测试说明（摘自 `README.md`）

- **Test files:**
  - `Tests/PlaybackHeroTests.swift` — uses `PlaybackStub` and `MediaStub` to test direct Provider use, view model, observer, and plugin lifecycle.
- **Key scenarios tested:**
  - ViewModel initializes from Provider state, tracks asset/state changes, and falls back to `.idle`/`EmptyView` when Providers are absent.
  - Observer forwards asset and state events but ignores time changes, and stops after cancellation.
  - Confirmed empty-library events hide the Hero only in the Music scene; positive-count library events restore it, and cancellation stops updates.
  - Plugin boot registers About/Manual docs, produces both hero and right-album views, and tears them down on shutdown.
- **Running tests:**
  ```bash
  cd /Users/angel/Code/Coffic/Cisum/Packages/PluginPlaybackHero
  swift test
  ```
- Tests cover direct Provider/view-model/observer wiring and plugin assembly with fakes; SwiftUI layout behavior is not asserted.

## 测试用例清单

下表由 `Tests/` 下的真实 `@Test` 声明自动生成，方法名与代码一一对应。

| ID | 类别 | 描述 | 优先级 | 状态 | 测试文件 | 测试方法 |
|----|------|------|--------|------|----------|----------|
| 1 | 视图模型 | View model uses playback and media providers directly | P2 | ✅ 已覆盖 | `PlaybackHeroTests.swift` | `viewModelUsesPlaybackAndMediaProvidersDirectly` |
| 2 | 视图模型 | View model initializes from providers and tracks playback changes | P2 | ✅ 已覆盖 | `PlaybackHeroTests.swift` | `viewModelInitializesFromProvidersAndTracksPlaybackChanges` |
| 3 | 观察者 | Observer forwards asset and state but stops after cancellation | P1 | ✅ 已覆盖 | `PlaybackHeroTests.swift` | `observerForwardsAssetAndStateButStopsAfterCancellation` |
| 4 | 存储 | Empty repository hides hero and populated library restores it | P1 | ✅ 已覆盖 | `PlaybackHeroTests.swift` | `emptyRepositoryHidesHeroAndPopulatedLibraryRestoresIt` |
| 5 | 观察者 | Plugin assembles docs and playback views then releases observer | P2 | ✅ 已覆盖 | `PlaybackHeroTests.swift` | `pluginAssemblesDocsAndPlaybackViewsThenReleasesObserver` |
| 6 | 插件 | Plugin contributes hero views after playback providers are ready | P2 | ✅ 已覆盖 | `PlaybackHeroTests.swift` | `pluginContributesHeroViewsAfterPlaybackProvidersAreReady` |

## 覆盖率统计

- P0: 0 / 0
- P1: 2 / 2 ✅
- P2: 4 / 4 ✅

**总计: 6 / 6**（本包 `Tests/` 中已声明的 `@Test` 全部登记）

## 测试文件

- `PlaybackHeroTests.swift` — 6 条用例

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
cd Packages/PluginPlaybackHero
swift test
```

## 维护规则

1. **新增公开 API** → 先在 TestPlan 登记测试用例,再写实现
2. **Bug 修复** → 追加回归用例,标注触发条件
3. **删除用例** → 在 commit message 说明理由
4. **状态同步** → 实现后更新 TestPlan,标记 ✅ 并填写测试方法名
