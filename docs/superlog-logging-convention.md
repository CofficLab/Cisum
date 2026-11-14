# SuperLog 日志规范（Cisum）

> 本文档汇总项目中对 `MagicKit/Sources/Protocols/SuperLog.swift` 的实际使用方式，沉淀为统一约定。
> 目标：任何新增代码都能写出**一眼可读、可分级、可检索**的日志。

---

## 1. 是什么

`SuperLog` 是一个协议，为类型提供统一的日志前缀与辅助能力：

- 自动附带**线程 QoS 标识**（`[UI]` / `[IN]` / `[DF]` / `[UT]` / `[BG]` / `[UN]`）
- 自动附带**类型 emoji + 类型名**（右对齐到固定宽度）
- 提供 Init / OnAppear 等语义化前缀与原因标记

所有输出通道统一走 **OSLog（`os_log`）**，不使用 `print` 打日志。

## 2. 接入方式（三步）

```swift
final class SomeService: SuperLog {
    // ① 类型标识 emoji（必选，用于日志检索）
    static let emoji = "📦"

    // ② verbose 开关（必选，见第 5 节）
    nonisolated static let verbose = false

    func doSomething() {
        // ③ 用 t / i / a 打日志
        os_log("\(self.t)开始处理")
    }
}
```

## 3. 前缀与核心 API

### 前缀格式

`\(t)` / `\(Self.t)` 展开为：

```
[UI] | 📦 SomeService               | 消息内容
```

| 段 | 来源 | 示例 |
|---|---|---|
| 线程 QoS | `Thread.currentQosDescription` | `[UI]` `[BG]` |
| 类型 emoji | `emoji` | `📦` |
| 类型名 | `author`（截取 `Type<...>` 泛型前的名字） | `SomeService` |
| 分隔符 | 固定 | ` | ` |

### API 速查

| API | 含义 | 典型输出 |
|---|---|---|
| `\(t)` / `\(Self.t)` | 通用前缀（线程 + emoji + 类型名） | `[UI] \| 📦 AudioDB \| 消息` |
| `\(i)` / `\(Self.i)` | Init 场景，`🚩 Init ` | `[UI] \| 📦 AudioDB \| 🚩 Init with reason: ...` |
| `\(a)` / `\(Self.a)` | OnAppear 场景，`📺 OnAppear ` | `[UI] \| 📦 View \| 📺 OnAppear ` |
| `r("原因")` | 原因标记，` ➡️ 原因` | `登录失败 ➡️ 密码错误` |
| `emoji` | 类型标识，未实现时按 `author` 自动生成 | 自定义优先 |
| `author` / `className` | 类型名 | — |
| `isMain` | 是否主线程 | — |

> 注意：`t` 已包含 emoji 与类型名，**不要在消息里再重复写一次类型名**。

## 4. 日志级别

项目统一使用 `os_log`，级别约定：

| 级别 | 写法 | 场景 |
|---|---|---|
| 默认（info） | `os_log("\(self.t)...")` | 常规状态、操作、事件 |
| `.error` | `os_log(.error, "\(self.t)...")` | 失败、异常、不可达分支 |

- **错误日志必须带 `\(self.t)` / `\(Self.t)` 前缀**，便于按来源过滤。
- 错误日志不受 `verbose` 开关控制（见下节）。
- 全局事件、重要链路可选用 `Logger(...).info/.error`（如 `EventManager`），分类命名遵循 `subsystem: "com.coffic.cisum"`。

## 5. verbose 分级控制

高频或冗长的调试日志用 `verbose` 门控，重要日志不门控：

```swift
nonisolated static let verbose = false

func allAudios() {
    if Self.verbose { os_log("\(self.t)🚛 GetAllAudios 🐛 \(reason)") }   // 调试细节
    // ... 主逻辑
    os_log(.error, "\(self.t)❌ 获取失败: \(error.localizedDescription)") // 重要错误，不门控
}
```

约定：
- 类型内统一声明 `nonisolated static let verbose = false`（Service/Repo/Manager 层建议开放为可配置）。
- 单行写法：`if Self.verbose { os_log(...) }`。
- **错误、用户可感知的关键状态变更永远打印**，不放进 `verbose`。
- 默认 `false`；`verbose` 的启用应在初始化入口集中控制（如 `Man(verbose:)`）。

## 6. emoji 语义约定

### 类型标识 emoji

每个类型自定义一个与职责相关的 emoji（`static let emoji`），同一 Plugin 内可复用：

| 层 | 常用 emoji | 示例 |
|---|---|---|
| Plugin | `🔌` | `AudioDBPlugin` |
| DB / Repo / 存储 | `📦` `💾` | `AudioDB` `AudioRepo` |
| 模型 | `🔔` `📄` | `AudioModel` |
| 播放器 | `🎵` `▶️` 等 | `MagicPlayMan` |
| 事件 | `📣` | `EventManager` |
| 视图 | 自定义 | `CopyStateView` |
| Shell / 系统 | `🖥️` 等 | `ShellFile` |

### 消息内容 emoji（日志正文开头）

统一用首部 emoji 表达「语义」，便于扫读与检索：

