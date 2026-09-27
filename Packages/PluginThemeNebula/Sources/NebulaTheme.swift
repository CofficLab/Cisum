import CisumUIComponents
import LumiUI
import SwiftUI

public struct NebulaTheme: LumiAppChromeTheme {
    public init() {}
    public let identifier = "nebula"
    public let displayName = String(localized: "Nebula Pink", bundle: .module)
    public let compactName = "Nebula Pink"
    public let description = String(localized: "Soft pink accents, maintaining clean reading layers", bundle: .module)
    public let iconName = "cloud.moon.fill"
    public let iconColor = Color.adaptive(light: "C026D3", dark: "F0ABFC")
    public let appearanceKind: ThemeAppearanceKind = .dark

    public func accentColors() -> (primary: Color, secondary: Color, tertiary: Color) {
        (
            .adaptive(light: "FF2D55", dark: "FF375F"),
            .adaptive(light: "AF52DE", dark: "BF5AF2"),
            .adaptive(light: "FF9F0A", dark: "FF9F0A")
        )
    }

    public func atmosphereColors() -> (deep: Color, medium: Color, light: Color) {
        (
            .adaptive(light: "FAF5F7", dark: "130E12"),
            .adaptive(light: "FFFFFF", dark: "1D171D"),
            .adaptive(light: "F6EEF2", dark: "29212A")
        )
    }

    public func glowColors() -> (subtle: Color, medium: Color, intense: Color) {
        let accents = accentColors()
        return (accents.primary.opacity(0.05), accents.secondary.opacity(0.08), accents.tertiary.opacity(0.12))
    }

    public func workspaceTextColor() -> Color { .adaptive(light: "1D1D1F", dark: "F5F5F7") }
    public func workspaceSecondaryTextColor() -> Color { .adaptive(light: "515154", dark: "A1A1A6") }
    public func workspaceTertiaryTextColor() -> Color { .adaptive(light: "86868B", dark: "74747A") }

    public func makeGlobalBackground(proxy: GeometryProxy) -> AnyView {
        let colors = atmosphereColors()
        let accents = accentColors()
        return AnyView(
            ZStack {
                LinearGradient(colors: [colors.medium, colors.deep, colors.light], startPoint: .top, endPoint: .bottom)
                RadialGradient(colors: [accents.primary.opacity(0.10), Color.clear], center: .topTrailing, startRadius: 0, endRadius: 560)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .ignoresSafeArea()
            .allowsHitTesting(false)
        )
    }
}
