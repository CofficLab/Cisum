# TestPlan — PluginWelcome

## 包概述

欢迎引导：首次启动的存储位置选择与引导页。

公开类型:
- `WelcomePluginHost`
- `WelcomePluginInfo`
- `WelcomeStorageSelection`
- `StorageView`
- `WelcomeView`
- `WelcomePlugin`

### README 中的测试说明（摘自 `README.md`）

- **Test files:**
  - `Tests/WelcomePluginTests.swift`.
- **Key scenarios tested:**
  - Metadata: `iconName = "hand.wave"`, `emoji = "👏"`, `order = -100`.
  - Selection policy: defaults to iCloud when available; falls back to local when iCloud is unavailable (even if a previous selection was iCloud); displays local as the only option otherwise.
  - Persistence rules: the initial default is not persisted before the user chooses; an existing unavailable iCloud selection is persisted as local; on-disappear persistence follows the same rule.
  - `completeGuidePage()` persists the displayed default selection (iCloud when available, local otherwise) and skips updates when storage already exists.
  - `addGuideView()` returns a view only when no storage location exists; `WelcomePluginHost` forwards updates and exposes availability flags.
- **Running tests:**
  ```bash
  cd /Users/angel/Code/Coffic/Cisum/Packages/PluginWelcome
  swift test
  ```
- Tests thoroughly cover the pure selection/policy logic and the host bridge (via injected closures); no real storage is touched.

## 测试用例清单

下表由 `Tests/` 下的真实 `@Test` 声明自动生成，方法名与代码一一对应。

| ID | 类别 | 描述 | 优先级 | 状态 | 测试文件 | 测试方法 |
|----|------|------|--------|------|----------|----------|
| 1 | 插件 | Plugin info exports registration metadata | P0 | ✅ 已覆盖 | `WelcomePluginTests.swift` | `pluginInfoExportsRegistrationMetadata` |
| 2 | 行为 | Welcome setup is always enabled as required first run infrastructure | P0 | ✅ 已覆盖 | `WelcomePluginTests.swift` | `welcomeSetupIsAlwaysEnabledAsRequiredFirstRunInfrastructure` |
| 3 | 行为 | Storage selection defaults to i cloud when available | P0 | ✅ 已覆盖 | `WelcomePluginTests.swift` | `storageSelectionDefaultsToICloudWhenAvailable` |
| 4 | 行为 | Storage selection falls back to local when i cloud unavailable | P1 | ✅ 已覆盖 | `WelcomePluginTests.swift` | `storageSelectionFallsBackToLocalWhenICloudUnavailable` |
| 5 | 行为 | Storage selection displays local when it is the only available option | P0 | ✅ 已覆盖 | `WelcomePluginTests.swift` | `storageSelectionDisplaysLocalWhenItIsTheOnlyAvailableOption` |
| 6 | 行为 | Onboarding always presents a selected draft for the confirm button | P0 | ✅ 已覆盖 | `WelcomePluginTests.swift` | `onboardingAlwaysPresentsASelectedDraftForTheConfirmButton` |
| 7 | 行为 | Storage selection keeps existing choice when it is still available | P0 | ✅ 已覆盖 | `WelcomePluginTests.swift` | `storageSelectionKeepsExistingChoiceWhenItIsStillAvailable` |
| 8 | 持久化 | Storage selection does not persist initial default before user chooses | P0 | ✅ 已覆盖 | `WelcomePluginTests.swift` | `storageSelectionDoesNotPersistInitialDefaultBeforeUserChooses` |
| 9 | 持久化 | Storage selection persists only existing unavailable selection fallback | P1 | ✅ 已覆盖 | `WelcomePluginTests.swift` | `storageSelectionPersistsOnlyExistingUnavailableSelectionFallback` |
| 10 | 持久化 | Storage selection does not persist initial default on disappear | P0 | ✅ 已覆盖 | `WelcomePluginTests.swift` | `storageSelectionDoesNotPersistInitialDefaultOnDisappear` |
| 11 | 持久化 | Completing welcome guide persists displayed default selection | P0 | ✅ 已覆盖 | `WelcomePluginTests.swift` | `completingWelcomeGuidePersistsDisplayedDefaultSelection` |
| 12 | 行为 | Guide view is shown only when no storage location exists | P2 | ✅ 已覆盖 | `WelcomePluginTests.swift` | `guideViewIsShownOnlyWhenNoStorageLocationExists` |
| 13 | 行为 | Completing guide when storage exists skips update | P0 | ✅ 已覆盖 | `WelcomePluginTests.swift` | `completingGuideWhenStorageExistsSkipsUpdate` |
| 14 | 行为 | Host forwards update storage selection | P0 | ✅ 已覆盖 | `WelcomePluginTests.swift` | `hostForwardsUpdateStorageSelection` |

## 覆盖率统计

- P0: 11 / 11 ✅
- P1: 2 / 2 ✅
- P2: 1 / 1 ✅

**总计: 14 / 14**（本包 `Tests/` 中已声明的 `@Test` 全部登记）

## 测试文件

- `WelcomePluginTests.swift` — 14 条用例

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
cd Packages/PluginWelcome
swift test
```

## 维护规则

1. **新增公开 API** → 先在 TestPlan 登记测试用例,再写实现
2. **Bug 修复** → 追加回归用例,标注触发条件
3. **删除用例** → 在 commit message 说明理由
4. **状态同步** → 实现后更新 TestPlan,标记 ✅ 并填写测试方法名
