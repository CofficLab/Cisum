# Swift 日志记录规范

> 本规范定义了 Cisum 项目中 Swift 代码的日志记录方式和标准。

---

## 核心原则

**使用 `os.Logger` 进行日志记录，统一日志格式和调试体验。禁止使用 `os_log`。**

所有日志输出必须加 `self.t` 或 `Self.t` 前缀（来自 SuperLog），用于统一格式。

### 通过抽象协议输出日志（适配器模式）

当代码不直接依赖 `os.Logger`、而是通过自定义日志协议（如 `RAGLogger`）解耦时，前缀由 **Plugin 层提供的具体适配器统一注入**，协议调用点无需各自加前缀。适配器实现必须自行加上所属插件/类型的 `.t` 前缀：

```swift
// ✅ 适配器统一加前缀，被适配的代码无需感知
struct OSLogRAGLogger: RAGLogger {
    func info(_ message: String) { RAGPlugin.logger.info("\(RAGPlugin.t)\(message)") }
    func error(_ message: String) { RAGPlugin.logger.error("\(RAGPlugin.t)\(message)") }
    func warning(_ message: String) { RAGPlugin.logger.warning("\(RAGPlugin.t)\(message)") }
}
```

---

## Import 要求

```swift
import os  // ✅ 使用 os.Logger，不使用 import OSLog
```

---

## Logger 分配规则

### 1. Core 模块

使用 `AppLogger.core`（定义在 `LumiApp/Core/Bootstrap/AppLogger.swift`）：

```swift
// 实现 SuperLog 的类型，日志前加 self.t 前缀
AppLogger.core.info("\(self.t)操作完成")
AppLogger.core.error("\(self.t)加载失败：\(error.localizedDescription)")
AppLogger.core.warning("\(self.t)使用备选数据")
```

### 2. Plugin 模块

在主插件文件中定义 logger，工具/服务等子文件使用插件 logger：

```swift
// 主插件文件（如 GitHubToolsPlugin.swift）
import os

actor GitHubToolsPlugin: SuperPlugin, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.cisum", category: "plugin.github-tools")
    nonisolated static let emoji = "🐙"
    // ...
}

// 插件内的 Tool/Service 使用（实例方法用 self.t，静态方法用 Self.t）
GitHubToolsPlugin.logger.info("\(self.t)获取仓库信息：\(owner)/\(repo)")
GitHubToolsPlugin.logger.error("\(self.t)请求失败：\(error.localizedDescription)")
```

### 3. LLM Provider / 独立类

在类型内部定义私有 logger：

```swift
import os

final class AnthropicProvider: SuperLLMProvider, SuperLog {
    private static let logger = Logger(subsystem: "com.coffic.cisum", category: "llm.anthropic")
    nonisolated static let emoji = "🤖"

    func transformMessage(_ message: ChatMessage) {
        if Self.verbose {
            Self.logger.info("\(self.t)消息包含 \(message.images.count) 张图片")
        }
    }
}
```

### 4. 扩展 / Finder 等

使用所属模块的 logger，并添加 `import os`：

```swift
import os

extension FinderSync {
    func openInVSCode(_ sender: AnyObject?) {
        if Self.verbose {
            FinderSync.logger.info("\(self.t)触发操作")
        }
    }
}
```

---

## 日志级别

| 级别 | 方法 | 用途 |
|------|------|------|
| 信息 | `logger.info(...)` | 正常流程、操作记录 |
| 警告 | `logger.warning(...)` | 非错误但需关注的情况 |
| 错误 | `logger.error(...)` | 错误、异常、失败 |
| 严重 | `logger.critical(...)` | 严重错误 |

---

## Logger 定义格式

```swift
// subsystem 固定为 "com.coffic.cisum"
// category 按模块命名：
//   - 插件："plugin.xxx"（如 plugin.github-tools, plugin.network）
//   - LLM: "llm.xxx"（如 llm.anthropic, llm.mlx）
//   - Finder: "finder"
private static let logger = Logger(subsystem: "com.coffic.cisum", category: "plugin.xxx")
```

---

## 常见模式

### Plugin Tool 日志

```swift
struct GitHubSearchTool: AgentTool, SuperLog {
    nonisolated static let emoji = "🔍"
    nonisolated static let verbose = false

    func execute(arguments: [String: ToolArgument]) async throws -> String {
        if Self.verbose {
            GitHubToolsPlugin.logger.info("\(self.t)搜索：\(query)")
        }
        // ...
    }
}
```

### Service 日志

```swift
class NetworkService: SuperLog {
    nonisolated static let emoji = "🌐"

    func fetchData() {
        if Self.verbose {
            NetworkManagerPlugin.logger.info("\(self.t)开始请求")
        }
        // ...
    }
}
```

### 错误与警告

```swift
do {
    try await performTask()
} catch {
    PluginName.logger.error("\(self.t)任务失败：\(error.localizedDescription)")
    throw error
}

// 警告
if !isValid {
    PluginName.logger.warning("\(self.t)使用默认配置")
}
```

---

## SuperLog 协议与 t 前缀

实现 `SuperLog` 的类型可获得 `emoji`、`t` 和 `verbose` 用于日志。

**日志输出必须加 `self.t` 或 `Self.t` 前缀**，格式为 `[QoS] | emoji TypeName | `，便于在 Console 中按线程、类型过滤：

- **实例方法**：使用 `self.t`
- **静态方法**：使用 `Self.t`
- **闭包中（如 Task.detached、weak self）**：使用 `TypeName.t`

```swift
struct MyTool: AgentTool, SuperLog {
    nonisolated static let emoji = "📋"
    nonisolated static let verbose = false

    func execute() {
        if Self.verbose {
            MyPlugin.logger.info("\(self.t)执行操作")
        }
    }
}

// 闭包内无 self 时（如 Task.detached），用类型名获取前缀
Task.detached {
    NetworkManagerPlugin.logger.error("\(NetworkHistoryService.t)后台保存失败：\(error)")
}
```

---

## 禁止事项

1. **禁止使用 os_log**
   - ❌ `os_log("...")`
   - ❌ `os_log(.error, "...")`
   - ✅ `logger.info(...)` / `logger.error(...)`

2. **禁止 import OSLog**
   - ✅ `import os`
   - ⚠️ **唯一例外**：需要直接访问 `OSLogStore` / `OSLogEntry` / `OSLogEntryLog` 等类型时（如 `FileLogCoordinator` 实现磁盘日志持久化），允许 `import OSLog`。仅用于日志输出（`Logger` / `os.Logger`）时仍必须用 `import os`。

3. **禁止记录敏感信息**
   - ❌ 密码、Token、API Key
   - ✅ 只记录操作结果或脱敏信息

---

## 日志过滤

通过 Console.app 或 `log stream` 可按住户定义：

```bash
# 按子系统过滤
log stream --predicate 'subsystem == "com.coffic.cisum"'

# 按 category 过滤
log stream --predicate 'subsystem == "com.coffic.cisum" AND category == "plugin.github-tools"'
```

---

## Emoji 选择指南

| Emoji | 用途 |
|-------|------|
| 🐙 | GitHub |
| 📁 | 文件/目录 |
| 💾 | 内存/存储 |
| 🔌 | 端口/网络 |
| 🤖 | Anthropic |
| 🔴 | Zhipu |
