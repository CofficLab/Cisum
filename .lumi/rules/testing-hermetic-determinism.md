# 测试体系规范（隔离 + 确定性 + 数据保真 + 分层）

> 本规范定义 Cisum 单元测试与 UI 测试的设计原则与落地约定。
> 核心目标：**不同开发者在自己的机器上运行同一份测试，必须得到相同的结论。**

---

## 0. 为什么需要这份规范

测试的价值等于「断言的可信度」。断言可信要求：**同样的输入必然得到同样的结论**。

一旦测试能观察到上次运行留下的东西，它测的就不是当前代码，而是「当前代码 + 环境的历史」。

Cisum 曾经存在三类跨机不一致：

| 类别 | 表现 | 根因 |
|---|---|---|
| **输入不同** | 测试读写开发者真实的 `UserDefaults` / 真实 iCloud 键值库 | 进程级全局状态无法注入 |
| **输入不同** | UI 测试的仓库内容取决于上一次运行残留 | 隔离与重置语义没闭合 |
| **结果不同** | 同样的输入每次跑出的顺序/时序不同 | 遍历顺序、墙钟、固定 sleep |

前两类靠**隔离**解决，第三类靠**确定性**解决。两者是正交的，必须都做。

---

## 1. 四条原则

### 1.1 隔离：测试不依赖外部残留状态

测试的输入必须由测试自己完全决定，包括：

- **文件系统**：临时目录 + 唯一名 + `defer` 清理
- **数据库**：内存容器（`isStoredInMemoryOnly: true`）
- **偏好存储**：独立 `UserDefaults` suite
- **iCloud 键值库**：内存实现，**不依赖设备是否登录 iCloud**

**禁止**在测试中直接读写 `UserDefaults.standard` 或 `NSUbiquitousKeyValueStore.default`。

> 这不只是「不优雅」。`NSUbiquitousKeyValueStore.default` 的可用性取决于
> **设备是否登录 iCloud**——同一份断言在登录和未登录的机器上会得到不同结论。
> 这是「跨机结果不一致」最隐蔽也最常见的来源。

### 1.2 确定性：同样的输入给出同样的输出

隔离解决「输入不同」，确定性解决「结果不同」。

具体要求：

- **遍历顺序固定**：回调表用有序数组，不用 `Dictionary`
- **不依赖真实挂钟**：断言语义而非耗时（「覆写超时生效」而非「耗时 < 15s」）
- **等待按时间给预算**，不按固定轮数
- **并发时序显式等待**，不用固定 sleep 硬撑

### 1.3 数据保真：造出来的数据要能触发真实边界

造数据不是目的，**造出能触发真实边界条件的数据**才是。

反面教材：造一个形态失真的假数据，然后断言「空仓库时显示空状态」——
这条断言永远成立，也就永远测不出任何东西。

正面例子（Cisum 的既有实践）：

- 音频种子是**真实可解码的 16-bit PCM WAV**，不是单字节占位——
  因为「进度随播放推进」需要引擎真能解出流
- 有声书种子是**目录 + 章节文件**的形态，与用户真实拖入书籍文件夹的路径一致
- 种子章节的扩展名必须落在仓库**真的会索引**的格式上

### 1.4 分层：按成本决定隔离强度

不是所有测试都值得付 hermetic 的成本。

| 层次 | 隔离强度 | 理由 |
|---|---|---|
| **单元测试** | 全面 hermetic，100% 执行 | 成本几乎为零（临时目录 + 内存库），收益极高 |
| **UI 测试·核心断言** | 严格隔离 | 空仓库态、Hero 显隐、场景切换——值得 |
| **UI 测试·集成断言** | 允许真实环境，但**显式 skip** | iCloud 路径、沙盒边界——覆盖差异必须被记录 |

关键洞察：**隔离「状态残留」和隔离「系统行为」是两件事，可以正交。**

完全可以同时做到「用真的 iCloud 容器」+「容器里只有我造的那一份内容」。
Cisum 的 iCloud UI 用例现在就是这么做的。

---

## 2. 单元测试落地约定

### 2.1 偏好存储必须可注入

生产代码**禁止**在状态仓库里硬编码 `UserDefaults.standard` / `NSUbiquitousKeyValueStore.default`。

Cisum 提供的两个基础设施（在 `MagicKit`）：

```swift
// CloudKeyValueStore：iCloud 键值库的窄契约
public protocol CloudKeyValueStore: AnyObject, Sendable {
    func string(forKey key: String) -> String?
    func set(_ value: String?, forKey key: String)
    func removeObject(forKey key: String)
    func synchronize()
}

// PreferenceStore：本地 + iCloud 双通道偏好存储
public final class PreferenceStore {
    public init(
        defaults: UserDefaults = .standard,
        cloud: CloudKeyValueStore = UbiquitousKeyValueStore.shared
    )
    // 生产用 .shared，测试注入隔离实例
}
```

