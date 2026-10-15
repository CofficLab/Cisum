import Foundation
import Testing
@testable import KitEventObservation

/// 补缺测试 —— 对应 `Tests/TestPlan.md` 中标记为 ❌ 缺失的 9 个用例。
///
/// 合并后,请把 TestPlan 中这些 TC 的"状态"列改为 ✅,并在"覆盖于"列
/// 写上对应的测试方法名。
@Suite @MainActor struct EventObserverStoreGapTests {

    // MARK: - P0 主路径补全

    /// TC-06: 空 store 调用 send 不崩溃。
    @Test func sendWithNoObserversDoesNotCrash() {
        let store = EventObserverStore<Int>()
        store.send(42) // 不抛异常即可
    }

    /// TC-07: 多观察者按注册顺序触发。
    @Test func multipleObserversFireInRegistrationOrder() {
        let store = EventObserverStore<String>()
        var order: [String] = []
        let hA = store.add { _ in order.append("A") }
        let hB = store.add { _ in order.append("B") }
        let hC = store.add { _ in order.append("C") }
        store.send("x")
        #expect(order == ["A", "B", "C"])
        hA.cancel(); hB.cancel(); hC.cancel()
    }

    // MARK: - P1 边界 / 错误路径

    /// TC-08: handle 在 store 释放后调用 cancel 不崩溃。
    ///
    /// handle 持有 `weak var store`,store 被 ARC 释放后,`store?.remove(id:)`
    /// 退化为 no-op,不会崩。
    @Test func cancelAfterStoreDeallocatedDoesNotCrash() {
        weak var storeRef: EventObserverStore<Int>?
        let handle: EventObserverHandle<Int> = {
            let s = EventObserverStore<Int>()
            storeRef = s
            return s.add { _ in }
        }()
        #expect(storeRef == nil) // 确认 store 已被 ARC 释放
        handle.cancel() // 弱引用下,不应崩溃
    }

    /// TC-09: 回调内新增观察者不影响本次 send。
    ///
    /// `send` 内部用 `Array(callbacks.values)` 取了一份快照再遍历,
    /// send 期间新加的观察者不在快照中,不会在本次 send 触发,但下次 send 会触发。
    @Test func addInsideCallbackDoesNotAffectCurrentSend() {
        let store = EventObserverStore<Int>()
        var aCalls = 0
        var bCalls = 0

        let hA = store.add { _ in
            aCalls += 1
            _ = store.add { _ in bCalls += 1 } // 回调内 add
        }
        store.send(1)
        #expect(aCalls == 1)
        #expect(bCalls == 0) // B 不参与本次 send

        store.send(2) // 下一次 send,B 参与
        #expect(aCalls == 2)
        #expect(bCalls == 1)
        hA.cancel()
    }

    /// TC-10: 回调内取消自身 —— 不重复触发,不影响同 send 内其他观察者。
    @Test func selfCancelInsideCallbackDoesNotAffectCurrentSend() {
        let store = EventObserverStore<Int>()
        var aCalls = 0
        var bCalls = 0
        var handleAOpt: EventObserverHandle<Int>?

        let handleA = store.add { _ in
            aCalls += 1
            handleAOpt?.cancel() // 回调内 cancel 自身
        }
        handleAOpt = handleA // add 之后再赋,让闭包能拿到自身 handle
        let handleB = store.add { _ in bCalls += 1 }

        store.send(0)
        #expect(aCalls == 1)
        #expect(bCalls == 1)

        store.send(0)
        #expect(aCalls == 1) // A 取消后,后续 send 不再触发
        #expect(bCalls == 2)

        handleB.cancel()
    }

    /// TC-11: 不同 Event 泛型(String / UUID / 自定义 struct)都能工作。
    @Test func genericEventTypesWork() {
        // String
        do {
            let store = EventObserverStore<String>()
            var received: String?
            let h = store.add { received = $0 }
            store.send("hello")
            #expect(received == "hello")
            h.cancel()
        }
        // UUID
        do {
            let store = EventObserverStore<UUID>()
            var received: UUID?
            let h = store.add { received = $0 }
            let id = UUID()
            store.send(id)
            #expect(received == id)
            h.cancel()
        }
        // 自定义 struct(局部声明,值类型 + Equatable)
        do {
            struct Point: Equatable { let x: Int; let y: Int }
            let store = EventObserverStore<Point>()
            var received: Point?
            let h = store.add { received = $0 }
            store.send(Point(x: 1, y: 2))
            #expect(received == Point(x: 1, y: 2))
            h.cancel()
        }
    }

    // MARK: - P2 性能 / 便利性

    /// TC-12: 大量观察者(150)全部收到同一事件。
    @Test func manyObserversAllReceive() {
        let store = EventObserverStore<Int>()
        var counter = 0 // var + 闭包隐式装箱,所有闭包共享同一存储
        var handles: [EventObserverHandle<Int>] = []
        for _ in 0..<150 {
            handles.append(store.add { _ in counter += 1 })
        }
        store.send(0)
        #expect(counter == 150)
        handles.forEach { $0.cancel() }
    }

    /// TC-13: `@discardableResult` 允许忽略 `add` 的返回值。
    ///
    /// 这个用例主要在编译期生效:能编过就说明 `@discardableResult` 注解保留住了。
    @Test func addDiscardableResultIsAllowed() {
        let store = EventObserverStore<Int>()
        var counter = 0
        store.add { _ in counter += 1 } // 故意不接收返回值
        store.send(0)
        #expect(counter == 1)
    }

    /// TC-14: cancel 紧贴下一次 send,已投递的事件不丢。
    ///
    /// 与 TC-03 的差别:本用例 send 两次后再 cancel,校验已投递的
    /// 事件在取消后仍保留,新 send 不会再投递。
    @Test func cancelBetweenSendsPreservesAlreadyDelivered() {
        let store = EventObserverStore<Int>()
        var received: [Int] = []
        let h = store.add { received.append($0) }
        store.send(1)
        store.send(2)
        h.cancel()
        store.send(3)
        #expect(received == [1, 2]) // 前两个保留,后一个不投递
    }
}