| emoji | 语义 | 示例 |
|---|---|---|
| 🚩 | Init / 初始化 | `\(Self.i)` 已内置 |
| 📺 | OnAppear / 渲染 | `\(Self.a)` 已内置 |
| ✅ | 成功 / 完成 | `✅ All files copied` |
| ❌ | 失败 / 错误（配 `.error`） | `❌ Failed to copy files: ...` |
| ⚠️ | 警告 / 废弃 / 降级 | `⚠️ dislike(_:) 已废弃` |
| 🚀 | 开始 / 就绪 / 重点事件 | `🚀 Play: ...` `🚀 EmitSorting` |
| ▶️ ⏸️ ⏹️ ⏩ ⏪ 🔊 🔇 ❤️ 💔 | 播放控制状态 | `⏸️ (reason) Pause` |
| 🔄 | 同步 / 重置 | `🔄 Player reset` |
| 🐢🐢🐢 | 耗时操作（配合计时） | `... cost 1.2s 🐢🐢🐢` |
| 🐛 | verbose 调试细节 | `🚛 GetAllAudios 🐛 reason` |
| 📋 📄 📥 🎯 | 文件 / 拷贝 / 导入 | `📥 Handling import, count: N` |
| 🗑️ | 删除 / 清除 / 卸载 | `🗑️ Cache cleared` |
| ⏭️ | 跳过 / 忽略 | `⏭️ Skipping disabled plugin` |
| ℹ️ | 中性提示 | `ℹ️ No next audio for current item` |
| 🔍 | 调试 / 详细 | `🔍 Verbose mode enabled` |
| 📣 | 事件分发 | `📣 post event=...` |

> 选择规则：先写语义 emoji，再写动作主语，再写关键上下文（对象名 / 数量 / 原因）。

## 7. 消息内容要求

- **结构**：`emoji + 动作/状态 + 关键上下文`
  - 好：`✅ Sync(\(items.count))`
  - 好：`⏩ (\(reason)) Seeking to \(Int(targetTime))s`
  - 差：`done`、`error happened`
- **上下文**：尽量带对象标识，文件类用 `lastPathComponent` 而非全路径。
- **原因标注**：方法有触发来源时用 `reason:` 参数 + `r("...")` 标记，如 `os_log("\(self.t)🔁 Sort with reason: \(reason)")`。
- **中文或英文均可**，与所在文件注释语言保持一致；emoji 与动作词混排时动作词建议用英文动词短句。

## 8. 计时 / 性能日志

慢操作统一输出耗时，超过 `tolerance` 才打 🐢 标记：

```swift
// 方式一：包一段闭包
func printRunTime(_ title: String, tolerance: Double = 0.1, verbose: Bool = false, _ code: () -> Void)
// 方式二：手动 startTime + jobEnd(startTime:title:tolerance:)
let start = DispatchTime.now()
... 
os_log("\(self.jobEnd(start, title: "\(self.t)✅ Sync(\(items.count))", tolerance: 0.01))")
```

- 耗时阈值建议：DB/IO 类 `0.01~0.1s`，一般操作 `1.0s` 默认。
- 只有**真正可能变慢**的操作才加计时，不要到处加。

## 9. 分层实践速查

| 层 | 日志粒度 | 说明 |
|---|---|---|
| Plugin | 安装/启动/生命周期、对外入口、错误 | `onRegister/onBoot/onReady/onShutdown` 关键节点用 `Self.verbose` 门控 |
| Service / Repo / DB | 每个公开操作入口 + 错误 + 慢操作计时 | 带 `reason:` 记录触发来源 |
| ViewModel | 用户动作、状态切换、失败 | 不在高频轮询/body 求值里打 |
| Observer | 订阅事件触发、异常 | 记录事件名与来源对象 |
| View | 仅用户可感知动作与致命错误 | 避免 `onAppear` 每次渲染都打 |
| Model | Init 关键字段（verbose） | `\(Self.i) -> \(url.lastPathComponent)` |
| Manager | 全局状态变更、关键链路 | 常开 verbose 或直接打印 |

## 10. 反模式（禁止）

1. **用 `print` 打业务日志** —— 统一 `os_log`。
2. **消息里重复类型名/emoji** —— `t` 已包含。
3. **错误日志不带前缀** —— 必须 `\(self.t)` 前缀 + `.error`。
4. **把错误塞进 verbose** —— 错误永远打印。
5. **无 emoji 的长裸文本** —— 首部用语义 emoji 便于检索。
6. **高频循环里打无门控日志** —— 用 `Self.verbose` 包住或移除。
7. **混用多种前缀风格** —— 统一 `\(self.t)` / `\(Self.t)`（静态上下文用 `Self`，实例上下文用 `self`）。
8. **`os_log` 传 `%` 格式化** —— 使用字符串插值即可，避免格式串注入。

## 11. 交付检查清单

- [ ] 类型声明了 `SuperLog`，并定义了 `static let emoji`
- [ ] 声明了 `nonisolated static let verbose`（默认 `false`）
- [ ] 常规日志 `os_log("\(t)...")`，错误日志 `os_log(.error, "\(t)...")`
- [ ] 消息以语义 emoji 开头，含关键上下文（对象/数量/原因）
- [ ] 高频路径已用 verbose 门控；错误与关键状态未门控
- [ ] 慢操作使用 `printRunTime` / `jobEnd` 输出耗时
