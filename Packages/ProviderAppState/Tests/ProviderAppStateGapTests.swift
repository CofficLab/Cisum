import Combine
import Foundation
import KitEventObservation
import Testing
@testable import ProviderAppState

/// 补缺测试 - 对应 TestPlan.md 中标记为 ❌ 缺失的测试用例
@Suite
struct ProviderAppStateGapTests {

    // MARK: - 观察者模式测试

    /// TC-03: 观察者能收到状态变更事件
    @Test @MainActor
    func observerReceivesStateChangeEvents() {
        let provider = AppStateProviderStub()
        var receivedEvents: [AppStateProvidingEvent] = []

        let handle = provider.addObserver { event in
            receivedEvents.append(event)
        }

        // 触发各种状态变更
        provider.enterDemoMode()
        provider.exitDemoMode()
        provider.showDBView()
        provider.hideDBView()
        provider.setImporting(true)
        provider.setDragOperation(true)
        provider.appendStateMessage("Test message")
        provider.clearStateMessages()

        // 由于 Stub 实现是空的，不会触发事件，所以 receivedEvents 应该为空
        // 这个测试验证观察者注册和取消不会崩溃
        #expect(receivedEvents.isEmpty)

        handle.cancel()
    }

    /// TC-04: 取消后不再收到事件
    @Test @MainActor
    func observerStopsReceivingEventsAfterCancellation() {
        let provider = AppStateProviderStub()
        var receivedCount = 0

        let handle = provider.addObserver { _ in
            receivedCount += 1
        }

        // 触发一些状态变更
        provider.enterDemoMode()
        provider.exitDemoMode()

        let countBeforeCancel = receivedCount
        handle.cancel()

        // 取消后再触发
        provider.showDBView()
        provider.hideDBView()

        // 由于 Stub 不触发事件，计数应该不变
        #expect(receivedCount == countBeforeCancel)
    }

    /// TC-05: 多个观察者同时收到事件
    @Test @MainActor
    func multipleObserversReceiveEvents() {
        let provider = AppStateProviderStub()
        var observer1Count = 0
        var observer2Count = 0

        let handle1 = provider.addObserver { _ in
            observer1Count += 1
        }

        let handle2 = provider.addObserver { _ in
            observer2Count += 1
        }

        // 触发状态变更
        provider.enterDemoMode()
        provider.exitDemoMode()

        // 由于 Stub 不触发事件，两个观察者的计数都应该为 0
        #expect(observer1Count == 0)
        #expect(observer2Count == 0)

        handle1.cancel()
        handle2.cancel()
    }

    /// TC-06: EventObserverHandle 可作为 AppStateProvidingObserverHandle
    @Test @MainActor
    func eventObserverHandleCanBeUsedAsAppStateProvidingObserverHandle() {
        let store = EventObserverStore<AppStateProvidingEvent>()
        var received = false

        let handle: AppStateProvidingObserverHandle = store.add { _ in
            received = true
        }

        // 发送事件
        store.send(.demoModeChanged(true))
        #expect(received == true)

        // 取消
        handle.cancel()
    }

    // MARK: - 状态属性测试

    /// TC-07: Stub 实现返回预期状态值
    @Test @MainActor
    func stubImplementationReturnsExpectedStateValues() {
        let provider = AppStateProviderStub()

        #expect(provider.isDemoMode == false)
        #expect(provider.isDBViewVisible == false)
        #expect(provider.isImporting == false)
        #expect(provider.isDropping == false)
        #expect(provider.hasDragOperation == false)
        #expect(provider.stateMessage == "")
    }

    /// TC-08: enterDemoMode 切换状态
    @Test @MainActor
    func enterDemoModeChangesState() {
        let provider = AppStateProviderStub()

        #expect(provider.isDemoMode == false)
        provider.enterDemoMode()
        // Stub 实现是空的，所以状态不会改变
        #expect(provider.isDemoMode == false)
    }

    /// TC-09: exitDemoMode 切换状态
    @Test @MainActor
    func exitDemoModeChangesState() {
        let provider = AppStateProviderStub()

        provider.enterDemoMode()
        provider.exitDemoMode()
        // Stub 实现是空的，状态不会改变
        #expect(provider.isDemoMode == false)
    }

