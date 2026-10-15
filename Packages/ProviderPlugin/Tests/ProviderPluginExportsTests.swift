import KernelCore
import LumiUI
import SwiftUI
import Testing
import ProviderPlugin

@MainActor
private final class PluginProviderStub: PluginProviding {
    var allPlugins: [any SuperPlugin] { [] }
    func getStatusViews() -> [AnyView] { [] }
    func getStateViews() -> [AnyView] { [] }
    func getPosterViews() -> [AnyView] { [] }
    func getGuideView() -> AnyView? { nil }
    func getSettingViews() -> [AnyView] { [] }
    func getTabViews(reason: String, demoMode: Bool) -> [(view: AnyView, label: String)] { [] }
    func wrapWithCurrentRoot<Content: View>(@ViewBuilder content: () -> Content) -> AnyView? {
        AnyView(content())
    }
    func getToolBarButtons() -> [(id: String, view: AnyView)] { [] }
    func getThemeContributions() -> [LumiUIThemeContribution] { [] }
    func getHeroView() -> AnyView? { nil }
    func getRightAlbumView() -> AnyView? { nil }
    func getControlButtonsView() -> AnyView? { nil }
    func getProgressView() -> AnyView? { nil }
    func invalidateCaches() {}
}

// 普通 import 验证下游可使用公开契约，不依赖 @testable。
@MainActor
struct ProviderPluginExportsTests {
    @Test
    func defaultObserverUsesNoopFallback() {
        let provider: any PluginProviding = PluginProviderStub()
        let handle = provider.addObserver { _ in
            Issue.record("默认观察者不应收到事件")
        }
        #expect(handle is NoopPluginProvidingObserverHandle)
        provider.invalidateCaches()
        handle.cancel()
        handle.cancel()
    }

    @Test
    func explicitNoopHandleSupportsRepeatedCancellation() {
        let handle: any PluginProvidingObserverHandle = NoopPluginProvidingObserverHandle()
        handle.cancel()
        handle.cancel()
    }

    @Test
    func publicServiceRegistersUnderBothProviderContracts() throws {
        let kernel = KernelCoreContainer()
        let service = PluginContributionService(kernel: kernel)
        try kernel.registerProvider((any PluginProviding).self, service)
        try kernel.registerProvider((any PluginContributionProviding).self, service)

        let query = try #require(kernel.resolveProvider((any PluginProviding).self))
        let registration = try #require(kernel.resolveProvider((any PluginContributionProviding).self))
        #expect(query === service)
        #expect(registration === service)
        #expect(query.allPlugins.isEmpty)
        #expect(query.getStatusViews().isEmpty)
    }
}
