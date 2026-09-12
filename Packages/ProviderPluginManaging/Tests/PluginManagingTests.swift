import Combine
import KernelCore
import Testing
@testable import ProviderPluginManaging

@MainActor
private final class PluginManagingStub: PluginManaging {
    let objectWillChange = ObservableObjectPublisher()

    var allPlugins: [any SuperPlugin] = []
    var configurablePlugins: [any SuperPlugin] = []
    var pluginCount = 0
    var enabledCount = 0
    var lastErrorDescription: String?

    func plugin(id: String) -> (any SuperPlugin)? { nil }
    func isRegistered(id: String) -> Bool { false }
    func enabledPlugins(from candidates: [any SuperPlugin]) -> [any SuperPlugin] { [] }
    func enablePlugin(id: String) async -> Bool { false }
    func disablePlugin(id: String) async -> Bool { false }
    func isEnabled(id: String) -> Bool { false }
}

@MainActor
struct PluginManagingTests {
    @Test
    func defaultObserverUsesNoopFallback() {
        let provider = PluginManagingStub()
        let handle = provider.addObserver { _ in
            Issue.record("The default plugin-management observer must not receive events")
        }

        #expect(handle is NoopPluginManagingObserverHandle)
        handle.cancel()
        handle.cancel()
    }

    @Test
    func explicitNoopHandleSupportsRepeatedCancellation() {
        let handle = NoopPluginManagingObserverHandle()

        handle.cancel()
        handle.cancel()
    }
}
