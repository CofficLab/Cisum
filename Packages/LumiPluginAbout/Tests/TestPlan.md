# TestPlan — LumiPluginAbout

## 包概述

「关于」插件：在宿主设置界面注入「关于」入口，页面包含「我们的应用」
（Coffic Lab 旗下其他应用）与「关于我们」（宿主官网、隐私政策、服务条款）。

公开类型:
- `AboutPlugin` — `@MainActor final class` conforming to `SuperPlugin, SuperLog`
- `AboutView` — 「关于」页详情视图
- `AboutConfiguration` — 宿主配置（官网与法律链接）
- `CofficApp` / `CofficApps` — 应用目录数据模型与静态目录

## 测试用例清单

下表由 `Tests/` 下的真实 `@Test` 声明自动生成，方法名与代码一一对应。

| ID | 类别 | 描述 | 优先级 | 状态 | 测试文件 | 测试方法 |
|----|------|------|--------|------|----------|----------|
| 1 | 插件生命周期 | Boot registers the settings entry | P0 | ✅ 已覆盖 | `AboutPluginTests.swift` | `bootRegistersSettingsEntry` |
| 2 | 插件生命周期 | Shutdown removes the settings entry | P0 | ✅ 已覆盖 | `AboutPluginTests.swift` | `shutdownRemovesSettingsEntry` |
| 3 | 品牌化 | Host can inject brand ID | P0 | ✅ 已覆盖 | `AboutPluginTests.swift` | `hostCanInjectBrandID` |
| 4 | 品牌化 | Default ID is used when no brand injected | P1 | ✅ 已覆盖 | `AboutPluginTests.swift` | `defaultIDIsUsedWhenNoBrandInjected` |
| 5 | 品牌化 | Settings entry ID is brand independent | P1 | ✅ 已覆盖 | `AboutPluginTests.swift` | `settingsEntryIDIsBrandIndependent` |
| 6 | 宿主配置 | Host can inject official website | P0 | ✅ 已覆盖 | `AboutPluginTests.swift` | `hostCanInjectOfficialWebsite` |
| 7 | 宿主配置 | Legal links are optional | P1 | ✅ 已覆盖 | `AboutPluginTests.swift` | `legalLinksAreOptional` |
| 8 | 退化路径 | Boot without settings provider does not throw | P1 | ✅ 已覆盖 | `AboutPluginTests.swift` | `bootWithoutSettingsProviderDoesNotThrow` |
| 9 | 策略 | Policy is reflected in metadata | P1 | ✅ 已覆盖 | `AboutPluginTests.swift` | `policyIsReflectedInMetadata` |
| 10 | 应用目录 | Catalog contains the expected apps | P0 | ✅ 已覆盖 | `CofficAppsTests.swift` | `catalogContainsExpectedApps` |
| 11 | 应用目录 | App identifiers are unique | P1 | ✅ 已覆盖 | `CofficAppsTests.swift` | `appIdentifiersAreUnique` |
| 12 | 应用目录 | Every app URL is a valid https coffic.cn link | P0 | ✅ 已覆盖 | `CofficAppsTests.swift` | `everyAppUsesHttpsCofficURL` |
| 13 | 应用目录 | "All Products" entry points at the product catalog page | P1 | ✅ 已覆盖 | `CofficAppsTests.swift` | `allProductsEntryPointsToCatalogPage` |
| 14 | 应用目录 | Every app has complete presentation data | P2 | ✅ 已覆盖 | `CofficAppsTests.swift` | `everyAppHasCompletePresentationData` |
| 15 | 国际化 | Every app tagline has a Chinese translation in the catalog | P0 | ✅ 已覆盖 | `CofficAppsTests.swift` | `everyAppTaglineHasChineseTranslation` |
| 16 | 国际化 | Section title and "All Products" have Chinese translations | P1 | ✅ 已覆盖 | `CofficAppsTests.swift` | `sectionStringsHaveChineseTranslation` |
| 17 | 国际化 | About/legal-link strings have Chinese translations | P0 | ✅ 已覆盖 | `CofficAppsTests.swift` | `aboutStringsHaveChineseTranslation` |

## 覆盖率统计

- P0: 8 / 8 ✅
- P1: 8 / 8 ✅
- P2: 1 / 1 ✅

**总计: 17 / 17**（本包 `Tests/` 中已声明的 `@Test` 全部登记）

## 测试文件

- `AboutPluginTests.swift` — 9 条用例
- `CofficAppsTests.swift` — 8 条用例

## 优先级说明

- **P0**: 主路径行为（入口注册与撤回、品牌 id 注入、官网注入、链接合法性）
- **P1**: 边界与退化（Provider 缺失、默认策略、id 唯一性、可选法律链接）
- **P2**: 视图 / 布局 / 系统集成相关，依赖真实窗口或系统环境

## 跨平台说明

- 测试以 `swift test`（macOS 主机）运行为基准
- 视图层端到端行为需在 iOS 模拟器或真机验证，不在单测清单内
- 链接跳转使用 SwiftUI 的 `openURL` 环境值，天然跨平台（含 visionOS），
  不需要 AppKit / UIKit 分支

## 测试执行

```bash
cd LumiPluginAbout
swift test
```

## 维护规则

1. **新增公开 API** → 先在 TestPlan 登记测试用例,再写实现
2. **Bug 修复** → 追加回归用例,标注触发条件
3. **删除用例** → 在 commit message 说明理由
4. **状态同步** → 实现后更新 TestPlan,标记 ✅ 并填写测试方法名
