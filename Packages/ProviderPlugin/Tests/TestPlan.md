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

> `PluginContributionServiceTests.swift` 使用真实 Kernel 与服务验证贡献行为；`ProviderPluginExportsTests.swift` 使用普通 import 验证公开契约与默认观察者。共 13 个 `@Test`，映射到下表 11 项场景。
>
> 统计仅表示本表场景的测试覆盖，不是源码行/分支覆盖率。AnyView 内容与顺序使用 `ImageRenderer` 渲染纯色色块并比较像素，不依赖私有反射，不保存截图，也不修改用户偏好。

| ID | 类别 | 描述 | 操作步骤 | 预期结果 | 优先级 | 状态 | 测试方法 |
|----|------|------|----------|----------|------|------|----------|
| 1 | 聚合 | 仅返回已启用插件的贡献 | 登记多种 owner，禁用后显式失效缓存，再重新启用 | 隐藏未注册/禁用 owner，重新启用后恢复 | P0 | ✅ 已覆盖 | `aggregationsExcludeDisabledAndUnknownOwners` |
| 2 | 聚合 | state/poster/setting/toolbar 按数字 order 排序 | 以与 order 相反的 ID 顺序注册，连续查询两次 | 列表排序正确，插件内部按钮顺序保留 | P0 | ✅ 已覆盖 | `listContributionsSortByPluginOrderAndPreserveButtonOrder` |
| 3 | 聚合 | 主题按 id 去重并重写 sortKey | 同 owner 和跨 owner 重复 id，撤回首个 owner | 首个主题获胜，重写 order/id，撤回后回落后续主题 | P0 | ✅ 已覆盖 | `themesDeduplicateByIDAndRewriteSortKeys` |
| 4 | 单槽位 | 五类单槽位取首个启用插件 | 分批启动，使实际启动顺序与 order 不同；逐个撤回 | 返回首个启动 owner，之后回落，最终 nil | P1 | ✅ 已覆盖 | `singleSlotsChooseFirstStartedOwnerAndFallBackAfterRemoval` |
| 5 | 撤回 | remove 清除该 owner 全部贡献并失效缓存 | 预热全部缓存，重复撤回，再撤回未知 owner | 保留其他 owner，已移除根包裹闭包不再执行，不注销插件 | P0 | ✅ 已覆盖 | `removeClearsEveryContributionWithoutAffectingOtherOwners` |
| 6 | 缓存 | 登记和替换使所有列表缓存失效 | 先缓存空结果，再登记和覆盖同一 owner | 新值可查询，无重复项；主题和按钮同步替换 | P1 | ✅ 已覆盖 | `replacingOwnerContributionsInvalidatesAllListCaches` |
| 7 | 包裹 | 根视图链式包裹，nil 结果保留前一内容 | 三层 wrapper，中间返回 nil；登记未知 owner | 调用顺序与最终像素正确，未知 owner 不执行；无 wrapper 保留原内容 | P1 | ✅ 已覆盖 | `rootWrappersComposeInStartupOrderAndSkipNilResults` |
| 8 | 事件 | 缓存失效通知语义观察者和 Combine 订阅者 | 显式失效、登记、撤回；取消一个观察者后再登记 | 回调读到更新后状态，取消幂等且不影响其他观察者；12 种登记均广播 | P1 | ✅ 已覆盖 | `invalidationNotifiesBothObservationChannelsAndCancellationStopsDelivery` / `eachContributionRegistrationBroadcastsInvalidation` |
| 9 | 观察者 | 默认观察者和显式 NoopHandle 可重复取消 | 通过协议替身订阅并重复 cancel | 返回 NoopHandle，不投递事件，不崩溃 | P0 | ✅ 已覆盖 | `defaultObserverUsesNoopFallback` / `explicitNoopHandleSupportsRepeatedCancellation` |
| 10 | 导出 | 下游可用公开符号注册服务 | 普通 import，以两个 Provider 协议注册并解析 | 两个协议解析到同一个服务，初始查询为空 | P2 | ✅ 已覆盖 | `publicServiceRegistersUnderBothProviderContracts` |
| 11 | 标签页 | 参数透传、nil 过滤且不缓存结果 | 同一贡献分别以普通/演示模式查询 | reason/demoMode 每次传入，nil 项被过滤，未注册 owner 不执行 | P1 | ✅ 已覆盖 | `tabContributionsReceiveArgumentsAndAreNotCached` |

## 覆盖率统计

- P0: 已覆盖 5 / 5
- P1: 已覆盖 5 / 5
- P2: 已覆盖 1 / 1
- **合计: 11 / 11 项场景，对应 13 个测试方法**

## 优先级说明

- **P0**: 启用过滤、聚合排序、主题去重重写、撤回清理、默认观察者兜底
- **P1**: 单槽位取首个、缓存失效、根包裹链、事件广播
- **P2**: 模块导出契约

## 跨平台说明

- `@MainActor` 约束要求主线程；契约支持 iOS 17+ / macOS 14+。
- 当前已在 macOS 上执行；iOS 尚未实跑。渲染检查仅使用 SwiftUI 的纯色色块，不依赖窗口、字体或主题全局状态。
- Kernel 未注入持久化 stateStore，启用/禁用仅改变测试实例的内存状态。

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
