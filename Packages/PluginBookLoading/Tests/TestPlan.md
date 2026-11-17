# TestPlan — PluginBookLoading

## 包概述

有声书 iCloud 载入横幅：在有声书场景下，用「名称 + 进度 + 取消/重试」的横幅
替代裸百分比，并只在 `SceneProviding` 报告有声书场景时激活控制区插槽。

核心组件:
- `BookLoadingPlugin` — `AsyncSuperPlugin`，装配能力、ViewModel、Observer 与插槽
- `BookLoadingPlaybackCapability(Adapter)` — 收窄的播放能力（状态 / 资源 / 取消 / 重试）
- `BookLoadingSceneCapability(Adapter)` — 收窄的只读场景能力
- `BookLoadingViewModel` — 场景 + 播放状态 → `BannerMode`
- `BookLoadingObserver` — 初始快照同步与后续事件转发
- `BookLoadingBanner` — 下载态 / 失败态视图与无障碍标识

## 测试用例清单

| ID | 类别 | 描述 | 优先级 | 状态 | 测试文件 | 测试方法 |
|----|------|------|--------|------|----------|----------|
| 1 | 模型 | 下载百分比夹取到 0…1，0 渲染不确定态 | P0 | ✅ 已覆盖 | `BookLoadingTests.swift` | `downloadingModeCarriesClampedProgress` |
| 2 | 模型 | 只有 iCloud 载入失败才显示失败态 | P0 | ✅ 已覆盖 | `BookLoadingTests.swift` | `onlyICloudFailureBecomesVisible` |
| 3 | 模型 | 横幅仅在有声书场景可见 | P0 | ✅ 已覆盖 | `BookLoadingTests.swift` | `sceneGatesBannerToAudiobooks` |
| 4 | 模型 | 标题取文件名 stem，无资源时为空 | P1 | ✅ 已覆盖 | `BookLoadingTests.swift` | `subjectUsesFileStem` |
| 5 | 视图模型 | 场景与播放事件驱动模式切换，离开场景不取消载入 | P0 | ✅ 已覆盖 | `BookLoadingTests.swift` | `viewModelFollowsSceneAndPlaybackChanges` |
| 6 | 视图模型 | 取消立即转发，重试异步转发到播放能力 | P0 | ✅ 已覆盖 | `BookLoadingTests.swift` | `viewModelForwardsCancelAndRetry` |
| 7 | 视图 | 隐藏/有进度/不确定/失败四种模式均可构建 body | P1 | ✅ 已覆盖 | `BookLoadingTests.swift` | `bannerBodyBuildsForEveryMode` |
| 8 | 插件 | 插槽激活态跟随模式，禁用/启用/关闭正确装卸监听 | P0 | ✅ 已覆盖 | `BookLoadingTests.swift` | `pluginActivatesSlotOnlyForAudiobookLoading` |
| 9 | 插件 | 无控制区 Provider 时静默休眠且可安全关闭 | P1 | ✅ 已覆盖 | `BookLoadingTests.swift` | `pluginStaysDormantWithoutControlProvider` |
| 10 | 插件 | 注册阶段注入「关于」与「说明书」文档条目，且两者视图不同 | P1 | ✅ 已覆盖 | `BookLoadingTests.swift` | `onRegisterPublishesAboutAndManualDocsEntries` |

## 覆盖率统计

- P0: 5 / 5 ✅
- P1: 5 / 5 ✅
- P2: 0 / 0

**总计: 10 / 10**（本包 `Tests/` 中已声明的 `@Test` 全部登记）

## 优先级说明

- **P0**: 场景门控、模式推导、插槽激活与生命周期、取消/重试转发
- **P1**: 命名、视图可构建性、Provider 缺席时的退化
- **P2**: 真实窗口内的布局与动画（未在单测覆盖）

## 跨平台说明

- 单测以 macOS 主机 `swift test` 为基准；视图层像素/布局未在本包断言
- 横幅高度由 `ControlView` 的插槽高度决定，切换载入态不改变控制区高度

## 测试执行

```bash
cd Packages/PluginBookLoading
swift test
```

## 维护规则

1. **新增公开 API** → 先在 TestPlan 登记测试用例，再写实现
2. **Bug 修复** → 追加回归用例，标注触发条件
3. **删除用例** → 在 commit message 说明理由
4. **状态同步** → 实现后更新 TestPlan，标记 ✅ 并填写测试方法名