生产仓库的写法：

```swift
public final class BookSettingRepo {
    public static let shared = BookSettingRepo()          // 生产
    private let preferences: PreferenceStore

    public init(preferences: PreferenceStore = .shared) {
        self.preferences = preferences
    }
}
```

测试的写法：

```swift
let defaults = UserDefaults(suiteName: "BookSettingRepoTests-\(UUID().uuidString)")!
defaults.removePersistentDomain(forName: suiteName)
let preferences = PreferenceStore(
    defaults: defaults,
    cloud: InMemoryCloudKeyValueStore()
)
let repo = BookSettingRepo(preferences: preferences)
```

### 2.2 禁止「保存-恢复真实偏好」

旧写法读写真实 `UserDefaults`，再在 `defer` 里恢复原值。这仍有两个问题：

1. 真实偏好在读写过程中处于**被改写**的中间态，进程崩溃就丢配置；
2. 断言结论取决于「运行测试前开发者的缓存长什么样」。

正确做法：**从一开始就用隔离实例**，根本不去碰真实偏好。

### 2.3 `.serialized` 不是解决方案

`@Suite(.serialized)` 是**用调度换隔离**——牺牲并行度来绕开全局状态冲突。

判断标准：**如果一个套件需要 `.serialized` 才能通过，先问是不是在读写全局状态。**
隔离做对了，串行化自然就不需要了。

> Cisum 改造后，`ProviderBook`、`PluginAudioProgress` 两个套件解除了 `.serialized`。

### 2.4 等待异步状态：必须用 `DeterministicWait`

```swift
// ❌ 旧：预算与机器速度耦合，失败信息缺失
for _ in 0..<100 where await library.totalCount() != 2 {
    try await Task.sleep(nanoseconds: 20_000_000)
}

// ✅ 新：按墙钟给预算，失败时给出可诊断描述
await DeterministicWait.expect(
    "library.totalCount() 应等于 2",
    timeout: 2.0
) { await library.totalCount() == 2 }
```

`DeterministicWait` 位于 `MagicKit/Sources/Utils/DeterministicWait.swift`，
标了 `@MainActor`（绝大多数被测对象是 MainActor 隔离的）。

**不要写固定 sleep。** 固定 sleep 是 flaky 的主要来源。

### 2.5 不依赖真实挂钟做断言

```swift
// ❌ 测的是「机器有多快」，CI 慢机必挂
XCTAssertLessThan(Date().timeIntervalSince(start), 15, "覆写超时未生效")

// ✅ 测的是语义：预算相对「被测配置」而非绝对墙钟
let budget = (control.effectiveTimeout ?? 0.2) * 5
XCTAssertLessThan(Date().timeIntervalSince(start), budget, "覆写超时未生效")
```

---

## 3. UI 测试落地约定

### 3.1 默认必须开启隔离

`CisumUITestBase.additionalLaunchArguments` 默认包含：

```swift
[
    "--cisum-ui-testing",
    "--cisum-ui-testing-storage-local",
    "--cisum-ui-testing-reset-scene",
    "--cisum-ui-testing-isolated-storage=\(Self.isolatedStorageName)",
    "-UI.ContentViewVisible", "YES",
]
```

- **`--cisum-ui-testing-isolated-storage=<名>`**：数据根落到临时目录的独立子目录
- **`--cisum-ui-testing-reset-scene`**：忽略上次持久化的场景

> **顺序约定**：`-UI.ContentViewVisible YES` 必须放在末尾。
> UserDefaults 的参数域遇到第一个**不含 `=`** 的参数就停止解析，
> `YES` 正是这样的参数。放在中间会让后面的 `--foo=bar` 整段被丢弃。

### 3.2 隔离根必须幂等重建

`UITestIsolation.resetIsolatedRootIfNeeded()` 在 App 启动时**整个根目录删掉重建**。

位置在 `FactoryCisum.createKernel`——内核创建后、任何插件 boot **之前**。
这是唯一能保证「所有插件都看到干净环境」的位置。

**为什么必须整体重建**：只删磁盘目录不够，**数据库里的行也必须一起清掉**
（数据库文件就落在该根目录下）。这正是历史上「删磁盘目录不够——
数据库里的行还在，列表照样有内容」的根治。

### 3.3 隔离目录名要可寻址，不要随机