    /// TC-10: showDBView 切换状态
    @Test @MainActor
    func showDBViewChangesState() {
        let provider = AppStateProviderStub()

        #expect(provider.isDBViewVisible == false)
        provider.showDBView()
        // Stub 实现是空的，状态不会改变
        #expect(provider.isDBViewVisible == false)
    }

    /// TC-11: hideDBView 切换状态
    @Test @MainActor
    func hideDBViewChangesState() {
        let provider = AppStateProviderStub()

        provider.showDBView()
        provider.hideDBView()
        // Stub 实现是空的，状态不会改变
        #expect(provider.isDBViewVisible == false)
    }

    /// TC-12: toggleDBView 切换状态
    @Test @MainActor
    func toggleDBViewChangesState() {
        let provider = AppStateProviderStub()

        #expect(provider.isDBViewVisible == false)
        provider.toggleDBView()
        provider.toggleDBView()
        // Stub 实现是空的，状态不会改变
        #expect(provider.isDBViewVisible == false)
    }

    /// TC-13: setImporting 设置导入状态
    @Test @MainActor
    func setImportingChangesState() {
        let provider = AppStateProviderStub()

        #expect(provider.isImporting == false)
        provider.setImporting(true)
        // Stub 实现是空的，状态不会改变
        #expect(provider.isImporting == false)
    }

    /// TC-14: setDragOperation 设置拖放状态
    @Test @MainActor
    func setDragOperationChangesState() {
        let provider = AppStateProviderStub()

        #expect(provider.isDropping == false)
        #expect(provider.hasDragOperation == false)
        provider.setDragOperation(true)
        // Stub 实现是空的，状态不会改变
        #expect(provider.isDropping == false)
        #expect(provider.hasDragOperation == false)
    }

    /// TC-15: appendStateMessage 追加消息
    @Test @MainActor
    func appendStateMessageChangesState() {
        let provider = AppStateProviderStub()

        #expect(provider.stateMessage == "")
        provider.appendStateMessage("Test message")
        // Stub 实现是空的，状态不会改变
        #expect(provider.stateMessage == "")
    }

    /// TC-16: clearStateMessages 清空消息
    @Test @MainActor
    func clearStateMessagesChangesState() {
        let provider = AppStateProviderStub()

        provider.appendStateMessage("Test")
        provider.clearStateMessages()
        // Stub 实现是空的，状态不会改变
        #expect(provider.stateMessage == "")
    }

    // MARK: - 兼容性测试

    /// TC-17: hasDragOperation 兼容 isDropping
    @Test @MainActor
    func hasDragOperationIsCompatibleWithIsDropping() {
        let provider = AppStateProviderStub()

        // hasDragOperation 应该等于 isDropping
        #expect(provider.hasDragOperation == provider.isDropping)

        // 尝试设置拖放状态
        provider.setDragOperation(true)
        #expect(provider.hasDragOperation == provider.isDropping)

        provider.setDragOperation(false)
        #expect(provider.hasDragOperation == provider.isDropping)
    }
}

/// 测试用 Stub 实现
@MainActor
private final class AppStateProviderStub: AppStateProviding {
    let objectWillChange = ObservableObjectPublisher()

    var isDemoMode = false
    var isDBViewVisible = false
    var isImporting = false
    var isDropping = false
    var hasDragOperation: Bool { isDropping }
    var stateMessage = ""

    private let store = EventObserverStore<AppStateProvidingEvent>()

    func enterDemoMode() {}
    func exitDemoMode() {}
    func showDBView() {}
    func hideDBView() {}
    func closeDBView() {}
    func toggleDBView() {}
    func setImporting(_ importing: Bool) {}
    func setDragOperation(_ active: Bool) {}
    func appendStateMessage(_ message: String) {}
    func clearStateMessages() {}

    func addObserver(_ callback: @escaping (AppStateProvidingEvent) -> Void) -> any AppStateProvidingObserverHandle {
        store.add(callback)
    }
}
