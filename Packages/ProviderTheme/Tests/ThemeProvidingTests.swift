import Combine
import CisumUIComponents
import SwiftUI
import Testing
@testable import ProviderTheme

private struct ThemeStub: LumiAppChromeTheme {
    let identifier = "test-theme"
    let displayName = "Test Theme"
    let compactName = "Test"
    let description = "Theme used by ProviderTheme contract tests"
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
private final class ThemeProviderStub: @preconcurrency ThemeProviding {
    let objectWillChange = ObservableObjectPublisher()

    var allThemeContributions: [LumiUIThemeContribution] = []
    var selectedThemeID = "test-theme"
    var activeChromeTheme: any LumiAppChromeTheme = ThemeStub()
    var preferredColorScheme: ColorScheme? = nil

    func selectTheme(_ themeID: String) {}
    func reloadThemes() {}
    func syncToCisumUI() {}
}

@MainActor
struct ThemeProvidingTests {
    @Test
    func defaultObserverUsesNoopFallback() {
        let provider = ThemeProviderStub()
        let handle = provider.addObserver { _ in
            Issue.record("The default theme observer must not receive events")
        }

        #expect(handle is NoopThemeProvidingObserverHandle)
        handle.cancel()
        handle.cancel()
    }

    @Test
    func explicitNoopHandleSupportsRepeatedCancellation() {
        let handle = NoopThemeProvidingObserverHandle()

        handle.cancel()
        handle.cancel()
    }
}
