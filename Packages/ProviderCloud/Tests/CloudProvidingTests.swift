import Combine
import Testing
@testable import ProviderCloud

@MainActor
private final class CloudProviderStub: @preconcurrency CloudProviding {
    let objectWillChange = ObservableObjectPublisher()

    var isICloudAvailable = false
    var isSignedIn: Bool? = nil
    var accountStatusDescription = "unknown"
}

@MainActor
struct CloudProvidingTests {
    @Test
    func defaultObserverUsesNoopFallback() {
        let provider = CloudProviderStub()
        let handle = provider.addObserver { _ in
            Issue.record("The default cloud observer must not receive events")
        }

        #expect(handle is NoopCloudProvidingObserverHandle)
        handle.cancel()
        handle.cancel()
    }

    @Test
    func explicitNoopHandleSupportsRepeatedCancellation() {
        let handle = NoopCloudProvidingObserverHandle()

        handle.cancel()
        handle.cancel()
    }
}
