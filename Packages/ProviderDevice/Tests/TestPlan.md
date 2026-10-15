# Test Plan: ProviderDevice

> 本文件是该包的**测试用例清单**,作为测试覆盖的"地图"使用。
> 与 `Tests/` 下的 Swift 测试一一对应;Swift 文件是"实现",本文件是"规格"。

## 包概览

- **包名**: `ProviderDevice`
- **平台**: macOS 14+ / iOS 17+
- **公开 API**:
  - `DeviceProvidingEvent` enum (单 case: `.deviceChanged`)
  - `DeviceProvidingObserverHandle` protocol
    - `cancel()`
  - `DeviceProviding` protocol (ObservableObject)
    - Properties: `isMac`, `isIOS`, `isPad`, `deviceModel`, `systemVersion`, `screenWidth`, `screenHeight`
    - Method: `addObserver(_:) -> DeviceProvidingObserverHandle` (`@discardableResult`)
  - `NoopDeviceProvidingObserverHandle` class (默认 noop 实现)
  - Extension: `EventObserverHandle` 遵循 `DeviceProvidingObserverHandle`
- **线程模型**: `@MainActor` — 调用必须在主线程
- **核心契约**: 默认 `addObserver` 返回 noop handle;协议扩展提供默认实现;`EventObserverHandle` 可直接作为设备观察者 handle

## 用例清单

| 编号 | 用例名 | 描述 | 操作步骤 | 预期结果 | 优先级 | 平台 | 状态 | 覆盖于 |
|---|---|---|---|---|---|---|---|---|
| TC-01 | 默认 addObserver 返回 NoopDeviceProvidingObserverHandle | 未实现协议的 stub 调用 addObserver | 1) `let handle = provider.addObserver { _ in }` | `handle is NoopDeviceProvidingObserverHandle` | P0 | iOS / macOS | ✅ 已覆盖 | `defaultObserverUsesNoopFallback` |
| TC-02 | Noop handle 重复 cancel 幂等 | 同一 noop handle 连续 cancel 两次 | 1) `let handle = NoopDeviceProvidingObserverHandle()`<br>2) `handle.cancel()`<br>3) `handle.cancel()` | 不崩溃 | P0 | iOS / macOS | ✅ 已覆盖 | `explicitNoopHandleSupportsRepeatedCancellation` |
| TC-03 | 观察者回调能收到 DeviceProvidingEvent | 实现协议的 stub 调用 addObserver,触发事件 | 1) 注册 observer<br>2) 触发 `send(.deviceChanged)`<br>3) 检查回调 | 回调收到 `.deviceChanged` | P0 | iOS / macOS | ✅ 已覆盖 | `observerCallbackReceivesEvent` |
| TC-04 | 观察者 handle cancel 后停止投递 | 注册后 cancel,再 send | 1) `addObserver { ... }`<br>2) `send(.deviceChanged)` 收到<br>3) `handle.cancel()`<br>4) `send(.deviceChanged)` | 第二次 send 不再触发回调 | P0 | iOS / macOS | ✅ 已覆盖 | `observerHandleCancelStopsDelivery` |
| TC-05 | 多观察者同时收到同一事件 | 注册 2 个观察者,send 1 次 | 1) 注册 A、B<br>2) `send(.deviceChanged)` | A 和 B 各收到 1 次 | P0 | iOS / macOS | ✅ 已覆盖 | `multipleObserversReceiveSameEvent` |
| TC-06 | EventObserverHandle 可作为 DeviceProvidingObserverHandle 使用 | 用 KitEventObservation 的 handle 调 cancel | 1) `let store = EventObserverStore<DeviceProvidingEvent>()`<br>2) `let handle: DeviceProvidingObserverHandle = store.add { _ in }`<br>3) `handle.cancel()` | 能编译、能调 cancel、不崩溃 | P0 | iOS / macOS | ✅ 已覆盖 | `eventObserverHandleCanBeUsedAsDeviceProvidingObserverHandle` |
| TC-07 | Stub 实现返回预期设备属性 | 用 DeviceProviderStub 检查各属性 | 1) `let stub = DeviceProviderStub()`<br>2) 检查 `isMac`, `isIOS`, `screenWidth` 等 | 返回预设值(true, false, 1280) | P1 | iOS / macOS | ✅ 已覆盖 | `stubImplementationReturnsExpectedDeviceProperties` |
| TC-08 | 默认扩展返回 noop handle(非协议要求的默认实现) | 直接调协议扩展的默认 addObserver | 1) `let provider = SomeProvider()`<br>2) `let handle = provider.addObserver { _ in }`(走默认扩展) | `handle is NoopDeviceProvidingObserverHandle` | P1 | iOS / macOS | ✅ 已覆盖 | `defaultExtensionReturnsNoopHandle` |

## 平台覆盖矩阵

| 维度 | iOS 17+ | macOS 14+ | 备注 |
|---|---|---|---|
| 设备属性(isMac/isIOS/isPad) | ✅ | ✅ | 由具体实现提供,协议本身跨平台 |
| 观察者模式 | ✅ | ✅ | 依赖 KitEventObservation,行为一致 |
| noop 默认实现 | ✅ | ✅ | 纯 Swift,无平台差异 |

## 跑测

```bash
cd Packages/ProviderDevice
swift test
```

或在仓库根目录:

```bash
xcodebuild -scheme ProviderDevice \
  -destination 'platform=iOS Simulator,name=BM-iPhone' \
  test
```

## 维护规则

1. **新增 public API** 时:**先在本文件登记测试用例,再写实现**。
2. **bug 修复** 时:在本文件追加"回归用例"(TC-NN),标注触发问题的最小复现。
3. **删除/合并用例** 时:在 git commit message 中说明理由,不要静默删除。
4. **状态更新**:用例实现并跑通后,把"状态"列改为 ✅,并填入"覆盖于"对应的 Swift 测试方法名。
5. **优先级**:P0 = 主路径,缺则不可合并;P1 = 边界/错误路径;P2 = 性能/便利性。

## 当前覆盖统计

- **P0**: 已覆盖 6 / 6(100%) ✅
- **P1**: 已覆盖 2 / 2(100%) ✅
- **P2**: N/A
- **合计**: 已覆盖 8 / 8(100%) 🎉
