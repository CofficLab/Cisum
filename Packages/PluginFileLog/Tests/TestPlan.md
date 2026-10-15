# TestPlan — PluginFileLog

## 包概述

PluginFileLog 提供基于文件的日志记录功能,支持日志轮转、大小管理、应用终止时的清理。

核心组件:
- `FileLogPlugin` - 插件主入口
- `FileLogCoordinator` - 日志协调器(单例,管理日志文件创建和轮转)
- `FileLogConfiguration` - 日志配置协议
- `FileLogRotation` - 日志轮转逻辑
- `FileLogFileSizePolicy` - 基于文件大小的轮转策略
- `FileLogTerminationObserver` - 应用终止监听(macOS only)

## 公开 API

### FileLogPlugin
- `init()`
- `boot(context:)` - 启动日志协调器
- `shutdown()` - 停止日志协调器
- `contributesMetadata()` - 返回插件元数据
- `contributesSettings()` - 返回插件设置(About/Manual 页面)

### FileLogCoordinator
- `shared` - 单例
- `configuration: FileLogConfiguration` - 可设置配置
- `start()` - 启动日志(创建目录和文件)
- `stop()` - 停止日志
- `log(level:message:)` - 记录日志

### FileLogConfiguration (协议)
- `logsDirectory() -> URL` - 返回日志目录

### DefaultFileLogConfiguration
- `init()`
- `logsDirectory() -> URL` - 返回默认日志目录(FileLog)

### FileLogRotation
- `uniqueLogFileURL(baseName:in:fileExists:) -> URL` - 生成唯一日志文件 URL

### FileLogFileSizePolicy
- `fileSize(from:) -> Int?` - 从文件属性读取大小
- `rotationPredicate(maxFileSize:) -> (URL) -> Bool` - 返回轮转判断闭包

### FileLogTerminationObserver (macOS only)
- `start(notificationCenter:stop:)` - 监听 willTerminateNotification
- `stopObserving(notificationCenter:)` - 移除监听

## 测试用例清单

