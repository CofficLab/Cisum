# TestPlan — PluginLikeButton

## 包概述

通用喜欢按钮：消费播放 Provider 展示并切换当前曲目收藏状态。

公开类型:
- `LikeButtonPlugin`
- `LikeButtonPluginInfo`
- `LikeToggleButtonView`

### README 中的测试说明（摘自 `README.md`）

- **Test files:**
  - `Tests/LikeButtonPluginTests.swift` — uses a `PlaybackProbe` conforming to `PlaybackProviding` to drive the view model and observer without a real player.
- **Key scenarios tested:**
  - Metadata stability (`toolbarItemId`, icon, description).
  - ViewModel initialization from the provider, fallback when playback is unavailable, and reactions to `assetChanged`, `likeStatusChanged`, and `likedAssetsChanged` events.
  - `toggleLike` forwards to `PlaybackProviding.toggleCurrentLike()`.
  - Observer forwards playback events to the view model and stops after `cancel()`.
- **Running tests:**
  ```bash
  cd /Users/angel/Code/Coffic/Cisum/Packages/PluginLikeButton
  swift test
  ```
- Tests cover the view model/observer in isolation with provider fakes; they do not boot the full plugin lifecycle.

## 测试用例清单

下表由 `Tests/` 下的真实 `@Test` 声明自动生成，方法名与代码一一对应。

| ID | 类别 | 描述 | 优先级 | 状态 | 测试文件 | 测试方法 |
|----|------|------|--------|------|----------|----------|
| 1 | 插件 | Plugin metadata is stable | P0 | ✅ 已覆盖 | `LikeButtonPluginTests.swift` | `pluginMetadataIsStable` |
| 2 | 状态 | Init reflects current playback state | P0 | ✅ 已覆盖 | `LikeButtonPluginTests.swift` | `initReflectsCurrentPlaybackState` |
| 3 | 行为 | Init falls back when playback is unavailable | P1 | ✅ 已覆盖 | `LikeButtonPluginTests.swift` | `initFallsBackWhenPlaybackIsUnavailable` |
| 4 | 状态 | Handle asset changed updates liked state | P0 | ✅ 已覆盖 | `LikeButtonPluginTests.swift` | `handleAssetChangedUpdatesLikedState` |
| 5 | 行为 | Handle like status changed updates flag | P0 | ✅ 已覆盖 | `LikeButtonPluginTests.swift` | `handleLikeStatusChangedUpdatesFlag` |
| 6 | 行为 | Handle liked assets changed reflects current u r l | P0 | ✅ 已覆盖 | `LikeButtonPluginTests.swift` | `handleLikedAssetsChangedReflectsCurrentURL` |
| 7 | 能力 | Toggle like forwards to capability | P0 | ✅ 已覆盖 | `LikeButtonPluginTests.swift` | `toggleLikeForwardsToCapability` |
| 8 | 行为 | Forwards playback events | P0 | ✅ 已覆盖 | `LikeButtonPluginTests.swift` | `forwardsPlaybackEvents` |
| 9 | 观察者 | Cancelling observer stops forwarding | P1 | ✅ 已覆盖 | `LikeButtonPluginTests.swift` | `cancellingObserverStopsForwarding` |

## 覆盖率统计

- P0: 7 / 7 ✅
- P1: 2 / 2 ✅
- P2: 0 / 0

**总计: 9 / 9**（本包 `Tests/` 中已声明的 `@Test` 全部登记）

## 测试文件

- `LikeButtonPluginTests.swift` — 9 条用例

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
cd Packages/PluginLikeButton
swift test
```

## 维护规则

1. **新增公开 API** → 先在 TestPlan 登记测试用例,再写实现
2. **Bug 修复** → 追加回归用例,标注触发条件
3. **删除用例** → 在 commit message 说明理由
4. **状态同步** → 实现后更新 TestPlan,标记 ✅ 并填写测试方法名
