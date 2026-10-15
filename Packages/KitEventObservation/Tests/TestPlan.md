# Test Plan: KitEventObservation

> 本文件是该包的**测试用例清单**,作为测试覆盖的"地图"使用。
> 与 `Tests/` 下的 Swift 测试一一对应;Swift 文件是"实现",本文件是"规格"。

## 包概览

- **包名**: `KitEventObservation`
- **平台**: macOS 14+ / iOS 17+
- **公开 API**:
  - `EventObserverStore<Event>`
    - `init()`
    - `add(_ callback: @escaping (Event) -> Void) -> EventObserverHandle<Event>` (`@discardableResult`)
    - `send(_ event: Event)`
  - `EventObserverHandle<Event>`
    - `cancel()`
- **线程模型**: `@MainActor` — 调用必须在主线程
- **核心契约**: 同步投递、handle 取消后立即停止、handle 弱引用 store

## 用例清单

| 编号 | 用例名 | 描述 | 操作步骤 | 预期结果 | 优先级 | 平台 | 状态 | 覆盖于 |
|---|---|---|---|---|---|---|---|---|
| TC-01 | 单一观察者按序接收多次 send | 注册 1 个观察者,连续 send 多次 | 1) `add { received.append($0) }`<br>2) `send(1)`<br>3) `send(2)`<br>4) `send(3)` | `received == [1, 2, 3]`,顺序与 send 顺序一致 | P0 | iOS / macOS | ✅ 已覆盖 | `addDeliversEveryEventInOrder` |
| TC-02 | 多观察者同时收到同一事件 | 注册 2 个观察者,send 1 次 | 1) 注册 A、B<br>2) `send("booted")` | A 和 B 各收到 1 次 `"booted"` | P0 | iOS / macOS | ✅ 已覆盖 | `allObserversReceiveTheSameEvent` |
| TC-03 | cancel 之后停止投递 | 注册后取消,再 send | 1) `add {...}`<br>2) `send(1)` 收到<br>3) `cancel()`<br>4) `send(2)` | 第二次 send 不再触发回调 | P0 | iOS / macOS | ✅ 已覆盖 | `cancelStopsFurtherDelivery` |
| TC-04 | cancel 重复调用幂等 | 同一 handle 连续 cancel 两次 | 1) `add {...}`<br>2) `cancel()`<br>3) `cancel()`<br>4) `send(1)` | 不崩溃;后续 send 不触发回调 | P0 | iOS / macOS | ✅ 已覆盖 | `cancelIsIdempotent` |
| TC-05 | 取消一个观察者不影响其他观察者 | A、B 都注册;取消 A;再 send | 1) 注册 A、B<br>2) `send("a")` → 双方都收到<br>3) 取消 A<br>4) `send("b")` | A 只收到 `["a"]`;B 收到 `["a", "b"]` | P0 | iOS / macOS | ✅ 已覆盖 | `removedObserverDoesNotAffectOthers` |
| TC-06 | 空 store 调用 send 不崩溃 | 无任何观察者,直接 send | 1) `let s = EventObserverStore<Int>()`<br>2) `s.send(42)` | 不抛异常、不触发任何回调 | P0 | iOS / macOS | ✅ 已覆盖 | `sendWithNoObserversDoesNotCrash` |
| TC-07 | 多观察者按注册顺序触发 | 注册 A、B、C;send 1 次 | 1) 依次注册 A、B、C(回调内追加自身标识)<br>2) `send(0)` | 触发顺序为 A → B → C | P0 | iOS / macOS | ✅ 已覆盖 | `multipleObserversFireInRegistrationOrder` |
| TC-08 | handle 在 store 释放后调用 cancel 不崩溃 | store 提前 dealloc,handle 后调 cancel | 1) `var h: EventObserverHandle<Int>?`<br>2) `do { let s = EventObserverStore<Int>(); h = s.add { _ in } }`<br>3) `h?.cancel()` | 不崩溃(handle 持有 `weak var store`,dealloc 后为 nil) | P1 | iOS / macOS | ✅ 已覆盖 | `cancelAfterStoreDeallocatedDoesNotCrash` |
| TC-09 | 回调内新增观察者:不参与本次 send | 观察者 A 在回调里 add 一个 B | 1) A 的回调中 `s.add { ... }`<br>2) 外部 `s.send(0)` | A 收到 1 次;B 收到 0 次(因为是 send 期间遍历 Array(callbacks.values) 的快照) | P1 | iOS / macOS | ✅ 已覆盖 | `addInsideCallbackDoesNotAffectCurrentSend` |
| TC-10 | 回调内取消自身:不重复触发,不影响同 send 内其他观察者 | A 在回调中 cancel 自己 | 1) 注册 A、B<br>2) `s.send(0)` | A 收到 1 次;B 收到 1 次;后续 send 不再触发 A | P1 | iOS / macOS | ✅ 已覆盖 | `selfCancelInsideCallbackDoesNotAffectCurrentSend` |
| TC-11 | 不同 Event 类型泛型替换可工作 | 用 `EventObserverStore<String>` / `<UUID>` / `<MyStruct>` 各跑一次 add+send | 对每种类型:注册一个回调,send 1 次,校验收到 | 三种类型行为一致 | P1 | iOS / macOS | ✅ 已覆盖 | `genericEventTypesWork` |
| TC-12 | 大量观察者(100+)全部收到同一事件 | 批量注册 N 个观察者,send 1 次 | 1) 循环 100 次 `add { counter += 1 }`<br>2) `send(0)` | `counter == 100` | P2 | iOS / macOS | ✅ 已覆盖 | `manyObserversAllReceive` |
| TC-13 | `@discardableResult` 允许忽略返回值 | 不持有 handle | 1) `s.add { _ in }`(不接收返回值)<br>2) `s.send(0)` | 回调被触发;编译器不警告 | P2 | iOS / macOS | ✅ 已覆盖 | `addDiscardableResultIsAllowed` |
| TC-14 | 同一 handle 被两个 send 之间的快速 cancel 不丢已 send 的事件 | 注册后 cancel 紧贴下一次 send | 1) `add { ... }`<br>2) `send(1)`<br>3) `cancel()`<br>4) `send(2)` | 只收到 1 | P2 | iOS / macOS | ✅ 已覆盖 | `cancelBetweenSendsPreservesAlreadyDelivered` |

## 平台覆盖矩阵

| 维度 | iOS 17+ | macOS 14+ | 备注 |
|---|---|---|---|
| 主路径(同步投递) | ✅ | ✅ | 由 XCTest / Swift Testing 同一份代码覆盖 |
| `@MainActor` 线程约束 | ✅ | ✅ | 两平台一致,需在主线程调用 |
| 弱引用 store 的生命周期 | ✅ | ✅ | 与平台无关,纯 Foundation 行为 |
| 跨进程 / 跨线程 | N/A | N/A | 故意不提供;新增线程安全需重新设计 API |

## 跑测

```bash
cd Packages/KitEventObservation
swift test
```

或在仓库根目录:

```bash
xcodebuild -scheme KitEventObservation \
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

- **P0**: 已覆盖 7 / 7(100%) ✅
- **P1**: 已覆盖 4 / 4(100%) ✅
- **P2**: 已覆盖 3 / 3(100%) ✅
- **合计**: 已覆盖 14 / 14(100%) 🎉
