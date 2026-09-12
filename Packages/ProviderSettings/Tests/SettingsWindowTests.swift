import Combine
import CisumUIComponents
import KernelCore
import SwiftUI
import Testing
@testable import ProviderSettings

@MainActor
private final class PluginProviderStub: @preconcurrency PluginProviding {
    let objectWillChange = ObservableObjectPublisher()
    var allPlugins: [any SuperPlugin] = []
    var navigationItems: [PluginSettingNavigationItem]
    private var observers: [UUID: (PluginProvidingEvent) -> Void] = [:]

    var observerCount: Int { observers.count }

    init(navigationItems: [PluginSettingNavigationItem] = []) {
        self.navigationItems = navigationItems
    }

    func getStatusViews() -> [AnyView] { [] }
    func getStateViews() -> [AnyView] { [] }
    func getPosterViews() -> [AnyView] { [] }
    func getGuideView() -> AnyView? { nil }
    func getSettingViews() -> [AnyView] { [] }
    func getSettingNavigationItems() -> [PluginSettingNavigationItem] { navigationItems }
    func getTabViews(reason: String, demoMode: Bool) -> [(view: AnyView, label: String)] { [] }

    func wrapWithCurrentRoot<Content: View>(@ViewBuilder content: () -> Content) -> AnyView? {
        nil
    }

    func getToolBarButtons() -> [(id: String, view: AnyView)] { [] }
    func getThemeContributions() -> [LumiUIThemeContribution] { [] }
    func getHeroView() -> AnyView? { nil }
    func getRightAlbumView() -> AnyView? { nil }
    func getControlButtonsView() -> AnyView? { nil }
    func getProgressView() -> AnyView? { nil }
    func invalidateCaches() {}

    func addObserver(
        _ callback: @escaping (PluginProvidingEvent) -> Void
    ) -> any PluginProvidingObserverHandle {
        let id = UUID()
        observers[id] = callback
        return PluginProviderObserverHandle { [weak self] in
            self?.observers.removeValue(forKey: id)
        }
    }

    func send(_ event: PluginProvidingEvent) {
        for callback in Array(observers.values) {
            callback(event)
        }
    }
}

@MainActor
private final class PluginProviderObserverHandle: PluginProvidingObserverHandle {
    private var cancellation: (() -> Void)?

    init(cancellation: @escaping () -> Void) {
        self.cancellation = cancellation
    }

    func cancel() {
        cancellation?()
        cancellation = nil
    }
}

@MainActor
struct SettingsWindowTests {
    @Test
    func viewModelRefreshesOnBothContributionEventsAndDetachesOldProvider() {
        let oldProvider = PluginProviderStub(navigationItems: [setting("old")])
        let viewModel = SettingsWindowViewModel(settings: oldProvider)

        #expect(viewModel.navigationItems.map(\.id) == ["old"])
        #expect(oldProvider.observerCount == 1)

        oldProvider.navigationItems = [setting("plugins-updated")]
        viewModel.handle(.pluginsChanged)
        #expect(viewModel.navigationItems.map(\.id) == ["plugins-updated"])

        oldProvider.navigationItems = [setting("contributions-updated")]
        oldProvider.send(.contributionsChanged)
        #expect(viewModel.navigationItems.map(\.id) == ["contributions-updated"])

        let replacement = PluginProviderStub(navigationItems: [setting("replacement")])
        viewModel.attach(to: replacement)
        #expect(oldProvider.observerCount == 0)
        #expect(replacement.observerCount == 1)
        #expect(viewModel.navigationItems.map(\.id) == ["replacement"])

        oldProvider.navigationItems = [setting("stale")]
        oldProvider.send(.pluginsChanged)
        #expect(viewModel.navigationItems.map(\.id) == ["replacement"])

        viewModel.attach(to: nil)
        #expect(replacement.observerCount == 0)
        #expect(viewModel.navigationItems.isEmpty)
    }

    @Test
    func viewModelSupportsMissingAndInitiallyEmptyProviders() {
        let viewModel = SettingsWindowViewModel(settings: nil)
        #expect(viewModel.navigationItems.isEmpty)

        let provider = PluginProviderStub()
        viewModel.attach(to: provider)
        #expect(viewModel.navigationItems.isEmpty)
        provider.navigationItems = [setting("added")]
        provider.send(.pluginsChanged)
        #expect(viewModel.navigationItems.map(\.id) == ["added"])
    }

    @Test
    func settingsWindowBuildsEmptyAndPopulatedStates() {
        _ = SettingsWindow(settings: nil).body

        let provider = PluginProviderStub(navigationItems: [setting("general"), setting("audio")])
        _ = SettingsWindow(settings: provider).body
        _ = SettingsHeaderView().body
    }
}

private func setting(_ id: String) -> PluginSettingNavigationItem {
    PluginSettingNavigationItem(
        id: id,
        title: id,
        iconName: "gearshape",
        order: 0,
        destination: AnyView(Text(id))
    )
}
