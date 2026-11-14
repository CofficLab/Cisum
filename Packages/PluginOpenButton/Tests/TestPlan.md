# TestPlan — PluginOpenButton

## 包概述

通用打开按钮：在 Finder / 默认程序中打开当前文件。

公开类型:
- `OpenButtonPluginInfo`
- `OpenButtonPlugin`
- `OpenCurrentButtonView`

### README 中的测试说明（摘自 `README.md`）

- **Test files:**
  - `Tests/OpenButtonPluginTests.swift` — metadata and the `shouldShowOpenButton` reachability rule.
  - `Tests/OpenButtonCoverageTests.swift` — a `PlaybackProbe`-driven suite for the view model and observer.
- **Key scenarios tested:**
  - Metadata stability (`toolbarItemId = "open-current"`, accessibility title `"Show in Finder"`).
  - `shouldShowOpenButton(for:)` accepts an existing local file, rejects a missing local file, and rejects a remote (https) URL.
  - ViewModel reflects the current URL, handles `assetChanged(nil)`, and falls back to `nil` without a capability.
  - The adapter exposes `currentURL`; the observer forwards asset changes and stops after `cancel()`.
- **Running tests:**
  ```bash
  cd /Users/angel/Code/Coffic/Cisum/Packages/PluginOpenButton
  swift test
  ```
- Tests cover the view model/adapter/observer with fakes and the reachability predicate directly; the button's Finder action itself is not executed.

## 测试用例清单

下表由 `Tests/` 下的真实 `@Test` 声明自动生成，方法名与代码一一对应。

| ID | 类别 | 描述 | 优先级 | 状态 | 测试文件 | 测试方法 |
|----|------|------|--------|------|----------|----------|
| 1 | 插件 | Plugin info is stable | P0 | ✅ 已覆盖 | `OpenButtonCoverageTests.swift` | `pluginInfoIsStable` |
| 2 | 行为 | Init reflects current u r l | P0 | ✅ 已覆盖 | `OpenButtonCoverageTests.swift` | `initReflectsCurrentURL` |
| 3 | 行为 | Init without playback keeps nil | P1 | ✅ 已覆盖 | `OpenButtonCoverageTests.swift` | `initWithoutPlaybackKeepsNil` |
| 4 | 行为 | Handle asset changed updates u r l | P0 | ✅ 已覆盖 | `OpenButtonCoverageTests.swift` | `handleAssetChangedUpdatesURL` |
| 5 | 行为 | Forwards asset changes | P0 | ✅ 已覆盖 | `OpenButtonCoverageTests.swift` | `forwardsAssetChanges` |
| 6 | 观察者 | Cancelling observer stops forwarding | P1 | ✅ 已覆盖 | `OpenButtonCoverageTests.swift` | `cancellingObserverStopsForwarding` |
| 7 | 插件 | Plugin metadata is stable | P0 | ✅ 已覆盖 | `OpenButtonPluginTests.swift` | `pluginMetadataIsStable` |
| 8 | 行为 | Open current button requires reachable local file | P0 | ✅ 已覆盖 | `OpenButtonPluginTests.swift` | `openCurrentButtonRequiresReachableLocalFile` |

## 覆盖率统计

- P0: 6 / 6 ✅
- P1: 2 / 2 ✅
- P2: 0 / 0

**总计: 8 / 8**（本包 `Tests/` 中已声明的 `@Test` 全部登记）

## 测试文件

- `OpenButtonCoverageTests.swift` — 6 条用例
- `OpenButtonPluginTests.swift` — 2 条用例

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
cd Packages/PluginOpenButton
swift test
```

## 维护规则

1. **新增公开 API** → 先在 TestPlan 登记测试用例,再写实现
2. **Bug 修复** → 追加回归用例,标注触发条件
3. **删除用例** → 在 commit message 说明理由
4. **状态同步** → 实现后更新 TestPlan,标记 ✅ 并填写测试方法名
