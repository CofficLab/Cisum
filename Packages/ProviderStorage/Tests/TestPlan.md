# TestPlan — ProviderStorage

## 包概述

ProviderStorage 定义应用持久化存储位置能力,统一描述数据可落入的根位置(iCloud / 本地 / 自定义),并广播存储位置变更事件。

核心组件:
- `StorageLocation` - 存储位置枚举(String / Sendable / Codable / CaseIterable)
- `StorageProviding` - 存储服务能力协议(`@MainActor` + `ObservableObject`)
- `StorageProvidingEvent` - 存储变更事件枚举(`locationChanged` / `storageAvailabilityChanged`)
- `StorageProvidingObserverHandle` - 观察者句柄协议
- `NoopStorageProvidingObserverHandle` - 默认空实现
- 扩展: `EventObserverHandle` 遵循 `StorageProvidingObserverHandle`

## 公开 API

### StorageLocation (枚举)
- Cases: `icloud`、`local`、`custom`(rawValue 与历史 `UserDefaults["StorageLocation"]` 键保持向后兼容)
- `emojiTitle: String` - 带 emoji 的展示标题
- `emoji: String` - 仅 emoji
- `title: String` - 不含 emoji 的标题
- `description: String` - 人类可读描述

### StorageProviding (协议, `@MainActor`)
属性:
- `currentStorageLocation: StorageLocation?`
- `storageRoot: URL?`
- `hasUsableStorageLocation: Bool`
- `isICloudStorageAvailable: Bool`
- `databaseRoot: URL`

方法:
- `storageRoot(for:) -> URL?`
- `databaseFile(name:) throws -> URL`
- `pluginDataDirectory(for:) -> URL`
- `setStorageLocation(_:)`
- `resetStorageLocation()`
- `addObserver(_:) -> StorageProvidingObserverHandle`(`@discardableResult`,默认返回 NoopHandle)

### StorageProvidingEvent (枚举, `@MainActor`)
- `locationChanged(StorageLocation?)`
- `storageAvailabilityChanged`

### NoopStorageProvidingObserverHandle
- `init()`
- `cancel()`(幂等)

## 测试用例清单

| ID | 类别 | 描述 | 前置条件 | 操作步骤 | 预期结果 | 优先级 | 状态 | 测试方法 |
|----|------|------|----------|----------|----------|------|------|----------|
| 1 | 枚举 | 各 case 的展示属性与持久化 rawValue 稳定 | - | 检查 `rawValue` / `emojiTitle` / `emoji` / `title` / `description` | 返回预设字符串 | P0 | ✅ 已覆盖 | `storageLocationPresentationAndPersistedValueRemainStable` |
| 2 | 枚举 | Codable 往返一致 | - | encode → decode | 等于原值 | P0 | ✅ 已覆盖 | `storageLocationPresentationAndPersistedValueRemainStable` |
| 3 | 枚举 | 历史 rawValue 可解码(向后兼容) | - | 用 `"icloud"`/`"local"`/`"custom"` 解码 | 映射到对应 case | P0 | ✅ 已覆盖 | `storageLocationDecodesLegacyRawValues` |
| 4 | 协议 | 默认 addObserver 返回 NoopHandle | 未实现观察者方法的替身 | 调 `addObserver { _ in }` | 返回 `NoopStorageProvidingObserverHandle` | P0 | ✅ 已覆盖 | `defaultStorageObserverUsesNoopFallback` |
| 5 | 协议 | NoopHandle 可重复取消 | - | 调 `cancel()` 两次 | 不崩溃 | P0 | ✅ 已覆盖 | `explicitStorageNoopSupportsRepeatedCancellation` |
| 6 | 事件 | `locationChanged` 事件携带新位置 | - | 发送 `.locationChanged(.icloud)` | 观察者收到对应位置 | P1 | ❌ 缺失 | - |
| 7 | 能力 | `storageRoot(for:)` 依位置解析根 URL | 具体实现 | 传入 `.local` / `.icloud` | 返回对应根 URL,不可用时 nil | P1 | ❌ 缺失 | - |
| 8 | 能力 | `databaseFile(name:)` 生成 `<name>/<name>.db` 并按需建目录 | 具体实现 | 调用并检查父目录 | 返回文件 URL 且目录已创建 | P1 | ❌ 缺失 | - |
| 9 | 能力 | `pluginDataDirectory(for:)` 返回插件专属目录 | 具体实现 | 传入 pluginID | 返回 `<databaseRoot>/<pluginID>/` | P1 | ❌ 缺失 | - |
| 10 | 能力 | `setStorageLocation` 持久化并广播事件 | 具体实现 | 设置位置后订阅 | 事件被广播且配置持久化 | P1 | ❌ 缺失 | - |
| 11 | 解码 | 拒绝未知值、错误大小写及非字符串 JSON | - | 解码六种非法负载 | 抛出 DecodingError | P0 | ✅ 已覆盖 | `storageLocationRejectsInvalidPersistedValues` |
| 12 | 枚举 | 选项顺序稳定且未知 rawValue 不回落 | - | 检查 allCases 和未知值 | 顺序 icloud/local/custom，未知值 nil | P1 | ✅ 已覆盖 | `storageLocationCaseOrderRemainsStable` |

> 用例 6-10 涉及具体存储实现，仍标为本包缺失；协议替身不用于证明持久化或事件广播。6 个测试方法已在 macOS 运行，iOS 未实跑。以下仅统计清单场景，不是源码覆盖率。

## 覆盖率统计

- P0: 已覆盖 6 / 6
- P1: 已覆盖 1 / 6
- **合计: 7 / 12**

## 优先级说明

- **P0**: 枚举契约(展示/持久化稳定)与默认观察者兜底,必须覆盖
- **P1**: 协议能力路径(根 URL、数据库文件、插件目录、事件广播),建议覆盖
- **P2**: 性能/便利性,可选

## 跨平台说明

- iOS 17+ / macOS 14+ 行为一致;`StorageLocation` 为纯 Swift 枚举,无平台差异
- `storageRoot`/iCloud 可用性由具体实现依赖系统 API,协议本身跨平台

## 测试执行

```bash
cd Packages/ProviderStorage
swift test
```

## 维护规则

1. **新增公开 API** → 先在 TestPlan 登记测试用例,再写实现
2. **Bug 修复** → 追加回归用例,标注触发条件
3. **删除用例** → 在 commit message 说明理由
4. **状态同步** → 实现后更新 TestPlan,标记 ✅ 并填写测试方法名
