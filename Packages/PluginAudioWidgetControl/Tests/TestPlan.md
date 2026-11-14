# TestPlan — PluginAudioWidgetControl

## 包概述

小组件播放控制：把播放控制暴露给 Widget 时间线。

公开类型:
- `AudioWidgetControlPlugin`
- `AudioWidgetControlPluginInfo`
- `AudioWidgetControlRootView`

### README 中的测试说明（摘自 `README.md`）

- **Test files**: `Tests/AudioWidgetControlPluginTests.swift`.
- **Key scenarios tested**:
  - Metadata: `iconName == "command"`; title/description non-empty.
  - `AudioWidgetPlaybackRequestPolicy`: navigation results only apply to an unchanged current asset (symlinked asset matches; distinct dangling symlinks do not); waits for an in-flight navigation task; command counting preserves rapid repeats (caps at 10, handles legacy timestamp/NSNumber triggers, ignores unexpected types); command consumption preserves commands added during handling; play-pause acts only on odd repeated commands.
  - `AudioWidgetControlViewModel`: odd play-pause toggles and clears the trigger; even play-pause is a no-op but still consumes the command; next navigates to the adjacent asset; previous wraps to the last asset in repeat-all; a missing playback Provider still consumes the pending command.
- **Running tests**:
  ```bash
  cd /Users/angel/Code/Coffic/Cisum/Packages/PluginAudioWidgetControl
  swift test
  ```

## 测试用例清单

下表由 `Tests/` 下的真实 `@Test` 声明自动生成，方法名与代码一一对应。

| ID | 类别 | 描述 | 优先级 | 状态 | 测试文件 | 测试方法 |
|----|------|------|--------|------|----------|----------|
| 1 | 插件 | Plugin metadata is stable | P0 | ✅ 已覆盖 | `AudioWidgetControlPluginTests.swift` | `pluginMetadataIsStable` |
| 2 | 行为 | Navigation result only applies to unchanged current asset | P0 | ✅ 已覆盖 | `AudioWidgetControlPluginTests.swift` | `navigationResultOnlyAppliesToUnchangedCurrentAsset` |
| 3 | 行为 | Navigation result applies to symlinked current asset | P0 | ✅ 已覆盖 | `AudioWidgetControlPluginTests.swift` | `navigationResultAppliesToSymlinkedCurrentAsset` |
| 4 | 行为 | Navigation result does not apply to distinct dangling symlinks | P1 | ✅ 已覆盖 | `AudioWidgetControlPluginTests.swift` | `navigationResultDoesNotApplyToDistinctDanglingSymlinks` |
| 5 | 行为 | Widget navigation waits for previous navigation task | P2 | ✅ 已覆盖 | `AudioWidgetControlPluginTests.swift` | `widgetNavigationWaitsForPreviousNavigationTask` |
| 6 | 行为 | Widget command count preserves rapid repeated commands | P1 | ✅ 已覆盖 | `AudioWidgetControlPluginTests.swift` | `widgetCommandCountPreservesRapidRepeatedCommands` |
| 7 | 行为 | Widget command count accepts legacy timestamp trigger | P2 | ✅ 已覆盖 | `AudioWidgetControlPluginTests.swift` | `widgetCommandCountAcceptsLegacyTimestampTrigger` |
| 8 | 行为 | Widget command consumption preserves commands added during handling | P2 | ✅ 已覆盖 | `AudioWidgetControlPluginTests.swift` | `widgetCommandConsumptionPreservesCommandsAddedDuringHandling` |
| 9 | 行为 | Widget play pause command toggles only odd repeated commands | P2 | ✅ 已覆盖 | `AudioWidgetControlPluginTests.swift` | `widgetPlayPauseCommandTogglesOnlyOddRepeatedCommands` |
| 10 | 行为 | Play pause odd command toggles | P0 | ✅ 已覆盖 | `AudioWidgetControlPluginTests.swift` | `playPauseOddCommandToggles` |
| 11 | 行为 | Play pause even command is no op | P1 | ✅ 已覆盖 | `AudioWidgetControlPluginTests.swift` | `playPauseEvenCommandIsNoOp` |
| 12 | 行为 | Next command navigates to adjacent asset | P0 | ✅ 已覆盖 | `AudioWidgetControlPluginTests.swift` | `nextCommandNavigatesToAdjacentAsset` |
| 13 | 行为 | Previous command falls back to last asset in repeat all | P0 | ✅ 已覆盖 | `AudioWidgetControlPluginTests.swift` | `previousCommandFallsBackToLastAssetInRepeatAll` |
| 14 | 能力 | Missing capability still consumes command | P1 | ✅ 已覆盖 | `AudioWidgetControlPluginTests.swift` | `missingCapabilityStillConsumesCommand` |

## 覆盖率统计

- P0: 6 / 6 ✅
- P1: 4 / 4 ✅
- P2: 4 / 4 ✅

**总计: 14 / 14**（本包 `Tests/` 中已声明的 `@Test` 全部登记）

## 测试文件

- `AudioWidgetControlPluginTests.swift` — 14 条用例

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
cd Packages/PluginAudioWidgetControl
swift test
```

## 维护规则

1. **新增公开 API** → 先在 TestPlan 登记测试用例,再写实现
2. **Bug 修复** → 追加回归用例,标注触发条件
3. **删除用例** → 在 commit message 说明理由
4. **状态同步** → 实现后更新 TestPlan,标记 ✅ 并填写测试方法名
