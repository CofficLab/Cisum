# Cisum 单元测试与覆盖率审计报告

> 生成时间：2026-10-18 · 仓库：`dev` 分支
> 本文已按**实测覆盖率数据**重写，替代此前基于「静态清点 + 管线可行性推断」的版本。
>
> 另见：[测试体系审计与改造](#7-测试体系审计与改造)（2026-10 第二轮）——
> 覆盖率回答「测了多少」，本文回答「测得**稳不稳**」。

---

## 7. 测试体系审计与改造

> 第二轮审计（2026-10）。目标是回答一个具体问题：
> **不同开发者在自己的机器上跑同一份测试，结论是否一致？**
> 答案在改造前是「否」，本节记录证据、改造与验证结果。

### 7.1 结论先行

改造前的状态可以概括为：**机制齐全，但执行层有两处没闭合**。

| 维度 | 改造前 | 改造后 |
|---|---|---|
| 单测文件系统隔离 | ✅ 良好（临时目录 + UUID） | 不变 |
| 单测数据库隔离 | ✅ 良好（纯内存容器） | 不变 |
| 单测偏好/全局状态隔离 | ⚠️ **9 处破口** | ✅ **0 处** |
| 单测等待的确定性 | ⚠️ 37 处固定轮数 + sleep | ✅ 统一 `DeterministicWait` |
| UI 测试隔离机制 | ⚠️ 机制齐全但**默认路径没开** | ✅ 默认开启 + 幂等重建 |
| UI 测试造数 | ⚠️ 音频 ✅ / 有声书 ❌ | ✅ 两边对齐 |
| UI 测试跨机一致性 | ❌ iCloud 依赖真实账号 | ✅ 显式 skip，明确报告覆盖差异 |

### 7.2 审计证据

#### 单测全局状态破口（9 处）

生产代码把 `UserDefaults.standard` / `NSUbiquitousKeyValueStore.default` 硬编码在
状态仓库里，导致测试只能绕开真实 I/O 路径去测纯函数分支——**生产路径本身从未被
hermetic 地覆盖**。

| 位置 | 问题 |
|---|---|
| `ProviderBook/BookSettingRepo.swift` | 全文 static，直接读写两个 store |
| `ProviderBook/BookRepo.swift:108` | `"BookLastUpdateTime"` 去抖时间戳写全局 |
| `PluginAudioProgress/AudioStateRepo.swift` | 全文 static |
| `PluginAudioPlayMode/AudioPlayModeStore.swift` | actor + `.shared` 单例硬编码 |
| `PluginBookPlayMode/BookPlayModeStore.swift` | 同构 |
| `PluginScene/SceneProvider.swift:179` | legacy 场景键读写全局 |
| `ProviderStoreKit/StoreState.swift:38` | 购买缓存读写真实偏好 |
| `FactoryCisum/CisumThemeBridge.swift:18` | 主题 ID 读全局 |
| `PluginAudioDBView/AudioStorageDiagnosticsFactory.swift:14` | **读写不同源**（见 7.3） |

对应的测试侧破口：

- `ProviderBook/BookCoverageTests.swift` — 清**真实** iCloud 键值库；
  套件被迫 `@Suite(.serialized)`
- `PluginScene/ScenePluginTests.swift` — `removeObject` 清掉**开发者真实的场景设置**
- `PluginBookDBData/BookDatabaseProviderTests.swift` — 读写真实 `"BookLastUpdateTime"`
- `ProviderStoreKit/ProviderStoreTests.swift` — 「保存-恢复」真实购买缓存

#### UI 测试隔离矩阵（23 个文件 / 81 个用例）

| 机制 | 实现 | 改造前状态 |
|---|---|---|
| 独立偏好 suite | `PluginStorage/StoragePlugin.swift:75` | ✅ |
| 钉住存储位置 | `--cisum-ui-testing-storage-local/-icloud` | ✅ |
| 重置存储位置 | `--cisum-ui-testing-reset-storage` | ✅ 仅 1 处用 |
| 重置场景 | `--cisum-ui-testing-reset-scene` | ✅ 仅 1 处用 |
| 隔离数据根 | `--cisum-ui-testing-isolated-storage=<名>` | ✅ 机制有，**仅 1 处用** |
| 音频造数 | `--cisum-ui-testing-seed-audio` | ✅ 5 处用 |
| 内容区显隐 | `-UI.ContentViewVisible YES` | ✅ |
| 仓库磁盘重置 | `resetUITestAudioStateIfRequested` | ⚠️ **只删磁盘目录，不删数据库行** |

### 7.3 关键根因

**「删磁盘目录不够——数据库里的行还在」** 是历史上被反复注释到的一句话。
根因是隔离与重置的语义没闭合：清磁盘目录是**局部**操作，而数据分布在
**整棵树**上（磁盘目录 + SwiftData 数据库文件 + 插件数据目录）。

修复方式是让隔离根**整体重建**——整个根目录删掉再创建，数据库文件随之消失。

另一处隐蔽缺陷：`AudioStorageDiagnosticsFactory` 读 `UserDefaults.standard`，
而 `StoragePlugin` 在 UI 测试下写的是**独立 suite**——读写不同源，
诊断面板在 UI 测试里永远显示「未设置存储位置」。这类 bug 靠覆盖率发现不了，
只有把「谁读谁写」理清才暴露。

### 7.4 改造内容

#### 新增基础设施（MagicKit）

| 文件 | 作用 |
|---|---|
| `Utils/CloudKeyValueStore.swift` | iCloud 键值库窄契约 + `InMemoryCloudKeyValueStore` |
| `Utils/PreferenceStore.swift` | 本地 + iCloud 双通道偏好存储（生产 `.shared`） |
| `Utils/UITestIsolation.swift` | 隔离根解析 + **幂等重建** |
| `Utils/DeterministicWait.swift` | 确定性等待（按墙钟预算 + 可诊断失败信息） |

#### 生产代码去硬编码

9 处硬编码全部改为可注入，`shared` 保留为生产默认路径。
`PluginScene/SceneProvider`、`ProviderStoreKit/StoreState` 也一并处理。

#### 测试侧改造

- **删除 `.serialized`**：`ProviderBook`、`PluginAudioProgress` 两个套件解除串行限制
- **新增双通道语义用例**：写两通道、iCloud 回退、本地优先（共 5 个）
- **37 处轮询等待**统一改为 `DeterministicWait`（12 个包）
- **墙钟断言改语义断言**：`ICloudDownloadingTests` 不再比较真实耗时

#### UI 测试

- 基类默认参数加上 `--cisum-ui-testing-isolated-storage=<类名>` 与 `--cisum-ui-testing-reset-scene`
- `FactoryCisum.createKernel` 在任何插件 boot 前**幂等重建**隔离根
- 新增 `--cisum-ui-testing-seed-book`，与音频侧语义对齐
- iCloud 用例改用**真实容器的隔离子目录**（真容器 + 干净内容）
- 新增 `requireRealICloudContainer(reason:)`：容器不可用时**显式 skip**

### 7.5 验证结果

**单元测试**：59/59 个包通过，共 **1586** 个测试。

**UI 测试**（macOS）：

| | 失败 | 跳过 |
|---|---|---|
| 改造前（基线） | 21 | 6 |
| 改造后 | **20** | 7 |

差异的那 1 个正是 `CisumAudiobooksICloudLoadingUITests`：

- 基线：**失败**（容器不可用导致误判）
- 改造后：**显式 skip**，报告「需要真实 iCloud 容器，但当前设备未登录 iCloud 账号」

这正是设计的语义——**明确报告本机未覆盖，而不是误报失败或伪装成绿色**。

其余 20 个失败在基线上同样存在（场景切换器、商店入口、下载环等 UI 断言），
与本次改造无关，属既有缺陷。

**隔离机制实测**（App 沙盒内）：

```
~/Library/Containers/com.yueyi.cisum.debug/Data/tmp/cisum-ui-testing/<用例类名>/
├── ApplicationSupport/db_debug_v4/audio/audio.db   ← 数据库在隔离区内
└── Documents/audios_debug/*.wav                      ← 种子数据在隔离区内
```

### 7.6 遗留事项

1. **既有 UI 测试失败 20 个**（场景切换器找不到、商店页缺「购买」入口、
   下载环相关）——与测试体系无关，是产品缺陷，需单独立项。
2. **UI 测试在 iOS 上的覆盖有限**：`ensureMusicScene` / `ensureAudiobooksScene`
   在 iOS 上无法通过 UI 切换场景，相关用例直接 skip。
3. **跨机一致性尚未有 CI 佐证**：目前只有本机基线对比，
   建议后续在 CI 上跑同一份测试并比对跨 runner 的结果。
4. **仍有 1 处只读 `UserDefaults.standard`**（`PluginStorage/StoragePluginTests`
   的自比较断言，只读、不写入，判定为低危）。

### 7.7 配套规范

完整规则见 `.agent/rules/testing-hermetic-determinism.md`，
摘要见 `CONTRIBUTING.md` 的 *Test isolation and determinism* 章节。

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
| （已解除）`PluginRootView` | 曾**编译失败**，无覆盖率数据 | `RootLayoutView.swift:198` 调用 `AppResponsivePlayerLayoutMetrics.shared.horizontalCenteringOffset(...)`，当时 LumiUI 中该方法尚未合入。**已解决**：当前 checkout 的 LumiUI 已提供该 API，`swift build` 通过 |
| （已解除）`PluginAudioDBView` | 曾有 2 个测试失败 | `loadInitial` 用 `Task.detached(priority: .background)` 调 `@MainActor` 库能力，测试轮询主线程时后台任务被饿死，`isLoading` 永不落位。**现已无法复现**，全量 118 个测试通过 |

### 1.2.1 本轮修复（iCloud 下载进度环闪烁）

根因是一条跨包的因果链，`NSMetadataQuery` 把每次下载百分比推送都算作目录变更：

1. `ICloudDirectoryMonitor.handleQueryUpdate` 把物化进度变化与成员变化混在一起透传；
2. 库同步因此在下载期间被百分比频率反复触发，抛出 `synced` / `updated`；
3. `AudioDatabaseObserver` 转发后 `AudioListViewModel` 刷新当前页；
4. 旧实现在刷新路径上调 `downloadStore.removeAll()`，把刚播报的进度抹掉。

修复分两层：

- `ICloudDirectoryMonitor` 新增 `IdentityLedger`，以「路径是否在基线内」区分成员变化与物化进度，
  并在 `deliverInitialScan` 后用完整快照重置基线，避免启动期文件被误判为新增。
- `CloudDownloadProgressStore` 明确所有权：进度只随文件删除而消亡，列表刷新无权清空；
  删除 `retainOnly(_:)` 这个「按可见集合裁剪」的原语，`removeAll()` 仅保留给存储切换。

回归测试：`ICloudDirectoryMonitorIdentityLedgerTests`（10 个）、`CloudDownloadProgressSurvivesDatabaseRefreshTests`（5 个）。

已修复的历史 flaky：

- `PluginAudioDBData`：轮询循环写成 `for _ in 0..<100 where await library.totalCount() == 0`，
  `where` 条件在每轮循环前求值，条件翻转即退出循环，语义正确但极易被误改。
  已改为显式 `if <目标达成> { break }`，连跑 3 次稳定通过。
- `KitEventObservation`：`EventObserverStore` 用 `Dictionary` 存回调导致投递顺序随机（5 次挂 4 次），
  已改为有序数组。

### 1.3 依赖结构风险（待确认）

多个包编译的 Provider / LumiUI 等模块来自 `.build/checkouts/` 下的**外部 git 依赖**，
而仓库内同时存在同名本地 `Packages/Provider*`。若 App target 实际链接本地版本，
则针对 checkout 编译产物的测试可能未覆盖真正出货的代码。**建议尽早确认。**


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
