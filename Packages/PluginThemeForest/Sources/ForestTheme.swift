import CisumUIComponents
import LumiUI
import SwiftUI

public struct ForestTheme: LumiAppChromeTheme {
    public init() {}
    public let identifier = "forest"
    public let displayName = String(localized: "Forest Green", bundle: .module)
    public let compactName = "Forest Green"
    public let description = String(localized: "Natural green accents, ideal for long audiobook sessions", bundle: .module)
    public let iconName = "leaf.fill"
    public let iconColor = Color.adaptive(light: "059669", dark: "34D399")
    public let appearanceKind: ThemeAppearanceKind = .system

    public func accentColors() -> (primary: Color, secondary: Color, tertiary: Color) {
        (
            .adaptive(light: "34C759", dark: "30D158"),
            .adaptive(light: "32D74B", dark: "32D74B"),
            .adaptive(light: "30B0C7", dark: "40CBE0")
        )
    }

    public func atmosphereColors() -> (deep: Color, medium: Color, light: Color) {
        (
            .adaptive(light: "F5F8F5", dark: "0B110D"),
            .adaptive(light: "FFFFFF", dark: "151B17"),
            .adaptive(light: "EEF4EF", dark: "202820")
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
