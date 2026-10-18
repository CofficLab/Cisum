# Cisum 单元测试与覆盖率审计报告

> 生成时间：2026-10-18 · 仓库：`dev` 分支
> 本文已按**实测覆盖率数据**重写，替代此前基于「静态清点 + 管线可行性推断」的版本。

## 0. 如何复现本文数据

```bash
./scripts/collect-coverage.sh              # 全量（56 个含源码的包，约 40-60 分钟）
./scripts/collect-coverage.sh MagicKit     # 只跑指定包
python3 scripts/coverage_lib.py file-report temp/coverage/MagicKit.json  # 逐文件明细
```

产物：`temp/coverage/report.md`（汇总）、`<包名>.json`（逐文件）、`<包名>.log`（测试日志）。

> 注：86 个目录中只有 **56 个是真实 SPM 包**（有 `Package.swift` 且 `Sources/` 下有 Swift 源码），
> 其余 30 个只剩 `Package.resolved` / `.swiftpm/` 等残留，是**空壳目录**，不参与统计。

## 1. 覆盖率现状（实测）

- 参与统计：**56 个包**，其中 **53 个**成功产出覆盖率
- **平均行覆盖率：44.31%**

分布呈现明显的**分层特征**：

| 层次 | 代表包 | 覆盖率区间 | 原因 |
|---|---|---|---|
| Provider 层 | `ProviderAudioLike` `ProviderCloud` `ProviderDevice` `ProviderPlayback` `ProviderPlugin` `ProviderScene` `ProviderStorage` | **100%** | 纯协议与状态逻辑，无 UI，天然易测 |
| 强逻辑包 | `PluginBookDBData` `PluginPlaybackProgress` `PluginAudioDBData` | 71%~94% | 业务规则密集 |
| 插件包（主体） | `PluginAudio*` `PluginBook*` | 10%~45% | View / ViewModel 为主，视图体难进单测 |
| 垫底 | `PluginReset` `PluginStore` `PluginAudioDemo` | 5%~18% | 装配与注册逻辑 |

### 1.1 关于「视图代码」的口径（重要，勿误读）

全量代码按是否含 `View`/`About`/`Manual` 字样拆分：

| 类别 | 总行数 | 未覆盖 | 覆盖率 |
|---|---|---|---|
| 视图类 | 30488 | 26109 | **14.4%** |
| 非视图（逻辑） | 28700 | 16406 | **42.8%** |
| 合计 | 59188 | 42515 | **28.2%** |

两个口径差了一倍以上，原因就是**视图占了全部可执行行的 51.5%**。
因此「44.31%」这个总体值受视图拖累；只看逻辑层是 42.8%。

给纯 SwiftUI 声明式视图写单测（断言「视图里有这个 Text」）几乎不发现真实缺陷，
但会推高数字。本项目的取舍是：**优先给视图里的分支逻辑抽 `*Presentation` / `*Policy`
纯函数再测**（如 `AudioDBSettingPresentation`），而不是直接断言视图结构。

### 1.2 已知的非测试失败

| 包 | 现象 | 根因 |
|---|---|---|
| `PluginAudioDBView` | 2 个测试失败（改动前即失败） | `loadInitial` 用 `Task.detached(priority: .background)` 调 `@MainActor` 库能力，测试轮询主线程时后台任务被饿死，`isLoading` 永不落位。需生产侧修复 |
| `PluginAudioDBData` | 测试失败 | 未逐项排查 |
| `PluginRootView` | 无覆盖率数据 | 未逐项排查 |


## 2. 关键结论（与此前版本不同）

此前报告称「命令行环境无法展开 Swift 宏、覆盖率无法产出」。**该结论已失效**：
实测 `swift test --enable-code-coverage` 在含 `@State` / `@Model` / `@Observable` 的包上可正常编译通过。
覆盖率数据现已可稳定产出并入库。

## 3. 口径说明（重要）

统计范围严格限定为 `Packages/<包名>/Sources/`。以下都**不计入**：

- `Tests/` 与构建产物 —— 覆盖率对象是被测代码，不是测试代码
- `.build/checkouts/` 下依赖包源码（LumiUI、ID3TagEditor、ZIPFoundation 等）
- 其它包的 `Sources/`

> 早期版本未做此过滤，得出「平均 17.96%」的偏低结论；修正口径后为 43.19%。差异全部来自依赖包源码被误计入分母。

## 4. 补测优先级建议

按「未覆盖行数 × 可测性」排序，建议优先补测：

| 优先级 | 包 | 现状 | 理由 |
|---|---|---|---|
| 高 | `PluginStore` `PluginReset` `PluginAudioDemo` | 2%~5% | 装配/注册逻辑，纯代码无 UI，补测成本最低 |
| 高 | `PluginBookScene` `PluginAudioScene` `PluginSettingGeneral` `PluginSettingsButton` `PluginWelcome` | 7%~9% | 同上，视图薄、逻辑少 |
| 中 | `PluginAudioDownload` `PluginBookSettings` `PluginAudioSettings` `PluginPluginManager` | 10%~15% | 有明确状态机与错误分支，值得补 |
| 中 | `MagicKit` `PluginAudioCopy` `PluginOpenButton` | 16%~21% | 工具型函数为主，边界用例易补 |
| 低 | `Plugin*View` 系列 | 30% 左右 | 视图体为主，单测收益低，建议靠 UI 测试兜底 |

## 5. 建议的门槛

- Provider 层已达 100%，可作为其它层的参照标准。
- 插件包短期目标可先定在 **50%**，优先补 4 节的「高」优先级项。
- 每次改动后跑 `./scripts/collect-coverage.sh <包名>` 做定向回归，避免全量 40-60 分钟。
