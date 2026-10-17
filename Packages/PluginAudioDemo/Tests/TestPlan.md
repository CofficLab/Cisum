# TestPlan — PluginAudioDemo

## 包概述

音乐演示模式：用于无真实媒体库时的演示数据源。

公开类型:
- `AudioDemoPlugin`
- `AudioDemoPluginInfo`
- `AudioItemDemo`
- `AudioListDemo`

### README 中的测试说明（摘自 `README.md`）

- **Test files**: `Tests/AudioDemoPluginTests.swift`.
- **Key scenarios tested**:
  - Plugin metadata is stable: `iconName == "externaldrive"`, and title/description/tabLabel are non-empty.
  - Demo content availability: `AudioListDemo.demoAudioFiles.count == 20` and `AudioItemDemo.iconNames.count == 8`.
  - `AudioItemDemo.stableIndex(for:count:)` handles extreme hashes safely — returns a valid index for `Int.min`, wraps negatives (e.g. `-1 → 7`), handles in-range values (e.g. `9 → 1`), and degrades to `0` when the icon count is zero.
- **Running tests**:
  ```bash
  cd /Users/angel/Code/Coffic/Cisum/Packages/PluginAudioDemo
  swift test
  ```

## 测试用例清单

下表由 `Tests/` 下的真实 `@Test` 声明自动生成，方法名与代码一一对应。

| ID | 类别 | 描述 | 优先级 | 状态 | 测试文件 | 测试方法 |
|----|------|------|--------|------|----------|----------|
| 1 | 插件 | Plugin metadata is stable | P0 | ✅ 已覆盖 | `AudioDemoPluginTests.swift` | `pluginMetadataIsStable` |
| 2 | 行为 | Demo audio files are available | P0 | ✅ 已覆盖 | `AudioDemoPluginTests.swift` | `demoAudioFilesAreAvailable` |
| 3 | 行为 | Audio demo stable index handles extreme hashes | P0 | ✅ 已覆盖 | `AudioDemoPluginTests.swift` | `audioDemoStableIndexHandlesExtremeHashes` |
| 4 | 元数据 | AudioDemoPlugin exposes stable identity and metadata | P1 | ✅ 已覆盖 | `AudioDemoPluginTests.swift` | `audioDemoPluginExposesStableIdentityAndMetadata` |

## 覆盖率统计

- P0: 3 / 3 ✅
- P1: 1 / 1 ✅
- P2: 0 / 0

**总计: 4 / 4**（本包 `Tests/` 中已声明的 `@Test` 全部登记）

## 测试文件

- `AudioDemoPluginTests.swift` — 4 条用例

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
cd Packages/PluginAudioDemo
swift test
```

## 维护规则

1. **新增公开 API** → 先在 TestPlan 登记测试用例,再写实现
2. **Bug 修复** → 追加回归用例,标注触发条件
3. **删除用例** → 在 commit message 说明理由
4. **状态同步** → 实现后更新 TestPlan,标记 ✅ 并填写测试方法名
