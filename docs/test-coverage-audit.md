# Cisum 单元测试与覆盖率审计报告

> 生成时间：2026-09-26 · 仓库：`dev` 分支 · 包数量：86

## 1. 概览

- 有单元测试的包：**80 / 86**（80 个包有 Tests 目录）
- 无 Tests 目录的包：**6 个，均为空壳包**（Sources 下无 Swift 文件：CisumFactory / CisumKernel / CisumUI / KernelCore / PluginAudioJob / PluginRegistry）
- 测试文件总数：**140 个**，测试用例总数：**1175 个**（XCTest `func test` 与 Swift Testing `@Test` 合并统计）
- 测试框架：XCTest 与 Swift Testing（`@Test`）混用，约一半包已迁移到 Swift Testing

## 2. 各包测试规模（按用例数降序）

| 包 | 测试文件数 | 用例数 |
|---|---|---|
| MagicPlayMan | 6 | 139 |
| MagicKit | 31 | 108 |
| PluginAudioDBView | 3 | 79 |
| PluginBookDBView | 3 | 63 |
| PluginAudioDBData | 6 | 59 |
| PluginStorage | 1 | 56 |
| PluginBook | 1 | 56 |
| ProviderBook | 4 | 39 |
| PluginBookProgress | 2 | 39 |
| PluginBookControlButtons | 1 | 34 |
| PluginAudioProgress | 1 | 34 |
| PluginAudioCopy | 1 | 31 |
| PluginPluginManager | 2 | 22 |
| PluginAudioPlayMode | 2 | 22 |
| ProviderStore | 1 | 19 |
| PluginScene | 2 | 17 |
| CisumKernelSupport | 3 | 17 |
| PluginStore | 1 | 16 |
| PluginBookPlayMode | 2 | 16 |
| PluginAudioControlButtons | 1 | 16 |
| PluginAudioWidgetControl | 1 | 14 |
| PluginAudioLike | 1 | 14 |
| PluginDevice | 1 | 12 |
| PluginBookLike | 1 | 12 |
| PluginWelcome | 1 | 11 |
| PluginToast | 2 | 11 |
| PluginPlayBack | 2 | 11 |
| PluginAudioDownload | 1 | 11 |
| PluginLikeButton | 1 | 10 |
| PluginFileLog | 1 | 10 |
| PluginThemeSettings | 1 | 9 |
| PluginPlaybackProgress | 1 | 9 |
| PluginOpenButton | 2 | 9 |
| PluginBookSettings | 1 | 9 |
| PluginAudioSettings | 1 | 9 |
| ProviderPlayback | 1 | 7 |
| PluginVideo | 1 | 7 |
| PluginBookScene | 2 | 7 |
| PluginBookDBData | 2 | 7 |
| PluginAudioScene | 2 | 7 |
| PluginAudio | 1 | 7 |
| ProviderToast | 1 | 5 |
| ProviderScene | 1 | 5 |
| ProviderAudioLibrary | 1 | 5 |
| CisumUIComponents | 1 | 5 |
| ProviderRootView | 1 | 4 |
| ProviderDocsView | 1 | 4 |
| ProviderContentView | 1 | 4 |
| PluginPlaybackHero | 1 | 4 |
| FactoryCisum | 1 | 4 |
| ProviderToolbar | 1 | 3 |
| ProviderSettings | 1 | 3 |
| ProviderControlView | 1 | 3 |
| PluginSettingGeneral | 1 | 3 |
| PluginReset | 1 | 3 |
| PluginAudioDemo | 1 | 3 |
| ProviderTheme | 1 | 2 |
| ProviderStorage | 1 | 2 |
| ProviderPluginManaging | 1 | 2 |
| ProviderDevice | 1 | 2 |
| ProviderCloud | 1 | 2 |
| ProviderAppState | 1 | 2 |
| PluginSettingsButton | 1 | 2 |
| DeviceData | 1 | 2 |
| ProviderPlugin | 1 | 1 |
| ProviderAudioNavigation | 1 | 1 |
| ProviderAudioLike | 1 | 1 |
| PluginThemeSunset | 1 | 1 |
| PluginThemeStudioBlue | 1 | 1 |
| PluginThemePaper | 1 | 1 |
| PluginThemeOcean | 1 | 1 |
| PluginThemeNebula | 1 | 1 |
| PluginThemeMono | 1 | 1 |
| PluginThemeMidnight | 1 | 1 |
| PluginThemeGraphiteBlack | 1 | 1 |
| PluginThemeForest | 1 | 1 |
| PluginThemeDaylightSilver | 1 | 1 |
| PluginThemeCisum | 1 | 1 |
| PluginThemeAurora | 1 | 1 |
| PluginMigrate | 1 | 1 |

## 3. 覆盖率可行性评估

### 已验证的覆盖率管线（可行）

```bash
swift test --enable-code-coverage            # 产出 .build/…/codecov/default.profdata
xcrun llvm-cov report <xctest二进制> -instr-profile=<profdata>  # 行/函数/分支覆盖率
```
已用最小无宏包验证：测试通过 → profdata 生成 → llvm-cov 输出行覆盖率报告，全链路可用。

### 当前命令行环境的阻塞（环境级，非代码问题）

本机命令行工具链（Xcode 27 + 系统进程包装）下，**所有 Swift 宏无法展开**：
`swift-plugin-server produced malformed response`。受影响宏包括 `@State`、`#Preview`、`@Model`、`@Observable` 等系统宏及 LumiUI 宏。
由于 86 个包中几乎所有包都含宏代码（UI 视图、SwiftData 模型、Observable 状态），**当前命令行环境无法自动跑通各包测试并生成覆盖率**（已实测 DeviceData、MagicKit 均因此失败）。
该问题不影响 Xcode GUI 构建（用户日常环境）与 GitHub Actions 的 `macos-latest`（无此进程包装）。

### 提交覆盖率的可行路径

| 路径 | 说明 | 前置条件 |
|---|---|---|
| A. 仓库脚本 + 本地执行 | 新增 `scripts/collect-coverage.sh`：循环各包 `swift test --enable-code-coverage` + `llvm-cov` 汇总为 JSON/Markdown | 在 Xcode GUI 或正常终端环境执行；当前包装环境不可用 |
| B. CI 覆盖率步骤 | 在 GitHub Actions 新增 workflow：`xcodebuild test`（或逐包 `swift test`）开 `-enable-code-coverage`，`xcrun xccov` 汇总并上传 artifact 或提交报告 | CI 仓库权限；首次运行约 15-30 分钟 |
| C. Xcode GUI 内覆盖率 | Xcode → Scheme → Test → Options → 勾选 Gather coverage data，本地查看与导出 | 人工操作，适合开发期自检 |
推荐组合：**C 用于日常开发，B 用于入库门槛**（PR 门禁）；A 作为可复现脚本沉淀在仓库。

## 4. 结论

- 测试资产完备：有代码的包 100% 有单元测试，总量 1175 个用例。
- 覆盖率**可以提交**：管线已验证，限制只在当前命令行环境无法执行宏编译；换到 Xcode GUI 或 CI 即可产出并提交覆盖率数据/报告。
- 下一步建议（任选）：我可以在仓库落地 `scripts/collect-coverage.sh` + CI workflow，或先只交付本审计文件由你决定。
