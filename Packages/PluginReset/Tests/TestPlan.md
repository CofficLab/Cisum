# TestPlan — PluginReset

## 包概述

重置插件：清理媒体库 / 设置等持久化状态。

公开类型:
- `ResetPluginInfo`
- `SystemPlugin`
- `ResetConfirm`
- `SystemSetting`

### README 中的测试说明（摘自 `README.md`）

- **Test files:**
  - `Tests/ResetPluginTests.swift`.
- **Key scenarios tested:**
  - `ResetPluginInfo` metadata (`iconName`, `emoji`, `order`).
  - `ResetConfirm.shouldDisableInteractiveDismiss(isResetting:)` is `false` before reset and `true` during reset.
  - Accessibility/label constants: `SystemSetting.resetStorageLocationActionLabel == "Reset Storage Location"` and `ResetConfirm.closeButtonLabel == "Close"`.
- **Running tests:**
  ```bash
  cd /Users/angel/Code/Coffic/Cisum/Packages/PluginReset
  swift test
  ```
- Tests are light: they verify metadata and pure view-policy helpers. The reset closure itself is not executed.

## 测试用例清单

下表由 `Tests/` 下的真实 `@Test` 声明自动生成，方法名与代码一一对应。

| ID | 类别 | 描述 | 优先级 | 状态 | 测试文件 | 测试方法 |
|----|------|------|--------|------|----------|----------|
| 1 | 插件 | Plugin info exports registration metadata | P0 | ✅ 已覆盖 | `ResetPluginTests.swift` | `pluginInfoExportsRegistrationMetadata` |
| 2 | 行为 | Reset sheet only allows dismiss before reset starts | P1 | ✅ 已覆盖 | `ResetPluginTests.swift` | `resetSheetOnlyAllowsDismissBeforeResetStarts` |
| 3 | 行为 | Reset icon buttons expose readable labels | P1 | ✅ 已覆盖 | `ResetPluginTests.swift` | `resetIconButtonsExposeReadableLabels` |
| 4 | 元数据 | SystemPlugin exposes stable identity and metadata | P1 | ✅ 已覆盖 | `ResetPluginTests.swift` | `systemPluginExposesStableIdentityAndMetadata` |

## 覆盖率统计

- P0: 1 / 1 ✅
- P1: 3 / 3 ✅
- P2: 0 / 0

**总计: 4 / 4**（本包 `Tests/` 中已声明的 `@Test` 全部登记）

## 测试文件

- `ResetPluginTests.swift` — 4 条用例

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
cd Packages/PluginReset
swift test
```

## 维护规则

1. **新增公开 API** → 先在 TestPlan 登记测试用例,再写实现
2. **Bug 修复** → 追加回归用例,标注触发条件
3. **删除用例** → 在 commit message 说明理由
4. **状态同步** → 实现后更新 TestPlan,标记 ✅ 并填写测试方法名
