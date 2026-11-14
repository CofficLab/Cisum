# TestPlan — PluginBookLike

## 包概述

有声书收藏：生产 `BookLikeProviding` 并向消费方暴露收藏状态。

公开类型:
- `BookLikePlugin`
- `BookLikePluginInfo`
- `BookLikeItem`
- `BookLikeStore`
- `BookLikeRootView`
- `BookLikeSettingsView`

### README 中的测试说明（摘自 `README.md`）

- **Test files:**
  - `Tests/BookLikePluginTests.swift` — metadata, settings item, store persistence,
    and view-model integration.
- **Key scenarios tested:**
  - Metadata: `iconName == "heart"`, `order == 6`.
  - Settings contribution: `addSettingView()` returns `nil`, navigation item has
    `id == "liked-books"` and title "Liked Books".
  - `BookLikeStore`: add/remove persistence, title-sorted listing, symlinked books
    collapsing to one entry (and unliking via the real path clearing it), distinct
    dangling symlink books staying separate, and tolerance of empty/legacy/whitespace/
    invalid stored URL strings.
  - ViewModel integration via a `PlaybackProviding` probe: `handleAppear` loads items,
    like saves are gated by scene activation and provider availability, and like-status
    changes reload the list.
- **Running tests:**
  ```bash
  cd /Users/angel/Code/Coffic/Cisum/Packages/PluginBookLike
  swift test
  ```

## 测试用例清单

下表由 `Tests/` 下的真实 `@Test` 声明自动生成，方法名与代码一一对应。

| ID | 类别 | 描述 | 优先级 | 状态 | 测试文件 | 测试方法 |
|----|------|------|--------|------|----------|----------|
| 1 | 插件 | Plugin info exports registration metadata | P0 | ✅ 已覆盖 | `BookLikePluginTests.swift` | `pluginInfoExportsRegistrationMetadata` |
| 2 | 插件 | Plugin exposes settings navigation item | P0 | ✅ 已覆盖 | `BookLikePluginTests.swift` | `pluginExposesSettingsNavigationItem` |
| 3 | 行为 | Book like settings uses localized loading text | P0 | ✅ 已覆盖 | `BookLikePluginTests.swift` | `bookLikeSettingsUsesLocalizedLoadingText` |
| 4 | 持久化 | Book like store persists real liked books | P0 | ✅ 已覆盖 | `BookLikePluginTests.swift` | `bookLikeStorePersistsRealLikedBooks` |
| 5 | 存储 | Book like store matches symlinked books | P0 | ✅ 已覆盖 | `BookLikePluginTests.swift` | `bookLikeStoreMatchesSymlinkedBooks` |
| 6 | 存储 | Book like store keeps distinct dangling symlinked books | P1 | ✅ 已覆盖 | `BookLikePluginTests.swift` | `bookLikeStoreKeepsDistinctDanglingSymlinkedBooks` |
| 7 | 存储 | Book like store ignores empty stored u r ls | P1 | ✅ 已覆盖 | `BookLikePluginTests.swift` | `bookLikeStoreIgnoresEmptyStoredURLs` |
| 8 | 行为 | Reload loads liked books | P0 | ✅ 已覆盖 | `BookLikePluginTests.swift` | `reloadLoadsLikedBooks` |
| 9 | 行为 | Like save requires active scene | P0 | ✅ 已覆盖 | `BookLikePluginTests.swift` | `likeSaveRequiresActiveScene` |
| 10 | 行为 | Activation requires playback provider | P0 | ✅ 已覆盖 | `BookLikePluginTests.swift` | `activationRequiresPlaybackProvider` |
| 11 | 行为 | Like status change reloads list | P0 | ✅ 已覆盖 | `BookLikePluginTests.swift` | `likeStatusChangeReloadsList` |

## 覆盖率统计

- P0: 9 / 9 ✅
- P1: 2 / 2 ✅
- P2: 0 / 0

**总计: 11 / 11**（本包 `Tests/` 中已声明的 `@Test` 全部登记）

## 测试文件

- `BookLikePluginTests.swift` — 11 条用例

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
cd Packages/PluginBookLike
swift test
```

## 维护规则

1. **新增公开 API** → 先在 TestPlan 登记测试用例,再写实现
2. **Bug 修复** → 追加回归用例,标注触发条件
3. **删除用例** → 在 commit message 说明理由
4. **状态同步** → 实现后更新 TestPlan,标记 ✅ 并填写测试方法名
