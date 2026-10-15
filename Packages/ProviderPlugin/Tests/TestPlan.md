# TestPlan — ProviderPlugin

## 包概述

ProviderPlugin 拥有 Cisum 的插件贡献契约与注册表。插件在 `onBoot`/`onEnable` 通过 `PluginContributionProviding` 按 owner(插件 id)登记 UI 贡献,`onShutdown`/`onDisable` 时撤回;宿主 UI 通过 `PluginProviding` 查询聚合结果。聚合实现为 `PluginContributionService`。

核心组件:
- `PluginProviding` - 聚合查询能力协议(`@MainActor` + `ObservableObject`)
- `PluginContributionProviding` - 贡献登记协议(按 owner 登记/撤回)
- `PluginContributionService` - 注册表 + 聚合 Provider 实现
- `PluginProvidingEvent` - 事件枚举(`pluginsChanged` / `contributionsChanged`)
- `PluginProvidingObserverHandle` / `NoopPluginProvidingObserverHandle`
- 扩展: `EventObserverHandle` 遵循 `PluginProvidingObserverHandle`

## 公开 API(摘要)

登记:`addRootView` / `addGuideView` / `addStateView` / `addPosterView` / `addTabView` / `addSettingView` / `addToolBarButtons` / `addThemeContributions` / `addHeroView` / `addRightAlbumView` / `addControlButtonsView` / `addProgressView`;撤回:`remove(owner:)`;失效:`invalidateCaches()`。
查询:`allPlugins` / `getStatusViews` / `getStateViews` / `getPosterViews` / `getGuideView` / `getSettingViews` / `getTabViews(reason:demoMode:)` / `wrapWithCurrentRoot` / `getToolBarButtons` / `getThemeContributions` / `getHeroView` / `getRightAlbumView` / `getControlButtonsView` / `getProgressView` / `addObserver`。

## 测试用例清单

> ⚠️ 现状:`Tests/` 下两个文件(`ProviderPluginExportsTests.swift`、`PluginContributionServiceTests.swift`)仅含 import 与一个未使用的替身声明,**当前无任何 `@Test` 用例**。下表为待补齐的覆盖地图。

| ID | 类别 | 描述 | 操作步骤 | 预期结果 | 优先级 | 状态 | 测试方法 |
|----|------|------|----------|----------|------|------|----------|
| 1 | 聚合 | 仅返回**已启用**插件的贡献 | 登记后禁用 owner 再查询 | 被禁用插件贡献不出现在结果 | P0 | ❌ 缺失 | - |
| 2 | 聚合 | state/poster/setting/toolbar 按插件 `order` 稳定排序 | 多插件乱序登记 | 输出按 `pluginOrder` 升序 | P0 | ❌ 缺失 | - |
| 3 | 聚合 | 主题贡献按 id 去重并按插件 order 重写 `sortKey` | 重复 id + 多插件 | 去重且 `ThemeSortKey` 正确 | P0 | ❌ 缺失 | - |
| 4 | 单槽位 | hero/rightAlbum/controlButtons/progress/guide 取首个启用插件 | 多插件登记单槽位贡献 | 返回启用顺序中首个 | P1 | ❌ 缺失 | - |
| 5 | 撤回 | `remove(owner:)` 清除该插件全部贡献并失效缓存 | 登记后 remove | 相关查询变空,缓存失效 | P0 | ❌ 缺失 | - |
| 6 | 缓存 | 登记/撤回触发 `invalidateCaches`,聚合结果被重算 | 缓存后再次登记 | 新贡献被纳入 | P1 | ❌ 缺失 | - |
| 7 | 包裹 | `wrapWithCurrentRoot` 依启用顺序链式包裹,wrapper 返回 nil 时跳过 | 多层 wrapper | 包裹顺序与结果正确 | P1 | ❌ 缺失 | - |
| 8 | 事件 | `invalidateCaches` 广播 `contributionsChanged` | 注册观察者后失效 | 收到 `.contributionsChanged` | P1 | ❌ 缺失 | - |
| 9 | 观察者 | 协议默认 `addObserver` 返回 NoopHandle 且可重复 cancel | 替身调用 | 返回 NoopHandle,不崩溃 | P0 | ❌ 缺失 | - |
| 10 | 导出 | 模块公开符号可被下游 import(Exports 契约) | 跨模块引用 | 编译通过 | P2 | ❌ 缺失 | - |

## 覆盖率统计

- P0: 已覆盖 0 / 5
- P1: 已覆盖 0 / 4
- P2: 已覆盖 0 / 1
- **合计: 0 / 10** —— 本包尚无有效测试,建议优先补齐 TC-01/02/03/05/09

## 优先级说明

- **P0**: 启用过滤、聚合排序、主题去重重写、撤回清理、默认观察者兜底
- **P1**: 单槽位取首个、缓存失效、根包裹链、事件广播
- **P2**: 模块导出契约

## 跨平台说明

- `@MainActor` 约束要求主线程;聚合逻辑为纯 Swift,iOS 17+ / macOS 14+ 一致

## 测试执行

```bash
cd Packages/ProviderPlugin
swift test
```

## 维护规则

1. **新增公开 API** → 先在 TestPlan 登记测试用例,再写实现
2. **Bug 修复** → 追加回归用例,标注触发条件
3. **删除用例** → 在 commit message 说明理由
4. **状态同步** → 实现后更新 TestPlan,标记 ✅ 并填写测试方法名