**刻意不用随机目录名**。随机会让「上次失败的场景」这次不复现，
只剩一句「它昨天挂过一次」。

正确做法：**结构固定 + 幂等清理**——目录名由用例类名派生，
每次启动先清空再重建。两者不冲突：结构固定，内容可寻址。

### 3.4 造数能力必须与被测对象对齐

| 能力 | 启动参数 | 实现 |
|---|---|---|
| 音乐仓库 | `--cisum-ui-testing-seed-audio <名>[,<名>]` | `UITestAudioSeedTone`（PluginAudioDBData） |
| 音乐时长 | `--cisum-ui-testing-seed-duration <秒>` | 同上 |
| 有声书仓库 | `--cisum-ui-testing-seed-book <书名>[/<章节>,<章节>][;...]` | `UITestBookSeedTone`（PluginBookDBData） |

两者刻意保持**同一套语义**：真实可解码的 PCM WAV、真实的目录结构、
落在仓库真的会索引的扩展名。

### 3.5 依赖系统能力的用例必须显式 skip

iCloud 容器需要设备**已登录 iCloud 账号**。没有账号时容器路径根本不存在——
这是真实的系统约束，任何实现都绕不过去。

```swift
func requireRealICloudContainer(reason: String) throws {
    guard isRealICloudContainerAvailable else {
        throw XCTSkip("""
        \(reason) 需要真实 iCloud 容器，但当前设备未登录 iCloud 账号
        （或容器不可用）。本用例在未覆盖 iCloud 路径的机器上被显式跳过，
        而不是「因为容器不存在而顺带通过」——
        否则它会与其它机器一样显示为绿色，却什么都没测。
        """)
    }
}
```

**绝不能让它「因为容器不存在而顺带通过」。** 那样这条用例在没登录 iCloud 的
机器上根本没测到任何东西，却和其它机器一样显示为绿色。

跨机一致性由这条约定保证：**要么真的测了，要么明确报告本机未覆盖。**

### 3.6 iCloud 用例：真容器 + 干净内容

`MagicApp.getCloudDocumentsDirectory()` 在 UI 测试下返回
`真实 iCloud 容器/Documents/CisumUITest/<隔离名>/`：

- 真实容器 → `NSMetadataQuery` 那条监控实现仍会被走到
  （与本地的 `DispatchSource` 是两套完全不同的代码，这正是要覆盖的）
- 隔离子目录 → 内容由测试独占，开发者自己同步的文件不会混进来

**隔离的是「状态残留」，不是「系统行为」。**

---

## 4. 检查清单

新增或修改测试时：

- [ ] 没有直接读写 `UserDefaults.standard` / `NSUbiquitousKeyValueStore.default`
- [ ] 状态仓库的偏好存储是**可注入**的（不是 static 硬编码）
- [ ] 文件系统用临时目录 + 唯一名 + `defer` 清理
- [ ] 数据库用内存容器
- [ ] 没有「保存-恢复真实偏好」这种变相污染
- [ ] 套件不需要 `.serialized`（需要就说明在读写全局状态）
- [ ] 没有固定 `Task.sleep` 同步（用 `DeterministicWait`）
- [ ] 没有用真实挂钟做断言
- [ ] 遍历顺序确定（不用 `Dictionary` 存回调）
- [ ] 造的种子数据是**真实可解码 / 可索引**的形态
- [ ] UI 测试用例默认开启隔离（不要覆写掉 `isolated-storage`）
- [ ] 依赖系统能力（iCloud / 文件选择器）的用例**显式 skip**，不靠顺带通过
- [ ] 隔离目录名可寻址（不随机）

---

## 5. 相关文件

| 文件 | 作用 |
|---|---|
| `Packages/MagicKit/Sources/Utils/CloudKeyValueStore.swift` | iCloud 键值库窄契约 + 内存实现 |
| `Packages/MagicKit/Sources/Utils/PreferenceStore.swift` | 本地 + iCloud 双通道偏好存储 |
| `Packages/MagicKit/Sources/Utils/UITestIsolation.swift` | UI 测试隔离根解析与幂等重建 |
| `Packages/MagicKit/Sources/Utils/DeterministicWait.swift` | 确定性等待工具 |
| `Packages/PluginAudioDBData/Sources/Support/UITestAudioSeedTone.swift` | 音乐种子合成器 |
| `Packages/PluginBookDBData/Sources/Support/UITestBookSeedTone.swift` | 有声书种子合成器 |
| `CisumUITests/CisumUITestCase.swift` | UI 测试基类（默认隔离 + 显式 skip 工具） |
| `docs/test-coverage-audit.md` | 覆盖率与测试现状审计 |
