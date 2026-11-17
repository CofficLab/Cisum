# TestPlan — PluginBookLoading

## 包概述

有声书 iCloud 载入横幅：在有声书场景下，用「名称 + 进度 + 取消/重试」的横幅
替代裸百分比，并只在 `SceneProviding` 报告有声书场景时激活控制区插槽。

核心组件:
- `BookLoadingPlugin` — `AsyncSuperPlugin`，装配能力、ViewModel、Observer 与插槽
- `BookLoadingPlaybackCapability(Adapter)` — 收窄的播放能力（状态 / 资源 / 取消 / 重试）
- `BookLoadingSceneCapability(Adapter)` — 收窄的只读场景能力
- `BookLoadingLibraryCapability(Adapter)` — 收窄的书籍库能力（书单 / 书库根 / 可播扩展名）
- `BookLoadingSubjectResolver` — 章节路径 → 书名 + 章节位置（与播放侧一致的自然排序）
- `BookLoadingViewModel` — 场景 + 播放状态 → `BannerMode`；资源切换后补全主题
- `BookLoadingObserver` — 初始快照同步与后续事件转发
- `BookLoadingBanner` — 下载态 / 失败态视图与无障碍标识

## 测试用例清单

| ID | 类别 | 描述 | 优先级 | 状态 | 测试文件 | 测试方法 |
|----|------|------|--------|------|----------|----------|
| 1 | 模型 | 下载百分比夹取到 0…1，0 渲染不确定态 | P0 | ✅ 已覆盖 | `BookLoadingTests.swift` | `downloadingModeCarriesClampedProgress` |
| 2 | 模型 | 只有 iCloud 载入失败才显示失败态 | P0 | ✅ 已覆盖 | `BookLoadingTests.swift` | `onlyICloudFailureBecomesVisible` |
| 3 | 模型 | 横幅仅在有声书场景可见 | P0 | ✅ 已覆盖 | `BookLoadingTests.swift` | `sceneGatesBannerToAudiobooks` |
| 4 | 模型 | 无书籍库数据时标题退回文件名 stem，且只保留章节名 | P1 | ✅ 已覆盖 | `BookLoadingTests.swift` | `subjectFallsBackToFileStemWithoutLibraryData` |
| 5 | 视图模型 | 场景与播放事件驱动模式切换，离开场景不取消载入 | P0 | ✅ 已覆盖 | `BookLoadingTests.swift` | `viewModelFollowsSceneAndPlaybackChanges` |
| 6 | 视图模型 | 取消立即转发，重试异步转发到播放能力 | P0 | ✅ 已覆盖 | `BookLoadingTests.swift` | `viewModelForwardsCancelAndRetry` |
| 7 | 视图 | 隐藏/有进度/不确定/失败四种模式均可构建 body | P1 | ✅ 已覆盖 | `BookLoadingTests.swift` | `bannerBodyBuildsForEveryMode` |
| 8 | 插件 | 插槽激活态跟随模式，禁用/启用/关闭正确装卸监听 | P0 | ✅ 已覆盖 | `BookLoadingTests.swift` | `pluginActivatesSlotOnlyForAudiobookLoading` |
| 9 | 插件 | 无控制区 Provider 时静默休眠且可安全关闭 | P1 | ✅ 已覆盖 | `BookLoadingTests.swift` | `pluginStaysDormantWithoutControlProvider` |
| 10 | 插件 | 注册阶段注入「关于」与「说明书」文档条目，且两者视图不同 | P1 | ✅ 已覆盖 | `BookLoadingTests.swift` | `onRegisterPublishesAboutAndManualDocsEntries` |
| 11 | 模型 | 章节路径解析出书名与章节位置（递归枚举 + 相对路径自然排序） | P0 | ✅ 已覆盖 | `BookLoadingTests.swift` | `resolverNamesBookAndChapterPosition` |
| 12 | 模型 | 书籍库无该书记录时退回父目录推断，仍给出章节位置 | P1 | ✅ 已覆盖 | `BookLoadingTests.swift` | `resolverFallsBackToParentWhenLibraryHasNoRecord` |
| 13 | 模型 | 顶层单文件识别为整本书，不输出章节位置 | P1 | ✅ 已覆盖 | `BookLoadingTests.swift` | `resolverTreatsTopLevelFileAsWholeBook` |
| 14 | 模型 | 缺少可播扩展名口径时不做目录猜测，只保留章节名 | P1 | ✅ 已覆盖 | `BookLoadingTests.swift` | `resolverKeepsChapterTitleWithoutLibraryContext` |
| 15 | 视图模型 | 资源变化后从书籍库补全书名与「第 n 章 / 共 m 章」 | P0 | ✅ 已覆盖 | `BookLoadingTests.swift` | `viewModelResolvesBookContextFromLibrary` |

## 覆盖率统计

- P0: 7 / 7 ✅
- P1: 8 / 8 ✅
- P2: 0 / 0

**总计: 15 / 15**（本包 `Tests/` 中已声明的 `@Test` 全部登记）

## 优先级说明

- **P0**: 场景门控、模式推导、插槽激活与生命周期、取消/重试转发、书名与章节位置解析
- **P1**: 命名、视图可构建性、Provider 缺席时的退化
- **P2**: 真实窗口内的布局与动画（未在单测覆盖）

## 跨平台说明

- 单测以 macOS 主机 `swift test` 为基准；视图层像素/布局未在本包断言
- 横幅高度由 `ControlView` 的插槽高度决定，切换载入态不改变控制区高度
- 横幅在紧凑插槽（< 70pt）收紧内边距与行距、取消入口并入标题行；
  < 78pt 收起底部说明行，但书名/章节位置始终保留。真实窗口行为由
  `CisumUITests/CisumAudiobooksICloudBannerUITests` 覆盖

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
