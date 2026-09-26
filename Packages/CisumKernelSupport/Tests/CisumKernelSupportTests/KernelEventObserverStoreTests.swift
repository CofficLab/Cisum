import Foundation
import Testing
@testable import CisumKernelSupport

/// 内核观察者存储的确定性回归：注册-分发-撤销语义必须可靠，
/// 撤销后不得再收到事件。
@Suite @MainActor struct KernelEventObserverStoreTests {
    @Test func addDeliversEveryEventInOrder() {
        let store = KernelEventObserverStore<Int>()
        var received: [Int] = []

        let handle = store.add { received.append($0) }
        store.send(1)
        store.send(2)
        store.send(3)

        #expect(received == [1, 2, 3])
        handle.cancel()
    }

    @Test func cancelStopsFurtherDelivery() {
        let store = KernelEventObserverStore<Int>()
        var received: [Int] = []

        let handle = store.add { received.append($0) }
        store.send(1)
        handle.cancel()
        store.send(2)

        #expect(received == [1])
    }

    @Test func cancelIsIdempotent() {
        let store = KernelEventObserverStore<Int>()
        var received: [Int] = []

        let handle = store.add { received.append($0) }
        handle.cancel()
        handle.cancel()
        store.send(1)

        #expect(received.isEmpty)
    }

    @Test func allObserversReceiveTheSameEvent() {
        let store = KernelEventObserverStore<String>()
        var first: [String] = []
        var second: [String] = []

        let handleA = store.add { first.append($0) }
        let handleB = store.add { second.append($0) }

        store.send("booted")

        #expect(first == ["booted"])
        #expect(second == ["booted"])
        handleA.cancel()
        handleB.cancel()
    }

    @Test func removedObserverDoesNotAffectOthers() {
        let store = KernelEventObserverStore<String>()
        var first: [String] = []
        var second: [String] = []

        let handleA = store.add { first.append($0) }
        let handleB = store.add { second.append($0) }

        store.send("a")
        handleA.cancel()
        store.send("b")

        #expect(first == ["a"])
        #expect(second == ["a", "b"])
        handleB.cancel()
    }
}
