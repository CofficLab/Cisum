import Combine
import Foundation
import KitEventObservation
import Testing
@testable import ProviderCloud

/// 补缺测试 - 对应 TestPlan.md 中标记为 ❌ 缺失的测试用例
@Suite
struct ProviderCloudGapTests {

    // MARK: - 观察者模式测试

    /// TC-03: 观察者能收到状态变更事件
    @Test @MainActor
    func observerReceivesAvailabilityChangedEvents() {
        let provider = CloudProviderStub()
        var receivedEvents: [CloudProvidingEvent] = []

        let handle = provider.addObserver { event in
            receivedEvents.append(event)
        }

        // 触发可用性变更事件
        provider.triggerAvailabilityChanged(isAvailable: true, isSignedIn: true)

        #expect(receivedEvents.count == 1)
        if case .availabilityChanged(let isAvailable, let isSignedIn) = receivedEvents.first {
            #expect(isAvailable == true)
            #expect(isSignedIn == true)
        } else {
            Issue.record("Expected availabilityChanged event")
        }

        handle.cancel()
    }

    /// TC-04: 取消后不再收到事件
    @Test @MainActor
    func observerStopsReceivingEventsAfterCancellation() {
        let provider = CloudProviderStub()
        var receivedCount = 0

        let handle = provider.addObserver { _ in
            receivedCount += 1
        }

        // 触发事件
        provider.triggerAvailabilityChanged(isAvailable: true, isSignedIn: true)
        #expect(receivedCount == 1)

        // 取消后
        handle.cancel()
        provider.triggerAvailabilityChanged(isAvailable: false, isSignedIn: false)

        // 不再收到事件
        #expect(receivedCount == 1)
    }

    /// TC-05: 多个观察者同时收到事件
    @Test @MainActor
    func multipleObserversReceiveEvents() {
        let provider = CloudProviderStub()
        var observer1Count = 0
        var observer2Count = 0

        let handle1 = provider.addObserver { _ in
            observer1Count += 1
        }

        let handle2 = provider.addObserver { _ in
            observer2Count += 1
        }

        // 触发事件
        provider.triggerAvailabilityChanged(isAvailable: true, isSignedIn: true)

        #expect(observer1Count == 1)
        #expect(observer2Count == 1)

        handle1.cancel()
        handle2.cancel()
    }

    /// TC-06: EventObserverHandle 可作为 CloudProvidingObserverHandle
    @Test @MainActor
    func eventObserverHandleCanBeUsedAsCloudProvidingObserverHandle() {
        let store = EventObserverStore<CloudProvidingEvent>()
        var received = false

        let handle: CloudProvidingObserverHandle = store.add { _ in
            received = true
        }

        // 发送事件
        store.send(.availabilityChanged(isICloudAvailable: true, isSignedIn: true))
        #expect(received == true)

        // 取消
        handle.cancel()
    }

    // MARK: - 属性测试

    /// TC-07: Stub 实现返回预期初始值
    @Test @MainActor
    func stubImplementationReturnsExpectedInitialValues() {
        let provider = CloudProviderStub()

        #expect(provider.isICloudAvailable == false)
        #expect(provider.isSignedIn == nil)
        #expect(provider.accountStatusDescription == "unknown")
    }

    /// TC-08: isICloudAvailable 默认为 false
    @Test @MainActor
    func isICloudAvailableDefaultsToFalse() {
        let provider = CloudProviderStub()
        #expect(provider.isICloudAvailable == false)
    }

    /// TC-09: isSignedIn 默认为 nil
    @Test @MainActor
    func isSignedInDefaultsToNil() {
        let provider = CloudProviderStub()
        #expect(provider.isSignedIn == nil)
    }

    /// TC-10: accountStatusDescription 默认为 "unknown"
    @Test @MainActor
    func accountStatusDescriptionDefaultsToUnknown() {
        let provider = CloudProviderStub()
        #expect(provider.accountStatusDescription == "unknown")
    }

    // MARK: - 事件测试

    /// TC-11: availabilityChanged 事件包含正确的可用性信息
    @Test @MainActor
    func availabilityChangedEventContainsCorrectInformation() {
        let provider = CloudProviderStub()
        var receivedEvent: CloudProvidingEvent?

        let handle = provider.addObserver { event in
            receivedEvent = event
        }

        // 测试可用的情况
        provider.triggerAvailabilityChanged(isAvailable: true, isSignedIn: true)
        if case .availabilityChanged(let isAvailable, let isSignedIn) = receivedEvent {
            #expect(isAvailable == true)
            #expect(isSignedIn == true)
        }

        // 测试不可用的情况
        provider.triggerAvailabilityChanged(isAvailable: false, isSignedIn: nil)
        if case .availabilityChanged(let isAvailable, let isSignedIn) = receivedEvent {
            #expect(isAvailable == false)
            #expect(isSignedIn == nil)
        }

        handle.cancel()
    }
}

/// 测试用 Stub 实现
@MainActor
private final class CloudProviderStub: CloudProviding {
    let objectWillChange = ObservableObjectPublisher()

    var isICloudAvailable = false
    var isSignedIn: Bool? = nil
    var accountStatusDescription = "unknown"

    private let store = EventObserverStore<CloudProvidingEvent>()

    func addObserver(_ callback: @escaping (CloudProvidingEvent) -> Void) -> any CloudProvidingObserverHandle {
        store.add(callback)
    }

    // 测试辅助方法:触发事件
    func triggerAvailabilityChanged(isAvailable: Bool, isSignedIn: Bool?) {
        isICloudAvailable = isAvailable
        self.isSignedIn = isSignedIn
        store.send(.availabilityChanged(isICloudAvailable: isAvailable, isSignedIn: isSignedIn))
    }
}
