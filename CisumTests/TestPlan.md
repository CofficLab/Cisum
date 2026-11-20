# TestPlan — CisumTests

## 概述

App 宿主单元测试（`bundle.unit-test`，注入 Cisum 进程运行，`@testable import Cisum`）。
组合根迁移到共享 `LumiFactory` 后，原 `FactoryCisum` 包测试随之迁入本目标：
清单装配（`CisumManifest` / `CisumPluginFactory` / `CisumHostWiring`）、
宿主差异服务（主题桥、显隐协调、设备服务）与插件 ID 兼容映射。

内核级用例经 `CisumKernelFixture` 走与 App 相同的流水线
（清单 → `KernelAssembler.makeKernel`），数据根隔离到临时目录，
避免读到开发机上真实 App 的插件启用状态。

## 测试用例清单

### 清单装配（来源 `CisumManifestTests.swift`）

| ID | 类别 | 描述 | 优先级 | 状态 | 测试方法 |
|----|------|------|--------|------|----------|
| 1 | 工厂 | 插件目录 id 唯一且数量 > 30 | P0 | ✅ 已覆盖 | `pluginFactoryProducesUniquePluginIDs` |
| 2 | 行为 | 根 Provider 缺失时接线安全退化 | P1 | ✅ 已覆盖 | `hostWiringFallsBackWhenRootProviderIsMissing` |
| 3 | 行为 | 接线注入控制区 / 内容区视图，demo 关闭、tabs 为空 | P2 | ✅ 已覆盖 | `hostWiringInjectsControlAndContentProviders` |
| 4 | 插件 | 内核启动后加载主题贡献（白名单 + 3 个基础外观） | P0 | ✅ 已覆盖 | `kernelLoadsThemeContributionsAfterPluginStartup` |
| 5 | 插件 | 只加载白名单内的目录主题 | P0 | ✅ 已覆盖 | `kernelLoadsOnlyWhitelistedCatalogueThemes` |
| 6 | 行为 | 暴露云下载进度 Provider（本地文件视为已完成） | P0 | ✅ 已覆盖 | `kernelExposesCloudDownloadProgressProvider` |
| 7 | 行为 | 设置侧栏包含共享「外观」导航项 | P0 | ✅ 已覆盖 | `kernelExposesSharedThemeSettingsNavigationItem` |

### 内容区显隐协调回归（来源 `ContentViewVisibilityCoordinatorTests.swift`）

> 背景：iOS 上「打开只剩播放控制区、没有音乐库」的另一条路径是**显隐真源割裂**。
> 落盘偏好（`AppStateProviding`）与内存态（`RootViewProviding`）只在启动时单向连通，
> 于是出现：旧缺陷写坏的落盘值让每次冷启动都空播放器；「更多」按钮只改内存态导致
> 用户显式选择重启后丢失；两者分叉时按钮按落盘值取反 → 点了没反应。
> 协调器把 `AppStateProviding` 确立为唯一真源，下表逐条锁定。

| ID | 类别 | 描述 | 优先级 | 状态 | 测试方法 |
|----|------|------|--------|------|----------|
| 8 | 回归 | 启动时把落盘态投影到根视图（隐藏） | P0 | ✅ 已覆盖 | `startProjectsPersistedVisibilityOntoRoot` |
| 9 | 回归 | 启动时把落盘态投影到根视图（可见） | P0 | ✅ 已覆盖 | `startProjectsVisibleStateOntoRoot` |
| 10 | 回归 | 真源变更必须投影到根视图 | P0 | ✅ 已覆盖 | `appStateChangeIsProjectedOntoRoot` |
| 11 | 行为 | 停止同步后不再投影 | P1 | ✅ 已覆盖 | `stopStopsProjection` |
| 12 | 回归 | 「更多」收起内容区必须落盘 | P0 | ✅ 已覆盖 | `toggleHidesContentAndPersistsTheChoice` |
| 13 | 回归 | 「更多」展开内容区必须落盘为可见 | P0 | ✅ 已覆盖 | `toggleShowsContentAndPersistsTheChoice` |
| 14 | 行为 | 显式设置同时落盘并立即生效 | P1 | ✅ 已覆盖 | `setVisiblePersistsExplicitChoice` |
| 15 | 回归 | 内存态被外部收起时「更多」仍能带回内容区 | P0 | ✅ 已覆盖 | `toggleRestoresContentHiddenOutsideAppState` |
| 16 | 回归 | 落盘态隐藏时「更多」按实际可见性收起 | P0 | ✅ 已覆盖 | `toggleHidesContentWhenPersistedStateIsHidden` |
| 17 | 集成 | 内核装配后必须能解析到显隐服务 | P0 | ✅ 已覆盖 | `kernelRegistersContentVisibilityService` |

### 主题迁移（来源 `CisumThemeBridgeTests.swift`）

| ID | 类别 | 描述 | 优先级 | 状态 | 测试方法 |
|----|------|------|--------|------|----------|
| 18 | 边界 | legacy 键不存在时不做迁移 | P1 | ✅ 已覆盖 | `doesNothingWhenLegacyKeyIsAbsent` |
| 19 | 回归 | legacy 键指向已移除主题时安全忽略 | P0 | ✅ 已覆盖 | `ignoresLegacyIDThatIsNotInAvailableThemes` |
| 20 | 行为 | legacy 键指向可用主题时完成迁移 | P0 | ✅ 已覆盖 | `migratesLegacySelectionWhenThemeIsAvailable` |

