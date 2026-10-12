import Combine
import Testing
@testable import ProviderAppState

@MainActor
private final class AppStateProviderStub: @preconcurrency AppStateProviding {
    let objectWillChange = ObservableObjectPublisher()

    var isDemoMode = false
    var isDBViewVisible = false
    var isImporting = false
    var isDropping = false
    var hasDragOperation: Bool { isDropping }
    var stateMessage = ""

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
}

@MainActor
struct AppStateProvidingTests {
    @Test
    func defaultObserverRegistrationReturnsSafeNoopHandle() {
        let provider = AppStateProviderStub()
        let handle = provider.addObserver { _ in
            Issue.record("The default observer fallback must not invoke callbacks")
        }

        #expect(handle is NoopAppStateProvidingObserverHandle)
        handle.cancel()
        handle.cancel()
    }

    @Test
    func explicitNoopObserverHandleCanBeCancelledRepeatedly() {
        let handle = NoopAppStateProvidingObserverHandle()

        handle.cancel()
        handle.cancel()
    }
}
