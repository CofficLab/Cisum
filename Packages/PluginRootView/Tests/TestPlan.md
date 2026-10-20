# TestPlan — PluginRootView

## 包概述

PluginRootView 通过插件生命周期装配 Cisum 的根视图：`RootViewPlugin` 注册
`RootViewProvider`，后者复用 LumiProviders 的共享根视图状态，配合 Cisum 自己的
`RootLayoutView` 播放布局。根布局负责：控制区/内容区/状态区的纵向排布、桌面端
窗口尺寸自适应、以及由播放/场景/仓库事件驱动的播放器收起态。

核心组件:
- `RootViewPlugin` - 插件（注册 RootView provider、贡献布局）
- `RootViewProvider` - 复用 `DefaultRootViewProviding` 的根视图状态
- `RootLayoutView` - 根布局视图（控制区 / 内容区 / 状态区、几何变化处理）
- `RootOverlayHostView` - 观察 overlay 贡献并重建包装链
- `RootLayoutViewModel` - 贡献区与播放器呈现态（事件直达）
- `RootContentVisibility` - 几何变化后内容区是否收起的纯判定（可注入平台）

## 公开 API

### RootViewPlugin / RootViewProvider
- `makeRootView() -> AnyView`（返回 `RootOverlayHostView`）
- 插件 `onBoot` / `onReady` 阶段注册 `RootViewProviding`

### RootContentVisibility（internal，供根布局消费）
- `static var hostIsMacOS: Bool`（编译期平台常量）
- `static func shouldHideContentView(isMacOS:newHeight:dropThreshold:) -> Bool`

## 测试用例清单

| ID | 类别 | 描述 | 前置条件 | 操作步骤 | 预期结果 | 优先级 | 状态 | 测试方法 |
|----|------|------|----------|----------|----------|------|------|----------|
| 1 | 回归 | iOS 上极短瞬时高度（0 / 100 / 阈值边界）不得收起内容区 | 注入 `isMacOS: false` | 对多档小高度求判定 | 均为 `false`（不隐藏） | P0 | ✅ 已覆盖 | `iosNeverHidesContentViewOnShortGeometry` |
| 2 | 回归 | iOS 正常屏幕高度保持内容区可见 | 注入 `isMacOS: false` | 844pt 求判定 | `false` | P0 | ✅ 已覆盖 | `iosKeepsContentViewAtRegularHeights` |
| 3 | 行为 | macOS 高度 ≤ 阈值时收起内容区（保留桌面响应式行为） | 注入 `isMacOS: true` | 200 / 270pt 求判定 | 均为 `true` | P1 | ✅ 已覆盖 | `macOSHidesContentViewAtOrBelowThreshold` |
| 4 | 行为 | macOS 高度 > 阈值时保持内容区可见 | 注入 `isMacOS: true` | 271 / 900pt 求判定 | 均为 `false` | P1 | ✅ 已覆盖 | `macOSKeepsContentViewAboveThreshold` |
| 5 | 视图 | `RootLayoutView` 在真实窗口/safe-area 过渡下的端到端显隐 | 需宿主窗口与实机 | 启动、旋转、拉窗 | 内容区不被瞬时小高度误收起 | P1 | ❌ 缺失 | - |
| 6 | 插件 | `RootViewPlugin` 生命周期注册 provider、贡献布局 | 需内核与插件装配 | boot/ready/shutdown | provider 注册、贡献生效、拆除干净 | P1 | ❌ 缺失 | - |
| 7 | 视图模型 | `RootLayoutViewModel` 由播放/场景/仓库事件驱动 `isPlaybackHeroPresenting` | 需环境事件替身 | 触发 asset/scene/repo 事件 | 收起/展开判定正确 | P1 | ❌ 缺失 | - |

> 说明：本次仅针对 p4.4.3 iOS「音乐库被隐藏、只剩浮在中央的空播放器」bug 追加回归用例
> （ID 1–4，锁定 `RootContentVisibility` 的平台隔离）。ID 5–7 依赖真实窗口、内核装配或
> 事件替身，超出纯函数单测范围，标注为 ❌ 缺失而非虚假打勾。

> 内容区**显隐协调**（落盘真源 ↔ 根视图投影、用户显式切换、内存态/落盘态分歧恢复）
> 不在本包：它同时依赖 `AppStateProviding` 与 `RootViewProviding`，属于组合根职责，
> 契约在 `ProviderAppState`、实现在 `FactoryCisum`，用例见
> `Packages/FactoryCisum/Tests/ContentViewVisibilityCoordinatorTests.swift`。

## 覆盖率统计

- P0: 已覆盖 2 / 2
- P1: 已覆盖 2 / 5
- **合计: 4 / 7**（仅表示清单场景，非源码覆盖率）

## 优先级说明

- **P0**: 直接对应线上 bug 的 iOS 显隐判定
- **P1**: 桌面端既有行为保持、真实视图/插件/视图模型集成

## 跨平台说明

- 判定为纯函数，通过注入 `isMacOS` 在本机（macOS CI）同时覆盖 iOS / macOS 两条分支
- 真实 `RootLayoutView` 的端到端行为需在 iOS 模拟器/真机验证（见 ID 5）

## 测试执行

```bash
cd Packages/PluginRootView
swift test
```

## 维护规则

1. **新增公开 API** → 先在 TestPlan 登记测试用例，再写实现
2. **Bug 修复** → 追加回归用例，标注触发条件（本包 ID 1–4 即 p4.4.3 回归）
3. **删除用例** → 在 commit message 说明理由
4. **状态同步** → 实现后更新 TestPlan，标记 ✅ 并填写测试方法名