### 插件 ID 兼容映射（来源 `PluginIDCompatibilityTests.swift`）

| ID | 类别 | 描述 | 优先级 | 状态 | 测试方法 |
|----|------|------|--------|------|----------|
| 21 | 规范 | 新 id 全部为反向 DNS 形式 | P1 | ✅ 已覆盖 | `allNewIDsUseReverseDNSForm` |
| 22 | 规范 | 旧 id 与新 id 不同且非空 | P1 | ✅ 已覆盖 | `legacyIDsDifferFromNewIDs` |
| 23 | 回归 | 别名表键值均无重复 | P0 | ✅ 已覆盖 | `aliasTableHasNoDuplicates` |
| 24 | 规范 | 历史目录名不等于新 id 且非空 | P1 | ✅ 已覆盖 | `legacyDirectoryNamesDifferFromNewID` |
| 25 | 回归 | 目录迁移表只覆盖别名表内的插件 | P0 | ✅ 已覆盖 | `directoryMigrationCoversOnlyKnownPlugins` |
| 26 | 回归 | 内核用旧 id 存的状态恢复启用状态 | P0 | ✅ 已覆盖 | `kernelRestoresEnabledStateFromLegacyID` |
| 27 | 回归 | 写入启用状态时新旧 id 双写（回滚兼容） | P0 | ✅ 已覆盖 | `persistingEnabledStateWritesBothNewAndLegacyID` |
| 28 | 边界 | 无历史状态时保持策略默认 | P1 | ✅ 已覆盖 | `pluginWithoutStoredStateKeepsPolicyDefault` |

### 插件管理器启用状态（来源 `PluginManagerEnablementTests.swift`）

| ID | 类别 | 描述 | 优先级 | 状态 | 测试方法 |
|----|------|------|--------|------|----------|
| 29 | 回归 | 插件管理器在 Cisum 是 disabled 策略 | P0 | ✅ 已覆盖 | `pluginManagerIsDisabled` |
| 30 | 回归 | disabled 策略的插件不会被内核启动 | P0 | ✅ 已覆盖 | `disabledPluginIsNotStarted` |

### visionOS 平台语义（来源 `DeviceServiceVisionOSTests.swift`，仅 visionOS 编译执行）

| ID | 类别 | 描述 | 优先级 | 状态 | 测试方法 |
|----|------|------|--------|------|----------|
| 31 | 回归 | visionOS 上既非 Mac 也非 iPad | P0 | ✅ 已覆盖 | `isNotPadNorDesktopOnVisionOS` |
| 32 | 回归 | visionOS 无主屏幕，屏幕尺寸为零值 | P0 | ✅ 已覆盖 | `primaryScreenSizeIsZeroBecauseVisionOSHasNoMainScreen` |
| 33 | 行为 | 设备型号 / 系统版本描述非空 | P1 | ✅ 已覆盖 | `exposesNonEmptySystemDescription` |

## 覆盖率统计

- P0: 23 / 23 ✅
- P1: 9 / 9 ✅
- P2: 1 / 1 ✅

**总计: 33 / 33**（macOS / iOS 执行 30 条，visionOS 执行全部 33 条）

## 迁移说明

- 原 `FactoryCisumTests.selectedPluginFactoryPreservesBaseOrderAndFiltersByID` 已删除：
  `SelectedPluginFactory` 随组合根迁移移除，插件过滤改由清单 `pluginFilter` 承担
  （Cisum 置 nil，全量装配），该类型不再有宿主侧实现可测。
- 原 `CisumBuilder.createKernel / destroyKernel` 由 `CisumKernelFixture` 取代：
  与 App 同走 `KernelAssembler.makeKernel(manifest:)`，数据根隔离到临时目录。
- 目录历史表断言改用存储层的 `PluginDataDirectoryHistory.legacyDirectoryNames`
  （启用状态别名表在宿主 `CisumPluginIDCompatibility`，两者职责分离）。

## 优先级说明

- **P0**: 主路径行为（状态推导、事件翻译、核心策略判定）
- **P1**: 边界与退化（Provider 缺失、取消、失效、并发、竞态）
- **P2**: 视图 / 布局 / 系统集成相关，依赖真实窗口或系统环境

## 测试执行

```bash
# macOS
xcodebuild test -project Cisum.xcodeproj -scheme Cisum \
  -destination "platform=macOS" -only-testing:CisumTests

# iOS 模拟器
xcodebuild test -project Cisum.xcodeproj -scheme Cisum \
  -destination "platform=iOS Simulator,name=iPhone 16" -only-testing:CisumTests

# visionOS 模拟器（含 DeviceServiceVisionOSTests）
xcodebuild test -project Cisum.xcodeproj -scheme Cisum \
  -destination "platform=visionOS Simulator,name=Apple Vision Pro" -only-testing:CisumTests
```

## 维护规则

1. **新增公开 API** → 先在 TestPlan 登记测试用例,再写实现
2. **Bug 修复** → 追加回归用例,标注触发条件
3. **删除用例** → 在 commit message 说明理由
4. **状态同步** → 实现后更新 TestPlan,标记 ✅ 并填写测试方法名