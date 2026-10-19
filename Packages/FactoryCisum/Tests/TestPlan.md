# TestPlan — FactoryCisum

## 包概述

组合根：创建内核、注册基础设施 Provider、实例化内置插件列表、装配主窗口与设置窗口，并串联 App 命令。

公开类型:
- `CisumAppCommands`
- `AppBootstrap`
- `FactoryCisumConfiguration`
- `CisumBuilder`
- `PluginFactory`
- `DefaultPluginFactory`
- `SelectedPluginFactory`
- `CloudService`
- `DeviceService`
- `SettingsWindowHost`
- `WindowMain`
- `ContentViewVisibilityCoordinator` - 内容区显隐的协调器（`ContentViewVisibilityProviding` 的实现）

### README 中的测试说明（摘自 `README.md`）

- **Test files**:
  - `Tests/FactoryCisumTests.swift` — Swift Testing suite (`@MainActor struct`).
- **Key scenarios tested**:
  - `defaultPluginFactoryProducesUniquePluginIDs` — the default factory produces more than 40 plugins with no duplicate ids.
  - `selectedPluginFactoryPreservesBaseOrderAndFiltersByID` — filtering by an allowed id set preserves base order and drops the rest.
  - `mainViewAssemblyFallsBackWhenRootProviderIsMissing` — `assembleMainView` does not crash on an empty kernel.
  - `mainViewAssemblyInjectsControlAndContentProviders` — after registering root/control/content providers, assembly wires the control and content views and leaves demo mode off / tabs empty.
- **Running tests**:
  ```bash
  cd /Users/angel/Code/Coffic/Cisum/Packages/FactoryCisum
  swift test
  ```

## 测试用例清单

下表由 `Tests/` 下的真实 `@Test` 声明自动生成，方法名与代码一一对应。

| ID | 类别 | 描述 | 优先级 | 状态 | 测试文件 | 测试方法 |
|----|------|------|--------|------|----------|----------|
| 1 | 工厂 | Default plugin factory produces unique plugin i ds | P0 | ✅ 已覆盖 | `FactoryCisumTests.swift` | `defaultPluginFactoryProducesUniquePluginIDs` |
| 2 | 工厂 | Selected plugin factory preserves base order and filters by i d | P0 | ✅ 已覆盖 | `FactoryCisumTests.swift` | `selectedPluginFactoryPreservesBaseOrderAndFiltersByID` |
| 3 | 行为 | Main view assembly falls back when root provider is missing | P1 | ✅ 已覆盖 | `FactoryCisumTests.swift` | `mainViewAssemblyFallsBackWhenRootProviderIsMissing` |
| 4 | 行为 | Main view assembly injects control and content providers | P2 | ✅ 已覆盖 | `FactoryCisumTests.swift` | `mainViewAssemblyInjectsControlAndContentProviders` |
| 5 | 插件 | Kernel loads theme contributions after plugin startup | P0 | ✅ 已覆盖 | `FactoryCisumTests.swift` | `kernelLoadsThemeContributionsAfterPluginStartup` |
| 6 | 行为 | Kernel exposes cloud download progress provider | P0 | ✅ 已覆盖 | `FactoryCisumTests.swift` | `kernelExposesCloudDownloadProgressProvider` |
| 7 | 行为 | Kernel exposes shared theme settings navigation item | P0 | ✅ 已覆盖 | `FactoryCisumTests.swift` | `kernelExposesSharedThemeSettingsNavigationItem` |

### 内容区显隐协调回归（ID 8–17，来源 `Tests/ContentViewVisibilityCoordinatorTests.swift`）

> 背景：iOS 上「打开只剩播放控制区、没有音乐库」的另一条路径是**显隐真源割裂**。
> 落盘偏好（`AppStateProviding`）与内存态（`RootViewProviding`）只在启动时单向连通，
> 于是出现：旧缺陷写坏的落盘值让每次冷启动都空播放器；「更多」按钮只改内存态导致
> 用户显式选择重启后丢失；两者分叉时按钮按落盘值取反 → 点了没反应。
> 协调器把 `AppStateProviding` 确立为唯一真源，下表逐条锁定。

| ID | 类别 | 描述 | 优先级 | 状态 | 测试文件 | 测试方法 |
|----|------|------|--------|------|----------|----------|
| 8 | 回归 | 启动时把落盘态投影到根视图（隐藏） | P0 | ✅ 已覆盖 | `ContentViewVisibilityCoordinatorTests.swift` | `startProjectsPersistedVisibilityOntoRoot` |
| 9 | 回归 | 启动时把落盘态投影到根视图（可见） | P0 | ✅ 已覆盖 | `ContentViewVisibilityCoordinatorTests.swift` | `startProjectsVisibleStateOntoRoot` |
| 10 | 回归 | 真源变更必须投影到根视图 | P0 | ✅ 已覆盖 | `ContentViewVisibilityCoordinatorTests.swift` | `appStateChangeIsProjectedOntoRoot` |
| 11 | 行为 | 停止同步后不再投影 | P1 | ✅ 已覆盖 | `ContentViewVisibilityCoordinatorTests.swift` | `stopStopsProjection` |
| 12 | 回归 | 「更多」收起内容区必须落盘 | P0 | ✅ 已覆盖 | `ContentViewVisibilityCoordinatorTests.swift` | `toggleHidesContentAndPersistsTheChoice` |
| 13 | 回归 | 「更多」展开内容区必须落盘为可见 | P0 | ✅ 已覆盖 | `ContentViewVisibilityCoordinatorTests.swift` | `toggleShowsContentAndPersistsTheChoice` |
| 14 | 行为 | 显式设置同时落盘并立即生效 | P1 | ✅ 已覆盖 | `ContentViewVisibilityCoordinatorTests.swift` | `setVisiblePersistsExplicitChoice` |
| 15 | 回归 | 内存态被外部收起时「更多」仍能带回内容区 | P0 | ✅ 已覆盖 | `ContentViewVisibilityCoordinatorTests.swift` | `toggleRestoresContentHiddenOutsideAppState` |
| 16 | 回归 | 落盘态隐藏时「更多」按实际可见性收起 | P0 | ✅ 已覆盖 | `ContentViewVisibilityCoordinatorTests.swift` | `toggleHidesContentWhenPersistedStateIsHidden` |
| 17 | 集成 | 内核装配后必须能解析到显隐服务 | P0 | ✅ 已覆盖 | `ContentViewVisibilityCoordinatorTests.swift` | `kernelRegistersContentVisibilityService` |

## 覆盖率统计

- P0: 13 / 13 ✅
- P1: 2 / 2 ✅
- P2: 1 / 1 ✅

**总计: 16 / 16**（本包 `Tests/` 中已声明的 `@Test` 全部登记）

## 测试文件

- `FactoryCisumTests.swift` — 7 条用例
- `ContentViewVisibilityCoordinatorTests.swift` — 10 条用例

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
cd Packages/FactoryCisum
swift test
```

## 维护规则

1. **新增公开 API** → 先在 TestPlan 登记测试用例,再写实现
2. **Bug 修复** → 追加回归用例,标注触发条件
3. **删除用例** → 在 commit message 说明理由
4. **状态同步** → 实现后更新 TestPlan,标记 ✅ 并填写测试方法名
