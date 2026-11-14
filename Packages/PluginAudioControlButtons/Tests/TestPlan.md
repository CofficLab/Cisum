# TestPlan — PluginAudioControlButtons

## 包概述

音乐播放控制按钮组（更多 / 上一首 / 播放暂停 / 下一首 / 播放模式），把按钮点击翻译为播放与导航命令。

公开类型:
- `AudioControlButtonsPlugin`

### README 中的测试说明（摘自 `README.md`）

- **Test files**: `Tests/ControlButtonsTests.swift`.
- **Key scenarios tested**:
  - `ControlButtonsPlaybackRequestPolicy`: navigation results only apply to the requested current asset; deletion matches the current asset but not another; deactivation invalidates pending requests via generation bump.
  - `ControlButtonsViewModel` integration (using Provider-conforming probes for playback, navigation, and toast): init reflects playback state; scene mismatch deactivates the control; playing state tracks asset changes; failure toasts are de-duplicated for identical failures but re-fire for new ones; scene change invalidates pending navigation; Next navigates and plays; Next at end / Previous at start without repeat-all present an error; Next with repeat-all wraps to first; missing Providers report unavailable; deletion of the current asset resets playback while deletion of an unrelated asset is ignored.
- **Running tests**:
  ```bash
  cd /Users/angel/Code/Coffic/Cisum/Packages/PluginAudioControlButtons
  swift test
  ```

## 测试用例清单

下表由 `Tests/` 下的真实 `@Test` 声明自动生成，方法名与代码一一对应。

| ID | 类别 | 描述 | 优先级 | 状态 | 测试文件 | 测试方法 |
|----|------|------|--------|------|----------|----------|
| 1 | 行为 | Navigation only applies to the requested current asset | P0 | ✅ 已覆盖 | `ControlButtonsTests.swift` | `navigationOnlyAppliesToTheRequestedCurrentAsset` |
| 2 | 行为 | Deletion matches the current asset but not another asset | P0 | ✅ 已覆盖 | `ControlButtonsTests.swift` | `deletionMatchesTheCurrentAssetButNotAnotherAsset` |
| 3 | 行为 | Deactivation invalidates pending requests | P1 | ✅ 已覆盖 | `ControlButtonsTests.swift` | `deactivationInvalidatesPendingRequests` |
| 4 | 行为 | Forwards consumed events and drops others | P0 | ✅ 已覆盖 | `ControlButtonsTests.swift` | `forwardsConsumedEventsAndDropsOthers` |
| 5 | 行为 | Degrades gracefully when playback provider is absent | P1 | ✅ 已覆盖 | `ControlButtonsTests.swift` | `degradesGracefullyWhenPlaybackProviderIsAbsent` |
| 6 | 状态 | Init reflects playback state | P0 | ✅ 已覆盖 | `ControlButtonsTests.swift` | `initReflectsPlaybackState` |
| 7 | 行为 | Scene mismatch deactivates control | P1 | ✅ 已覆盖 | `ControlButtonsTests.swift` | `sceneMismatchDeactivatesControl` |
| 8 | 状态 | Apply state changed tracks playing | P0 | ✅ 已覆盖 | `ControlButtonsTests.swift` | `applyStateChangedTracksPlaying` |
| 9 | 状态 | Failure state presents error once | P1 | ✅ 已覆盖 | `ControlButtonsTests.swift` | `failureStatePresentsErrorOnce` |
| 10 | 行为 | Scene change invalidates pending navigation | P1 | ✅ 已覆盖 | `ControlButtonsTests.swift` | `sceneChangeInvalidatesPendingNavigation` |
| 11 | 行为 | Next navigates and plays | P0 | ✅ 已覆盖 | `ControlButtonsTests.swift` | `nextNavigatesAndPlays` |
| 12 | 行为 | Next at end without repeat all presents error | P1 | ✅ 已覆盖 | `ControlButtonsTests.swift` | `nextAtEndWithoutRepeatAllPresentsError` |
| 13 | 行为 | Previous at start without repeat all presents error | P1 | ✅ 已覆盖 | `ControlButtonsTests.swift` | `previousAtStartWithoutRepeatAllPresentsError` |
| 14 | 行为 | Next with repeat all falls back to first | P0 | ✅ 已覆盖 | `ControlButtonsTests.swift` | `nextWithRepeatAllFallsBackToFirst` |
| 15 | 能力 | Previous without capability reports unavailable | P1 | ✅ 已覆盖 | `ControlButtonsTests.swift` | `previousWithoutCapabilityReportsUnavailable` |
| 16 | 能力 | Toggle without capability reports unavailable | P1 | ✅ 已覆盖 | `ControlButtonsTests.swift` | `toggleWithoutCapabilityReportsUnavailable` |
| 17 | 行为 | Deletion of current asset resets playback | P1 | ✅ 已覆盖 | `ControlButtonsTests.swift` | `deletionOfCurrentAssetResetsPlayback` |
| 18 | 行为 | Deletion of unrelated asset is ignored | P0 | ✅ 已覆盖 | `ControlButtonsTests.swift` | `deletionOfUnrelatedAssetIsIgnored` |

## 覆盖率统计

- P0: 8 / 8 ✅
- P1: 10 / 10 ✅
- P2: 0 / 0

**总计: 18 / 18**（本包 `Tests/` 中已声明的 `@Test` 全部登记）

## 测试文件

- `ControlButtonsTests.swift` — 18 条用例

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
cd Packages/PluginAudioControlButtons
swift test
```

## 维护规则

1. **新增公开 API** → 先在 TestPlan 登记测试用例,再写实现
2. **Bug 修复** → 追加回归用例,标注触发条件
3. **删除用例** → 在 commit message 说明理由
4. **状态同步** → 实现后更新 TestPlan,标记 ✅ 并填写测试方法名
