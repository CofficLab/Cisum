# TestPlan — ProviderCloudDownload

## 包概述

ProviderCloudDownload 广播 iCloud 文件的下载进度。采用「全局广播、不订阅具体 URL」模型:底层 `NSMetadataQuery` 只回传正在下载的文件,数据量天然极小。核心不变式是**身份按完整路径比对**与**进度只升不降**。

核心组件:
- `CloudDownloadProviding` - 下载进度能力协议(`@MainActor`, `Sendable`)
- `CloudDownloadEvent` - 进度事件枚举(`progressChanged(url:progress:)`)
- `CloudDownloadProvidingObserverHandle` / `NoopCloudDownloadProvidingObserverHandle`
- `CloudDownloadService` - 生产实现(订阅即建连)
- `CloudDownloadIdentity`(internal)- URL/查询结果统一身份键
- `CloudDownloadProgressPolicy`(internal)- 进度归一化与单调合并

## 公开 API

### CloudDownloadProviding (协议)
- `addObserver(_:) -> CloudDownloadProvidingObserverHandle`(`@discardableResult`,默认返回 NoopHandle)
- `progress(for url: URL) -> Double`(已下载/非 iCloud→`1.0`,无法判定→`0`)

### CloudDownloadIdentity (internal)
- `key(for url: URL) -> String` - 标准化绝对路径
- `key(for item: NSMetadataItem) -> String?` - 取 `NSMetadataItemPathKey`,缺失返回 nil(不降级猜测)

### CloudDownloadProgressPolicy (internal)
- `normalized(_:) -> Double` - 夹取到 `0...1`,非有限值归 `0`
- `merged(current:incoming:) -> Double` - 单调取大,任一源读到 0 不打回

## 测试用例清单

| ID | 类别 | 描述 | 前置条件 | 操作步骤 | 预期结果 | 优先级 | 状态 | 测试方法 |
|----|------|------|----------|----------|----------|------|------|----------|
| 1 | 身份 | key 使用标准化绝对路径 | - | `/tmp/./sub/../intro.mp3` | `/tmp/intro.mp3` | P0 | ✅ 已覆盖 | `keyUsesStandardizedAbsolutePath` |
| 2 | 身份 | 不同目录同名文件身份不同(避免串扰) | - | 比对 Music/Downloads 下同名 | 两个 key 不相等 | P0 | ✅ 已覆盖 | `keyDistinguishesSameNameInDifferentDirectories` |
| 3 | 身份 | 两侧(item / url)归一化方式一致 | - | 从真实 NSMetadataItem 与 URL 分别取键 | 路径一致；缺少 item 路径时返回 nil | P0 | 🟡 部分覆盖：现有测试只调用 URL 重载 | `keyFromItemNormalizesTheSameWayAsKeyFromURL` |
| 4 | 进度 | normalized 夹取越界值 | - | -1 / 0.5 / 2 | 0 / 0.5 / 1 | P0 | ✅ 已覆盖 | `normalizedClampsOutOfRangeValues` |
| 5 | 进度 | normalized 拒绝非有限值 | - | NaN / Infinity | 0 | P0 | ✅ 已覆盖 | `normalizedRejectsNonFiniteValues` |
| 6 | 进度 | merged 永不回退(核心不变式) | - | (0.5,0)/(0.5,0.8)/(1,0.2) | 0.5 / 0.8 / 1 | P0 | ✅ 已覆盖 | `mergedNeverRegresses` |
| 7 | 进度 | merged 两侧同时归一化 | - | (NaN,0.4) | 0.4 | P1 | ✅ 已覆盖 | `mergedNormalizesBothSides` |
| 8 | 观察者 | 默认 addObserver 返回 NoopHandle 且可重复 cancel | 未实现观察者协议的替身 | addObserver → cancel ×2 | 返回 NoopHandle,不崩溃 | P0 | ✅ 已覆盖 | `defaultObserverUsesNoopFallback` / `explicitNoopHandleSupportsRepeatedCancellation` |
| 9 | 服务 | 订阅后 cancel 不再收到事件 | 生产 `CloudDownloadService` | 取消前后各注入一个下载事件 | 只收到取消前的事件 | P1 | 🟡 部分覆盖：现有测试仅订阅后立即取消并检查空数组，未触发事件 | `serviceForwardsEventsToSubscribersUntilCancelled` |
| 10 | 服务 | 非 iCloud 本地文件快照判为完成 | 生产实现 | 对本地文件读 `progress(for:)` | `1.0` | P1 | ✅ 已覆盖 | `snapshotTreatsNonICloudFileAsComplete` |
| 11 | 服务 | 正在下载文件推送真实百分比并经 merged 单调发布 | 需 iCloud 下载环境 | 订阅后系统推送进度 | 进度只升不降地转发 | P2 | ❌ 缺失 | - (依赖真实 iCloud 下载,CI 无法覆盖) |

## 覆盖率统计

- P0: 已覆盖 6 / 7，部分覆盖 1 项
- P1: 已覆盖 2 / 3，部分覆盖 1 项
- P2: 已覆盖 0 / 1（下载集成场景）
- **合计: 完整覆盖 8 / 11，部分覆盖 2 项，缺失 1 项**

## 优先级说明

- **P0**: 身份归一化、进度夹取/单调、默认观察者兜底
- **P1**: 生产实现的订阅/取消与本地文件快照
- **P2**: 真实下载进度转发(需 iCloud 环境)

## 跨平台说明

- iCloud 下载进度依赖 `NSMetadataQuery`,仅在具备 iCloud 能力的平台生效
- 身份/进度策略为纯函数,iOS 17+ / macOS 14+ 一致

## 测试执行

```bash
cd Packages/ProviderCloudDownload
swift test
```

## 维护规则

1. **新增公开 API** → 先在 TestPlan 登记测试用例,再写实现
2. **Bug 修复** → 追加回归用例,标注触发条件
3. **删除用例** → 在 commit message 说明理由
4. **状态同步** → 实现后更新 TestPlan,标记 ✅ 并填写测试方法名
