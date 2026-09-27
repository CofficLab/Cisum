import CisumUIComponents
import LumiUI
import SwiftUI

public struct MidnightTheme: LumiAppChromeTheme {
    public init() {}
    public let identifier = "midnight"
    public let displayName = String(localized: "Midnight Blue", bundle: .module)
    public let compactName = "Midnight Blue"
    public let description = String(localized: "Deep gray with blue accents, ideal for night listening", bundle: .module)
    public let iconName = "moon.stars.fill"
    public let iconColor = Color.adaptive(light: "2563EB", dark: "60A5FA")
    public let appearanceKind: ThemeAppearanceKind = .dark

    public func accentColors() -> (primary: Color, secondary: Color, tertiary: Color) {
        (
            .adaptive(light: "2563EB", dark: "60A5FA"),
            .adaptive(light: "007AFF", dark: "0A84FF"),
            .adaptive(light: "5AC8FA", dark: "64D2FF")
        )
    }

    public func atmosphereColors() -> (deep: Color, medium: Color, light: Color) {
        (
            .adaptive(light: "F5F7FA", dark: "090B10"),
            .adaptive(light: "FFFFFF", dark: "14171D"),
            .adaptive(light: "EEF3FA", dark: "20242C")
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
