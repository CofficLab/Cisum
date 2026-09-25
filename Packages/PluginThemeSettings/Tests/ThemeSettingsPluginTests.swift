@testable import PluginThemeSettings
import CisumKernelSupport
import CisumUIComponents
import SwiftUI
import Testing

@Test func pluginInfoExportsRegistrationMetadata() {
    #expect(ThemeSettingsPluginInfo.iconName == "paintbrush")
    #expect(ThemeSettingsPluginInfo.order == 140)
}

// MARK: - Observer + ViewModel 生命周期（迁移 Phase 1）

private struct TestChromeTheme: LumiAppChromeTheme {
    let identifier = "test-theme"
    let displayName = "Test Theme"
    let compactName = "Test"
    let description = "Test theme for observer lifecycle"
    let iconName = "paintpalette"
    let iconColor: Color = .blue
    let appearanceKind: ThemeAppearanceKind = .light

    func accentColors() -> (primary: Color, secondary: Color, tertiary: Color) {
        (.blue, .blue.opacity(0.7), .blue.opacity(0.4))
    }

    func atmosphereColors() -> (deep: Color, medium: Color, light: Color) {
        (.black, .gray, .white)
    }

    func glowColors() -> (subtle: Color, medium: Color, intense: Color) {
        (.blue.opacity(0.2), .blue.opacity(0.5), .blue)
    }

    func makeGlobalBackground(proxy: GeometryProxy) -> AnyView {
        AnyView(Color.clear)
    }
}

@MainActor
private func makeThemeService() -> ThemeService {
    let theme = TestChromeTheme()
    let contribution = LumiUIThemeContribution(
        sortKey: ThemeSortKey(pluginOrder: 1, themeId: theme.identifier),
        chromeTheme: theme,
        editorThemeId: theme.identifier
    )
    let service = ThemeService(contributionsProvider: { [contribution] })
    service.reloadThemes()
    return service
}

@MainActor
@Test func themeObserverPerformsInitialSync() {
    let service = makeThemeService()

    let viewModel = ThemeSettingsViewModel(
        capability: ThemeSettingsCapabilityAdapter(theme: service)
    )
    let observer = ThemeProvidingObserver(provider: service, viewModel: viewModel)
    defer { observer.cancel() }

    // 监听安装前已经存在的状态不能丢失。
    #expect(viewModel.themes.map(\.id) == ["test-theme"])
    #expect(viewModel.currentThemeID == "test-theme")
}

@MainActor
@Test func themeObserverForwardsSelectionToViewModel() {
    let theme = TestChromeTheme()
    let contribution = LumiUIThemeContribution(
        sortKey: ThemeSortKey(pluginOrder: 1, themeId: theme.identifier),
        chromeTheme: theme,
        editorThemeId: theme.identifier
    )
    let service = ThemeService(contributionsProvider: { [contribution] })

    let viewModel = ThemeSettingsViewModel(
        capability: ThemeSettingsCapabilityAdapter(theme: service)
    )
    let observer = ThemeProvidingObserver(provider: service, viewModel: viewModel)
    defer { observer.cancel() }

    service.reloadThemes()
    #expect(viewModel.themes.map(\.id) == ["test-theme"])
}

@MainActor
@Test func themeObserverCancelStopsViewModelUpdates() {
    let service = makeThemeService()
    let viewModel = ThemeSettingsViewModel(
        capability: ThemeSettingsCapabilityAdapter(theme: service)
    )
    let observer = ThemeProvidingObserver(provider: service, viewModel: viewModel)

    #expect(viewModel.currentThemeID == "test-theme")

    observer.cancel()
    // 无可选中变化时保持当前选中；cancel 后重新加载不再覆盖 ViewModel。
    service.reloadThemes()
    #expect(viewModel.currentThemeID == "test-theme")
}

// MARK: - ViewModel 与外观筛选

@MainActor
private final class ThemeSettingsCapabilityProbe: ThemeSettingsCapability {
    var allThemeContributions: [LumiUIThemeContribution] = []
    var selectedThemeID = ""
    var selected: [String] = []

    func selectTheme(_ themeID: String) {
        selected.append(themeID)
    }
}

@MainActor
struct ThemeSettingsViewModelTests {
    @Test
    func initReflectsCapabilityState() {
        let capability = ThemeSettingsCapabilityProbe()
        capability.selectedThemeID = "aurora"
        let viewModel = ThemeSettingsViewModel(capability: capability)
        #expect(viewModel.currentThemeID == "aurora")
    }

    @Test
    func selectThemeForwardsToCapability() {
        let capability = ThemeSettingsCapabilityProbe()
        let viewModel = ThemeSettingsViewModel(capability: capability)
        viewModel.selectTheme("midnight")
        #expect(capability.selected == ["midnight"])
    }

    @Test
    func providerChangeRefreshesSelection() {
        let capability = ThemeSettingsCapabilityProbe()
        let viewModel = ThemeSettingsViewModel(capability: capability)
        capability.selectedThemeID = "forest"
        viewModel.handleProviderChanged()
        #expect(viewModel.currentThemeID == "forest")
    }

    @Test
    func missingCapabilityKeepsEmptyState() {
        let viewModel = ThemeSettingsViewModel(capability: nil)
        viewModel.selectTheme("x")
        viewModel.handleProviderChanged()
        #expect(viewModel.themes.isEmpty)
        #expect(viewModel.currentThemeID == "")
    }
}

@Test func appearanceFilterMatchesKinds() {
    #expect(ThemeAppearanceFilter.all.matches(.dark))
    #expect(ThemeAppearanceFilter.all.matches(.light))
    #expect(ThemeAppearanceFilter.dark.matches(.dark))
    #expect(!ThemeAppearanceFilter.dark.matches(.light))
    #expect(ThemeAppearanceFilter.light.matches(.light))
    #expect(!ThemeAppearanceFilter.light.matches(.system))
    #expect(ThemeAppearanceFilter.system.matches(.system))
    #expect(!ThemeAppearanceFilter.system.matches(.dark))
}
