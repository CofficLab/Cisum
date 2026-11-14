# TestPlan — PluginBookScene

## 包概述

有声书场景插件：把书籍栈注册进场景系统。

公开类型:
- `BookScenePlugin`
- `BookScenePluginInfo`
- `BookPosterView`

### README 中的测试说明（摘自 `README.md`）

- **Test files:**
  - `Tests/BookScenePluginCoverageTests.swift` — kernel-lifecycle tests using a
    `SceneProbe`.
  - `Tests/BookScenePluginTests.swift` — metadata assertions.
- **Key scenarios tested:**
  - `onRegister` with no docs provider registered does not crash.
  - `onReady` without a scene provider keeps a safe fallback (poster still returned).
  - With a scene provider registered, `onReady` installs the scene action and tapping
    the poster calls `setCurrentScene(.audiobooks)` (incrementing the probe's
    `setSceneCount`).
  - `onEnable` reinstalls the action after `onDisable`; `onShutdown` clears it while
    still returning a poster view.
  - Metadata: name/description/icon/order match `BookScenePluginInfo`
    (`iconName == "book.closed"`, `order == 0`).
- **Running tests:**
  ```bash
  cd /Users/angel/Code/Coffic/Cisum/Packages/PluginBookScene
  swift test
  ```

## 测试用例清单

下表由 `Tests/` 下的真实 `@Test` 声明自动生成，方法名与代码一一对应。

| ID | 类别 | 描述 | 优先级 | 状态 | 测试文件 | 测试方法 |
|----|------|------|--------|------|----------|----------|
| 1 | 行为 | On register with no docs is safe | P0 | ✅ 已覆盖 | `BookScenePluginCoverageTests.swift` | `onRegisterWithNoDocsIsSafe` |
| 2 | 行为 | On ready without scene provider keeps fallback | P1 | ✅ 已覆盖 | `BookScenePluginCoverageTests.swift` | `onReadyWithoutSceneProviderKeepsFallback` |
| 3 | 行为 | On ready installs scene action when provider registered | P0 | ✅ 已覆盖 | `BookScenePluginCoverageTests.swift` | `onReadyInstallsSceneActionWhenProviderRegistered` |
| 4 | 行为 | On enable reinstalls after disable | P0 | ✅ 已覆盖 | `BookScenePluginCoverageTests.swift` | `onEnableReinstallsAfterDisable` |
| 5 | 行为 | On shutdown clears scene action | P0 | ✅ 已覆盖 | `BookScenePluginCoverageTests.swift` | `onShutdownClearsSceneAction` |
| 6 | 元数据 | Metadata exports registration info | P0 | ✅ 已覆盖 | `BookScenePluginCoverageTests.swift` | `metadataExportsRegistrationInfo` |
| 7 | 插件 | Plugin info exports registration metadata | P0 | ✅ 已覆盖 | `BookScenePluginTests.swift` | `pluginInfoExportsRegistrationMetadata` |

## 覆盖率统计

- P0: 6 / 6 ✅
- P1: 1 / 1 ✅
- P2: 0 / 0

**总计: 7 / 7**（本包 `Tests/` 中已声明的 `@Test` 全部登记）

## 测试文件

- `BookScenePluginCoverageTests.swift` — 6 条用例
- `BookScenePluginTests.swift` — 1 条用例

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
cd Packages/PluginBookScene
swift test
```

## 维护规则

1. **新增公开 API** → 先在 TestPlan 登记测试用例,再写实现
2. **Bug 修复** → 追加回归用例,标注触发条件
3. **删除用例** → 在 commit message 说明理由
4. **状态同步** → 实现后更新 TestPlan,标记 ✅ 并填写测试方法名
