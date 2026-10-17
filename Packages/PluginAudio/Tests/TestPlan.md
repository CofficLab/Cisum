# TestPlan — PluginAudio

## 包概述

音频主插件：注册音频场景栈、播放器、数据库视图与音频相关 Provider，是音乐场景的装配入口。

公开类型:
- `AudioPlugin`
- `AudioRootView`

### README 中的测试说明（摘自 `README.md`）

- **Test files**: `Tests/AudioRootViewTests.swift`.
- **Key scenarios tested**:
  - `AudioRootErrorPresentation` mapping: `.storageMissing` yields the storage-setup guidance (no detail); `.initialization("database is locked")` surfaces the underlying detail.
  - `AudioRootViewModel`: `reloadContainer` finishes initialization when storage exists and reports `.storageMissing` when it does not; repeated storage-location changes produce a fresh notice each time.
  - `AudioStorageObserver`: drives a reload on storage events (initial load, then missing-storage error + notice) and supports idempotent cancellation. A `StorageProviderProbe` stub stands in for `StorageProviding`.
- **Running tests**:
  ```bash
  cd /Users/angel/Code/Coffic/Cisum/Packages/PluginAudio
  swift test
  ```

## 测试用例清单

下表由 `Tests/` 下的真实 `@Test` 声明自动生成，方法名与代码一一对应。

| ID | 类别 | 描述 | 优先级 | 状态 | 测试文件 | 测试方法 |
|----|------|------|--------|------|----------|----------|
| 1 | 行为 | Missing storage error keeps storage setup guidance | P1 | ✅ 已覆盖 | `AudioRootViewTests.swift` | `missingStorageErrorKeepsStorageSetupGuidance` |
| 2 | 行为 | Database initialization error shows actual failure | P1 | ✅ 已覆盖 | `AudioRootViewTests.swift` | `databaseInitializationErrorShowsActualFailure` |
| 3 | 行为 | Reload with storage finishes initialization | P0 | ✅ 已覆盖 | `AudioRootViewTests.swift` | `reloadWithStorageFinishesInitialization` |
| 4 | 行为 | Reload without storage reports missing storage | P1 | ✅ 已覆盖 | `AudioRootViewTests.swift` | `reloadWithoutStorageReportsMissingStorage` |
| 5 | 行为 | Storage location change produces new notice | P0 | ✅ 已覆盖 | `AudioRootViewTests.swift` | `storageLocationChangeProducesNewNotice` |
| 6 | 观察者 | Observer drives reload on storage events | P0 | ✅ 已覆盖 | `AudioRootViewTests.swift` | `observerDrivesReloadOnStorageEvents` |
| 7 | 观察者 | Observer cancellation is idempotent | P1 | ✅ 已覆盖 | `AudioRootViewTests.swift` | `observerCancellationIsIdempotent` |
| 8 | 元数据 | Plugin exposes stable identity and presentation | P1 | ✅ 已覆盖 | `AudioRootViewTests.swift` | `pluginExposesStableIdentityAndPresentation` |
| 9 | 元数据 | Metadata carries expected localization and stage | P1 | ✅ 已覆盖 | `AudioRootViewTests.swift` | `metadataCarriesExpectedLocalizationAndStage` |
| 10 | 元数据 | Plugin re-exports info constants | P1 | ✅ 已覆盖 | `AudioRootViewTests.swift` | `pluginReexportsInfoConstants` |

## 覆盖率统计

- P0: 3 / 3 ✅
- P1: 7 / 7 ✅
- P2: 0 / 0

**总计: 10 / 10**（本包 `Tests/` 中已声明的 `@Test` 全部登记）

## 测试文件

- `AudioRootViewTests.swift` — 10 条用例

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
cd Packages/PluginAudio
swift test
```

## 维护规则

1. **新增公开 API** → 先在 TestPlan 登记测试用例,再写实现
2. **Bug 修复** → 追加回归用例,标注触发条件
3. **删除用例** → 在 commit message 说明理由
4. **状态同步** → 实现后更新 TestPlan,标记 ✅ 并填写测试方法名
