import Combine
import SwiftUI
import Testing
@testable import ProviderDevice

@MainActor
private final class DeviceProviderStub: @preconcurrency DeviceProviding {
    let objectWillChange = ObservableObjectPublisher()

    var isMac = true
    var isIOS = false
    var isPad = false
    var deviceModel = "test-device"
    var systemVersion = "1.0"
    var screenWidth: CGFloat = 1280
    var screenHeight: CGFloat = 800
}

@MainActor
struct DeviceProvidingTests {
    @Test
    func defaultObserverUsesNoopFallback() {
        let provider = DeviceProviderStub()
        let handle = provider.addObserver { _ in
            Issue.record("The default device observer must not receive events")
        }

        #expect(handle is NoopDeviceProvidingObserverHandle)
        handle.cancel()
        handle.cancel()
    }

    @Test
    func explicitNoopHandleSupportsRepeatedCancellation() {
        let handle = NoopDeviceProvidingObserverHandle()

        handle.cancel()
        handle.cancel()
    }
}
