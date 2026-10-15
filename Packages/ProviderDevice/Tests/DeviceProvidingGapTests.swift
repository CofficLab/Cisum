import Combine
import Foundation
import KitEventObservation
import Testing
@testable import ProviderDevice

/// 补缺测试 —— 对应 `Tests/TestPlan.md` 中标记为 ❌ 缺失的 6 个用例。
///
/// 合并后,请把 TestPlan 中这些 TC 的"状态"列改为 ✅,并在"覆盖于"列
/// 写上对应的测试方法名。
@Suite @MainActor struct DeviceProvidingGapTests {

    // MARK: - Stub

    /// 使用 EventObserverStore 实现真实观察者模式
    private final class RealDeviceProvider: DeviceProviding {
        let objectWillChange = ObservableObjectPublisher()

        let isMac = true
        let isIOS = false
        let isPad = false
        let deviceModel = "test-device"
        let systemVersion = "1.0"
        let screenWidth: CGFloat = 1280
        let screenHeight: CGFloat = 800

        private let store = EventObserverStore<DeviceProvidingEvent>()

        func addObserver(_ callback: @escaping (DeviceProvidingEvent) -> Void) -> any DeviceProvidingObserverHandle {
            store.add(callback)
        }

        func send(_ event: DeviceProvidingEvent) {
            store.send(event)
        }
    }

    /// 不覆盖 addObserver 的 stub,走协议默认扩展
    private final class DefaultExtensionProvider: DeviceProviding {
        let objectWillChange = ObservableObjectPublisher()

        let isMac = false
        let isIOS = true
        let isPad = false
        let deviceModel = "default-ext-device"
        let systemVersion = "2.0"
        let screenWidth: CGFloat = 1000
        let screenHeight: CGFloat = 800
    }

    // MARK: - P0 主路径补全

    /// TC-03: 观察者回调能收到 DeviceProvidingEvent
    @Test func observerCallbackReceivesEvent() {
        let provider = RealDeviceProvider()
        var received: DeviceProvidingEvent?

        let handle = provider.addObserver { event in
            received = event
        }
        provider.send(.deviceChanged)
        #expect(received != nil)
        handle.cancel()
    }

    /// TC-04: 观察者 handle cancel 后停止投递
    @Test func observerHandleCancelStopsDelivery() {
        let provider = RealDeviceProvider()
        var callCount = 0

        let handle = provider.addObserver { _ in
            callCount += 1
        }
        provider.send(.deviceChanged)
        #expect(callCount == 1)

        handle.cancel()
        provider.send(.deviceChanged)
        #expect(callCount == 1) // 取消后不再触发
    }

    /// TC-05: 多观察者同时收到同一事件
    @Test func multipleObserversReceiveSameEvent() {
        let provider = RealDeviceProvider()
        var firstReceived = false
        var secondReceived = false

        let handleA = provider.addObserver { _ in firstReceived = true }
        let handleB = provider.addObserver { _ in secondReceived = true }
        provider.send(.deviceChanged)

        #expect(firstReceived == true)
        #expect(secondReceived == true)
        handleA.cancel()
        handleB.cancel()
    }

    /// TC-06: EventObserverHandle 可作为 DeviceProvidingObserverHandle 使用
    @Test func eventObserverHandleCanBeUsedAsDeviceProvidingObserverHandle() {
        let store = EventObserverStore<DeviceProvidingEvent>()
        var received = false

        // EventObserverHandle<DeviceProvidingEvent> 遵循 DeviceProvidingObserverHandle
        let handle: DeviceProvidingObserverHandle = store.add { _ in
            received = true
        }
        store.send(.deviceChanged)
        #expect(received == true)

        handle.cancel() // 应能调 cancel
    }

    // MARK: - P1 边界 / 错误路径

    /// TC-07: Stub 实现返回预期设备属性
    @Test func stubImplementationReturnsExpectedDeviceProperties() {
        let stub = RealDeviceProvider()

        #expect(stub.isMac == true)
        #expect(stub.isIOS == false)
        #expect(stub.isPad == false)
        #expect(stub.deviceModel == "test-device")
        #expect(stub.systemVersion == "1.0")
        #expect(stub.screenWidth == 1280)
        #expect(stub.screenHeight == 800)
    }

    /// TC-08: 默认扩展返回 noop handle(非协议要求的默认实现)
    @Test func defaultExtensionReturnsNoopHandle() {
        let provider = DefaultExtensionProvider() // 未覆盖 addObserver,走默认扩展
        let handle = provider.addObserver { _ in
            Issue.record("Noop handle should not deliver events")
        }

        #expect(handle is NoopDeviceProvidingObserverHandle)
        handle.cancel()
        handle.cancel() // 幂等
    }
}
