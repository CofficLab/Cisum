import CisumUIComponents
import LumiUI
import SwiftUI

public struct SunsetTheme: LumiAppChromeTheme {
    public init() {}
    public let identifier = "sunset"
    public let displayName = String(localized: "Sunset Orange", bundle: .module)
    public let compactName = "Sunset Orange"
    public let description = String(localized: "Warm orange accents, background stays clean white", bundle: .module)
    public let iconName = "sunset.fill"
    public let iconColor = Color.adaptive(light: "EA580C", dark: "FB923C")
    public let appearanceKind: ThemeAppearanceKind = .system

    public func accentColors() -> (primary: Color, secondary: Color, tertiary: Color) {
        (
            .adaptive(light: "FF9500", dark: "FF9F0A"),
            .adaptive(light: "FF3B30", dark: "FF453A"),
            .adaptive(light: "FFD60A", dark: "FFD60A")
        )
    }

    public func atmosphereColors() -> (deep: Color, medium: Color, light: Color) {
        (
            .adaptive(light: "FAF7F2", dark: "120F0B"),
            .adaptive(light: "FFFFFF", dark: "1D1914"),
            .adaptive(light: "F5EFE6", dark: "29231B")
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
