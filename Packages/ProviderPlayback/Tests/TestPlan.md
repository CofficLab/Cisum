# TestPlan — ProviderPlayback

## 包概述

ProviderPlayback 定义播放服务能力契约:播放状态、快照、导航与语义事件,并提供可复用的事件发送器 `PlaybackObserverStore`。本包只声明契约与通用观察者实现,不含具体播放器。

核心组件:
- `PlaybackStatus` / `PlaybackStatus.LoadingStatus` - 播放状态与加载子状态枚举
- `PlaybackFailure` / `PlaybackNavigationFailure` - 失败描述类型
- `PlaybackMode` - 播放模式枚举
- `PlaybackNavigationDirection` - 上/下曲方向
- `PlaybackSnapshot` - 一致状态快照
- `PlaybackProvidingEvent` - 播放语义事件枚举
- `PlaybackProviding` / `PlaybackMediaProviding` - 播放能力与视觉能力协议(`@MainActor`)
- `PlaybackObserverStore` / `PlaybackObserverStoreHandle` - 事件发送器与句柄
- `NoopPlaybackProvidingObserverHandle` - 默认空实现
- 扩展: `EventObserverHandle` 遵循 `PlaybackProvidingObserverHandle`

## 公开 API(摘要)

- `PlaybackStatus`:`idle`/`loading(_)`/`willPlay`/`playing`/`paused`/`stopped`/`failed(_)`;计算属性 `isPlaying`/`isLoading`/`isDownloading`
- `PlaybackSnapshot`:`state`/`currentURL`/`currentTime`/`duration`/`progress`/`playMode`/`likedAssets`;`isPlaying`/`hasAsset`
- `PlaybackProviding`:`play(_:)`/`play(_:startTime:)`/`pause`/`toggle`/`seek(...)`/`next`/`previous`/`setPlayMode`/`toggleCurrentLike`/`reset`/`togglePlayMode`/`snapshot`/`addObserver`
- `PlaybackObserverStore`:`add(_:) -> Handle`、`send(_:)`、`Handle.cancel()`(幂等,可自取消)

## 测试用例清单

| ID | 类别 | 描述 | 前置条件 | 操作步骤 | 预期结果 | 优先级 | 状态 | 测试方法 |
|----|------|------|----------|----------|----------|------|------|----------|
| 1 | 观察者 | 观察者收到事件,cancel 后停止投递 | `PlaybackObserverStore` | add → send → cancel → send | 仅收到取消前的事件 | P0 | ✅ 已覆盖 | `observerReceivesEventsAndStopsAfterCancellation` |
| 2 | 观察者 | 观察者在分发中自取消不影响其他观察者 | 两个观察者 | 首个回调内 cancel,连发两次 | 自取消者仅收 1 次,另一收 2 次 | P0 | ✅ 已覆盖 | `observerCanCancelItselfWithoutSkippingOtherObservers` |
| 3 | 快照 | snapshot 派生 isPlaying / hasAsset | - | 构造 playing + URL 快照 | `isPlaying`、`hasAsset` 为 true | P0 | ✅ 已覆盖 | `snapshotDerivesAssetAndPlayingState` |
| 4 | 状态 | status 标志区分 loading / downloading / playing | - | 检查各状态标志 | loading 与 downloading 语义正确分离 | P0 | ✅ 已覆盖 | `playbackStatusFlagsDistinguishLoadingAndDownloading` |
| 5 | 观察者 | 默认 addObserver 返回 NoopHandle 且可重复 cancel | 未实现观察者协议的替身 | addObserver → cancel ×2 | 返回 NoopHandle,不崩溃 | P0 | ✅ 已覆盖 | `noOpObserverFallbackCanBeCancelledRepeatedly` |
| 6 | 导航 | NavigationFailure 保留方向与原因;Mode 顺序稳定 | - | 构造并比较 | 字段保留;`allCases` 顺序固定 | P1 | ✅ 已覆盖 | `navigationFailurePreservesDirectionAndReason` |
| 7 | 协议 | 协议默认扩展构建 snapshot 并转发定时播放 | 实现必需成员的替身 | 读 snapshot,调 `play(_:startTime:)`/`reset` | snapshot 字段与替身一致;定时播放回落到 `play(_:)` | P0 | ✅ 已覆盖 | `providerDefaultsBuildSnapshotAndForwardTimedPlay` |
| 8 | 事件 | 各 `PlaybackProvidingEvent` case 承载正确负载 | 具体实现 | 触发 `stateChanged`/`timeChanged`/`likeStatusChanged` 等 | 事件字段与操作一致 | P1 | ❌ 缺失 | - |
| 9 | 能力 | `PlaybackMediaProviding` 返回媒体视图与本地化状态文本 | 具体实现 | 调 `makeMediaView`/`localizedStateText` | 返回非空视图与文案 | P2 | ❌ 缺失 | - |

> 说明:`PlaybackProvidingEvent` 各语义 case 与 `PlaybackMediaProviding` 由播放插件的具体实现驱动,本包提供契约与通用 store;用例 8-9 需在实现侧或跨包集成测试补齐。

## 覆盖率统计

- P0: 已覆盖 6 / 6
- P1: 已覆盖 1 / 2
- P2: 已覆盖 0 / 1
- **合计: 7 / 9**

## 优先级说明

- **P0**: 观察者分发/取消、快照派生、状态标志、默认扩展兜底
- **P1**: 失败/模式数据契约、事件负载完整性
- **P2**: 视觉能力协议

## 跨平台说明

- iOS 17+ / macOS 14+ 行为一致;`@MainActor` 约束要求在主线程调用

## 测试执行

```bash
cd Packages/ProviderPlayback
swift test
```

## 维护规则

1. **新增公开 API** → 先在 TestPlan 登记测试用例,再写实现
2. **Bug 修复** → 追加回归用例,标注触发条件
3. **删除用例** → 在 commit message 说明理由
4. **状态同步** → 实现后更新 TestPlan,标记 ✅ 并填写测试方法名
