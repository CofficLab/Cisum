# TestPlan — ProviderAudioLibrary

## 包概述

ProviderAudioLibrary 定义音频库能力契约(读取、同步、删除、排序)与领域事件,并提供音频仓库路径解析的诊断能力。Kernel 只依赖本协议,不依赖具体仓库实现。

核心组件:
- `AudioLibraryProviding` - 音频库能力协议(`@MainActor`, `Sendable`)
- `AudioLibraryOrderingProviding` - 播放顺序窄协议
- `AudioLibraryProvidingEvent` - 领域事件枚举
- `AudioLibraryProvidingError` - 错误枚举
- `NoopAudioLibraryProvidingObserverHandle` - 默认空实现
- `AudioPluginInfo` - 音频库常量元信息(目录名、扩展名、上限)
- `AudioStorageDiagnostics` - 仓库路径解析诊断

## 公开 API

### AudioLibraryProviding (协议)
属性: `audioDisk`、`supportedExtensions`、`isAvailable`
方法: `totalCount()`、`allURLs(reason:)`、`urls(offset:limit:reason:)`、`contains(_:)`、`delete(urls:verbose:)`、`sync(urls:verbose:isFirst:)`、`sort(url:reason:)`、`sortRandom(url:reason:verbose:)`、`addObserver(_:)`

### AudioLibraryProvidingEvent (枚举)
`syncing`/`synced(totalCount:)`/`updated(totalCount:)`/`deleted(urls:totalCount:)`/`repositoryEmpty`/`repositoryAvailabilityChanged`/`sorting`/`sortCompleted`

### AudioLibraryProvidingError (枚举)
`unavailable`

### AudioPluginInfo
`titleKey`/`descriptionKey`/`maxAudioCount`/`dbDirName`/`debugDBDirName`/`supportedExtensions`/`effectiveDBDirName`(DEBUG→`audios_debug`,Release→`audios`)

### AudioStorageDiagnostics
- 各环节输入字段(存储位置原始值、iCloud 可用性、容器/Documents、storageRoot、audioDisk、dbDirName)
- `failureReason: String?` - 依链路推断的不可用原因
- `summary: String` - 多行诊断文本

## 测试用例清单

| ID | 类别 | 描述 | 前置条件 | 操作步骤 | 预期结果 | 优先级 | 状态 | 测试方法 |
|----|------|------|----------|----------|----------|------|------|----------|
| 1 | 观察者 | 默认 addObserver 返回 NoopHandle 且可重复 cancel | 未实现观察者协议的替身 | addObserver → cancel ×2 | 返回 NoopHandle,不崩溃 | P0 | ✅ 已覆盖 | `audioLibraryDefaultObserverReturnsNoopHandle` |
| 2 | 错误 | `.unavailable` 跨并发边界保留类型 | - | detached task 抛出，调用端捕获 | 精确匹配 `.unavailable` | P1 | ✅ 已覆盖 | `unavailableLibraryErrorIsTransportSafe` |
| 3 | 元信息 | `effectiveDBDirName` 依构建配置切换;扩展名与上限稳定 | - | 检查 DEBUG/Release 分支 | 目录名正确,扩展名列表与 `maxAudioCount>0` | P0 | ✅ 已覆盖 | `audioPluginInfoUsesBuildSpecificRepositoryDirectory` |
| 4 | 诊断 | 仓库不可用时逐环节给出正确 `failureReason` 与 summary | - | 5 组缺失环节用例 | 命中对应人类可读原因,summary 含 `failureReason` | P0 | ✅ 已覆盖 | `audioStorageDiagnosticsExplainsUnavailableRepository` |
| 5 | 诊断 | 仓库就绪时 `failureReason == nil` 且 summary 完整 | - | 提供完整链路 | nil,summary 含 storageRoot/dbDirName | P0 | ✅ 已覆盖 | `audioStorageDiagnosticsHasNoFailureWhenRepositoryIsReady` |
| 6 | 能力 | `totalCount`/`allURLs`/`urls(offset:limit:)`/`contains` 读取正确 | 具体实现 | 填充库后查询 | 返回匹配数量与分页 URL | P1 | ❌ 缺失 | - |
| 7 | 能力 | `delete`/`sync`/`sort`/`sortRandom` 修改库并广播事件 | 具体实现 | 执行操作后订阅 | 库状态变化,对应事件被广播 | P1 | ❌ 缺失 | - |
| 8 | 事件 | 已确认空仓库时订阅立即回放 `repositoryEmpty` | 具体实现 | 订阅空库 provider | 立即收到 `.repositoryEmpty` | P1 | ❌ 缺失 | - |

> 说明:协议数据/事件路径(用例 6-8)由音频数据插件的具体实现承担,本包提供契约、诊断与默认 noop 观察者兜底。

### 新增边界用例

| ID | 描述 | 优先级 | 状态 | 测试方法 |
|----|------|------|------|----------|
| 9 | 本地与自定义存储不依赖 iCloud，就绪摘要不含失败行 | P0 | ✅ 已覆盖 | `nonCloudStorageDoesNotRequireCloudAvailability` |
| 10 | 摘要全部字段、顺序、nil 占位与 Unicode 路径完整 | P1 | ✅ 已覆盖 | `diagnosticsSummaryIncludesEveryFieldAndNilPlaceholder` |
| 11 | iCloud 容器已解析后区分根路径缺失、仓库缺失与就绪 | P0 | ✅ 已覆盖 | `cloudDiagnosticsContinuePastResolvedContainer` |
| 12 | deleted 事件跨任务保留 URL 顺序与剩余数量 | P1 | ✅ 已覆盖 | `deletionEventPreservesURLsAndCountAcrossTaskBoundary` |

> 9 个测试方法已在 macOS Debug 运行，iOS/Release 未实跑。事件传输测试不代替真实仓库删除与广播测试。统计仅表示清单场景，不是源码覆盖率。

## 覆盖率统计

- P0: 已覆盖 6 / 6
- P1: 已覆盖 3 / 6
- **合计: 9 / 12**

## 优先级说明

- **P0**: 默认观察者兜底、元信息稳定、诊断链路推断
- **P1**: 错误传递、数据读取/写入与事件回放
- **P2**: 性能/便利性,可选

## 跨平台说明

- iOS 17+ / macOS 14+ 行为一致;`AudioPluginInfo.effectiveDBDirName` 依构建配置(DEBUG/Release)不同

## 测试执行

```bash
cd Packages/ProviderAudioLibrary
swift test
```

## 维护规则

1. **新增公开 API** → 先在 TestPlan 登记测试用例,再写实现
2. **Bug 修复** → 追加回归用例,标注触发条件
3. **删除用例** → 在 commit message 说明理由
4. **状态同步** → 实现后更新 TestPlan,标记 ✅ 并填写测试方法名
