# TestPlan — PluginBookSettings

## 包概述

有声书设置页装配。

公开类型:
- `BookSettingsPlugin`
- `BookSettingsPluginInfo`
- `BookSettingsView`

### README 中的测试说明（摘自 `README.md`）

- **Test files:**
  - `Tests/BookSettingsPluginTests.swift` — metadata, policy, view helpers, and
    view-model tests.
- **Key scenarios tested:**
  - Metadata: `iconName == "gearshape"`, `order == 11`.
  - `BookSettingsMetricsPolicy`: applies metrics only when the current disk, requested
    disk, and generation all match; rejects mismatched disk, stale generation, and
    nil current disk.
  - `BookSettingsView.shouldShowOpenLibraryAction`: hidden for a missing local disk,
    shown for an existing one.
  - `BookSettingsView.shouldUseSingularFileCount`: true only for count == 1.
  - ViewModel: empty initial state; `handleStorageLocationChanged` bumps
    `refreshToken`; `refresh()` with nil disk clears metrics; `refresh()` on a local
    directory collects real size and file count (waits for the detached task); a
    stale refresh result is discarded.
- **Running tests:**
  ```bash
  cd /Users/angel/Code/Coffic/Cisum/Packages/PluginBookSettings
  swift test
  ```

## 测试用例清单

下表由 `Tests/` 下的真实 `@Test` 声明自动生成，方法名与代码一一对应。

| ID | 类别 | 描述 | 优先级 | 状态 | 测试文件 | 测试方法 |
|----|------|------|--------|------|----------|----------|
| 1 | 插件 | Plugin info exports registration metadata | P0 | ✅ 已覆盖 | `BookSettingsPluginTests.swift` | `pluginInfoExportsRegistrationMetadata` |
| 2 | 行为 | Book settings only applies current disk metrics | P0 | ✅ 已覆盖 | `BookSettingsPluginTests.swift` | `bookSettingsOnlyAppliesCurrentDiskMetrics` |
| 3 | 行为 | Book settings hides open library action for missing local disk | P1 | ✅ 已覆盖 | `BookSettingsPluginTests.swift` | `bookSettingsHidesOpenLibraryActionForMissingLocalDisk` |
| 4 | 行为 | Book settings uses singular file count only for one file | P0 | ✅ 已覆盖 | `BookSettingsPluginTests.swift` | `bookSettingsUsesSingularFileCountOnlyForOneFile` |
| 5 | 状态 | Init has empty state | P1 | ✅ 已覆盖 | `BookSettingsPluginTests.swift` | `initHasEmptyState` |
| 6 | 行为 | Storage location change bumps refresh token | P0 | ✅ 已覆盖 | `BookSettingsPluginTests.swift` | `storageLocationChangeBumpsRefreshToken` |
| 7 | 行为 | Refresh without disk clears metrics | P1 | ✅ 已覆盖 | `BookSettingsPluginTests.swift` | `refreshWithoutDiskClearsMetrics` |
| 8 | 行为 | Refresh with local directory collects metrics | P0 | ✅ 已覆盖 | `BookSettingsPluginTests.swift` | `refreshWithLocalDirectoryCollectsMetrics` |
| 9 | 行为 | Stale refresh result is discarded | P1 | ✅ 已覆盖 | `BookSettingsPluginTests.swift` | `staleRefreshResultIsDiscarded` |

## 覆盖率统计

- P0: 5 / 5 ✅
- P1: 4 / 4 ✅
- P2: 0 / 0

**总计: 9 / 9**（本包 `Tests/` 中已声明的 `@Test` 全部登记）

## 测试文件

- `BookSettingsPluginTests.swift` — 9 条用例

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
cd Packages/PluginBookSettings
swift test
```

## 维护规则

1. **新增公开 API** → 先在 TestPlan 登记测试用例,再写实现
2. **Bug 修复** → 追加回归用例,标注触发条件
3. **删除用例** → 在 commit message 说明理由
4. **状态同步** → 实现后更新 TestPlan,标记 ✅ 并填写测试方法名
