# TestPlan — PluginSettingGeneral

## 包概述

通用设置页：应用级设置项装配。

公开类型:
- `SettingGeneralPlugin`

### README 中的测试说明（摘自 `README.md`）

- **Test files:**
  - `Tests/GeneralSettingsTests.swift`.
- **Key scenarios tested:**
  - ViewModel defaults to no manuals and preserves injected entries in order.
  - Plugin registers its own About/Manual docs, `addSettingView()` returns `nil`, and the navigation item has id `"general"`, title `"General"`, order matching `plugin.order`.
  - Registration is safe when no `DocsViewProviding` exists.
- **Running tests:**
  ```bash
  cd /Users/angel/Code/Coffic/Cisum/Packages/PluginSettingGeneral
  swift test
  ```
- Tests cover docs registration and the navigation item; the manual browser's UI is not exercised.

## 测试用例清单

下表由 `Tests/` 下的真实 `@Test` 声明自动生成，方法名与代码一一对应。

| ID | 类别 | 描述 | 优先级 | 状态 | 测试文件 | 测试方法 |
|----|------|------|--------|------|----------|----------|
| 1 | 视图模型 | View model defaults to no manuals and preserves injected entries | P2 | ✅ 已覆盖 | `GeneralSettingsTests.swift` | `viewModelDefaultsToNoManualsAndPreservesInjectedEntries` |
| 2 | 插件 | Plugin registers its docs and contributes general entry | P0 | ✅ 已覆盖 | `GeneralSettingsTests.swift` | `pluginRegistersItsDocsAndContributesGeneralEntry` |
| 3 | 插件 | Plugin does not contribute entry without settings provider | P1 | ✅ 已覆盖 | `GeneralSettingsTests.swift` | `pluginDoesNotContributeEntryWithoutSettingsProvider` |
| 4 | 插件 | Plugin registration is safe without docs provider | P1 | ✅ 已覆盖 | `GeneralSettingsTests.swift` | `pluginRegistrationIsSafeWithoutDocsProvider` |

## 覆盖率统计

- P0: 1 / 1 ✅
- P1: 2 / 2 ✅
- P2: 1 / 1 ✅

**总计: 4 / 4**（本包 `Tests/` 中已声明的 `@Test` 全部登记）

## 测试文件

- `GeneralSettingsTests.swift` — 4 条用例

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
cd Packages/PluginSettingGeneral
swift test
```

## 维护规则

1. **新增公开 API** → 先在 TestPlan 登记测试用例,再写实现
2. **Bug 修复** → 追加回归用例,标注触发条件
3. **删除用例** → 在 commit message 说明理由
4. **状态同步** → 实现后更新 TestPlan,标记 ✅ 并填写测试方法名