| ID | 类别 | 描述 | 前置条件 | 操作步骤 | 预期结果 | 状态 | 测试方法 |
|----|------|------|----------|----------|----------|------|----------|
| 1 | 配置 | 默认配置返回 FileLog 目录 | - | 调用 `DefaultFileLogConfiguration().logsDirectory()` | URL 最后一部分为 "FileLog" | ✅ 已覆盖 | `defaultConfigurationReturnsFileLogDirectory` |
| 2 | 轮转 | 时间戳已存在时生成唯一文件名 | 存在 `2026-05-31_15-00-00.log` | 调用 `uniqueLogFileURL(baseName:in:)` | 返回 `2026-05-31_15-00-00 2.log` | ✅ 已覆盖 | `logRotationUsesUniqueNameWhenTimestampAlreadyExists` |
| 3 | 轮转 | 空 baseName 使用可读回退名 | - | 调用 `uniqueLogFileURL(baseName: "", in:)` | 返回 `Cisum Log.log` | ✅ 已覆盖 | `logRotationUsesReadableFallbackForEmptyBaseName` |
| 4 | 轮转 | 跳过悬空符号链接 | 存在悬空 symlink `2026-05-31_15-00-00.log` | 调用 `uniqueLogFileURL` | 返回 `2026-05-31_15-00-00 2.log` | ✅ 已覆盖 | `logRotationSkipsDanglingSymlinkNames` |
| 5 | 策略 | fileSize 读取 NSNumber 属性 | - | 调用 `fileSize(from: [.size: NSNumber(1234)])` | 返回 1234 | ✅ 已覆盖 | `fileLogFileSizePolicyReadsFoundationNumberAttributes` |
| 6 | 策略 | fileSize 处理 Int64 和 Int | - | 调用 `fileSize(from: [.size: Int64(5678)])` | 返回 5678 | ✅ 已覆盖 | `fileLogFileSizePolicyReadsFoundationNumberAttributes` |
| 7 | 策略 | fileSize 处理负数 | - | 调用 `fileSize(from: [.size: NSNumber(-1234)])` | 返回 0 | ✅ 已覆盖 | `fileLogFileSizePolicyNormalizesInvalidSizes` |
| 8 | 策略 | fileSize 处理超大值 | - | 调用 `fileSize(from: [.size: Int64.max])` | 返回 Int.max | ✅ 已覆盖 | `fileLogFileSizePolicyNormalizesInvalidSizes` |
| 9 | 策略 | fileSize 处理缺失属性 | - | 调用 `fileSize(from: [:])` | 返回 nil | ✅ 已覆盖 | `fileLogFileSizePolicyNormalizesInvalidSizes` |
| 10 | 终止监听 | start 幂等且可移除 (macOS) | - | 调用 `start` 两次,post willTerminateNotification | stop 只调用 1 次 | ✅ 已覆盖 | `terminationObserverIsIdempotentAndRemovable` |
| 11 | 终止监听 | stopObserving 后不再监听 (macOS) | 已 start | 调用 `stopObserving`,post notification | stop 不再调用 | ✅ 已覆盖 | `terminationObserverIsIdempotentAndRemovable` |
| 12 | 协调器 | start 创建日志目录和文件 | - | 调用 `coordinator.start()` | 目录存在,包含 .log 文件 | ✅ 已覆盖 | `coordinatorStartCreatesLogDirectoryAndFile` |
| 13 | 协调器 | start 幂等(重复调用不创建多个文件) | 已 start | 再次调用 `start()` | 日志文件数 ≤ 2(轮转一次) | ✅ 已覆盖 | `coordinatorStartIsIdempotent` |
| 14 | 协调器 | stop 安全且刷新日志 | - | 调用 `start()`,等待,`stop()` 两次 | 日志文件存在 | ✅ 已覆盖 | `coordinatorStopIsSafeAndFlushes` |
| 15 | 插件 | boot 启动协调器 | - | 创建 `FileLogPlugin`,调用 `boot(context:)` | 协调器已启动 | ⚠️ 不可测试 | 需要 mock KernelCoreContainer(final class),无法单元测试 |
| 16 | 插件 | shutdown 停止协调器 | 已 boot | 调用 `shutdown()` | 协调器已停止 | ⚠️ 不可测试 | 需要 mock KernelCoreContainer(final class),无法单元测试 |
| 17 | 插件 | contributesMetadata 返回正确元数据 | - | 调用 `contributesMetadata()` | 包含 id, version, description | ✅ 已覆盖 | `pluginMetadataIsCorrect` |
| 18 | 插件 | contributesSettings 返回 About/Manual 页面 | - | 调用 `contributesSettings()` | 返回 2 个设置项 | ⚠️ 不可测试 | 需要 mock DocsViewProviding,无法单元测试 |
| 19 | 轮转 | 多个文件已存在时生成正确序号 | 存在 `test.log`, `test 2.log` | 调用 `uniqueLogFileURL(baseName: "test", in:)` | 返回 `test 3.log` | ✅ 已覆盖 | `rotationGeneratesCorrectSequenceWithMultipleFiles` |
| 19b | 轮转 | 更多序号测试 | 存在 `log.log` 到 `log 5.log` | 调用 `uniqueLogFileURL(baseName: "log", in:)` | 返回 `log 6.log` | ✅ 已覆盖 | `rotationGeneratesCorrectSequenceWithManyFiles` |
| 19c | 轮转 | 空目录测试 | 目录为空 | 调用 `uniqueLogFileURL(baseName: "empty", in:)` | 返回 `empty.log` | ✅ 已覆盖 | `rotationInEmptyDirectory` |
| 20 | 协调器 | log 方法写入文件 | 已 start | 调用 `log(level: .info, message: "test")` | 日志文件包含 "test" | ⚠️ 不可测试 | FileLogCoordinator 没有公开的 log 方法,它从 OSLogStore 读取日志 |
| 21 | 协调器 | 文件大小超过阈值时轮转 | maxFileSize=100, 当前文件 150 字节 | 调用 `log()` | 创建新日志文件 | ⚠️ 不可测试 | maxFileSize 是 private 的,无法在测试中修改 |

## 覆盖率统计

- P0 (核心功能): 14/14 ✅
- P1 (边界情况): 0/3
- P2 (集成场景): 0/4

**总计: 14/21 (67%)**

## 优先级说明

- **P0**: 核心功能,必须覆盖(配置、轮转、策略、终止监听、协调器生命周期)
- **P1**: 边界情况,建议覆盖(多文件序号、元数据、设置项)
- **P2**: 集成场景,可选覆盖(插件 boot/shutdown、日志写入、大小轮转)

## 跨平台说明

- `FileLogTerminationObserver` 仅在 macOS 上可用(依赖 AppKit 的 NSApplication.willTerminateNotification)
- 其他功能在 iOS 和 macOS 上行为一致

## 测试执行

```bash
cd Packages/PluginFileLog
swift test
```

## 维护规则

1. **新增公开 API** → 先在 TestPlan 登记测试用例,再写实现
2. **Bug 修复** → 追加回归用例,标注触发条件
3. **删除用例** → 在 commit message 说明理由
4. **状态同步** → 实现后更新 TestPlan,标记 ✅ 并填写测试方法名
