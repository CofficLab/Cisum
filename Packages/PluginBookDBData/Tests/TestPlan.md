# TestPlan — PluginBookDBData

## 包概述

有声书数据库数据层：书籍、章节与收听统计的读取能力。

公开类型:
- `BookDBDataPlugin`

### README 中的测试说明（摘自 `README.md`）

- **Test files:**
  - `Tests/BookDatabaseProviderTests.swift` — a `@Suite(.serialized)` suite using a
    `BookTestStorageProvider` fake storage and an event recorder.
  - `Tests/BookDBDataPluginTests.swift` — lightweight metadata assertions.
- **Key scenarios tested:**
  - Unavailable storage: empty reads, `nil` cover/state, writes throw
    `BookPluginError`, and `shutdown()` removes the storage observer.
  - Happy path: initial sync, `syncImportedItems`, cover/state reads, saving and
    reading playback state, and a storage-root switch that invalidates the repo and
    serves the new disk's books.
  - Typed event delivery: database and storage changes reach observers, and cancelling
    an observer stops further delivery.
  - Plugin lifecycle: no provider is registered until storage is available; when
    storage is available the provider is registered on boot, removed on disable,
    re-registered on enable, and removed on shutdown.
  - Failure isolation: a duplicate-registration failure leaves the pre-existing
    provider in place and does not leak observers.
  - Metadata: `order == 11`, `category == .feature`,
    `iconName == "externaldrive.badge.timemachine"`.
- **Running tests:**
  ```bash
  cd /Users/angel/Code/Coffic/Cisum/Packages/PluginBookDBData
  swift test
  ```

## 测试用例清单

下表由 `Tests/` 下的真实 `@Test` 声明自动生成，方法名与代码一一对应。

| ID | 类别 | 描述 | 优先级 | 状态 | 测试文件 | 测试方法 |
|----|------|------|--------|------|----------|----------|
| 1 | 插件 | Book d b data plugin metadata describes data layer | P0 | ✅ 已覆盖 | `BookDBDataPluginTests.swift` | `bookDBDataPluginMetadataDescribesDataLayer` |
| 2 | 行为 | Unavailable storage returns empty reads and rejects writes | P1 | ✅ 已覆盖 | `BookDatabaseProviderTests.swift` | `unavailableStorageReturnsEmptyReadsAndRejectsWrites` |
| 3 | 状态 | Library sync playback state and storage changes use current repository | P0 | ✅ 已覆盖 | `BookDatabaseProviderTests.swift` | `librarySyncPlaybackStateAndStorageChangesUseCurrentRepository` |
| 4 | 行为 | Provider publishes typed database and storage events and cancels cleanly | P1 | ✅ 已覆盖 | `BookDatabaseProviderTests.swift` | `providerPublishesTypedDatabaseAndStorageEventsAndCancelsCleanly` |
| 5 | 插件 | Plugin lifecycle skips registration until storage is available | P0 | ✅ 已覆盖 | `BookDatabaseProviderTests.swift` | `pluginLifecycleSkipsRegistrationUntilStorageIsAvailable` |
| 6 | 插件 | Plugin lifecycle registers and removes provider when storage is available | P0 | ✅ 已覆盖 | `BookDatabaseProviderTests.swift` | `pluginLifecycleRegistersAndRemovesProviderWhenStorageIsAvailable` |
| 7 | 行为 | Failed provider registration does not steal or leak existing provider | P1 | ✅ 已覆盖 | `BookDatabaseProviderTests.swift` | `failedProviderRegistrationDoesNotStealOrLeakExistingProvider` |

## 覆盖率统计

- P0: 4 / 4 ✅
- P1: 3 / 3 ✅
- P2: 0 / 0

**总计: 7 / 7**（本包 `Tests/` 中已声明的 `@Test` 全部登记）

## 测试文件

- `BookDBDataPluginTests.swift` — 1 条用例
- `BookDatabaseProviderTests.swift` — 6 条用例

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
cd Packages/PluginBookDBData
swift test
```

## 维护规则

1. **新增公开 API** → 先在 TestPlan 登记测试用例,再写实现
2. **Bug 修复** → 追加回归用例,标注触发条件
3. **删除用例** → 在 commit message 说明理由
4. **状态同步** → 实现后更新 TestPlan,标记 ✅ 并填写测试方法名
