import Combine
import SwiftUI
import Testing
@testable import ProviderToolbar

@MainActor
private final class ToolbarProviderStub: @preconcurrency ToolbarProviding {
    let objectWillChange = ObservableObjectPublisher()

    func makeToolbarView() -> AnyView {
        AnyView(Text("Toolbar"))
    }
}

@MainActor
struct ToolbarProvidingTests {
    @Test
    func toolbarProviderReturnsAView() {
        let provider = ToolbarProviderStub()
        let view = provider.makeToolbarView()
        _ = view
    }

    @Test
    func defaultObserverUsesNoopFallback() {
        let provider = ToolbarProviderStub()
        let handle = provider.addObserver { _ in
            Issue.record("The default toolbar observer must not receive events")
        }

        #expect(handle is NoopToolbarProvidingObserverHandle)
        handle.cancel()
        handle.cancel()
    }

    @Test
    func explicitNoopHandleSupportsRepeatedCancellation() {
        let handle = NoopToolbarProvidingObserverHandle()

        handle.cancel()
        handle.cancel()
    }
}
