import CisumUIComponents
import LumiUI
import SwiftUI

public struct MonoTheme: LumiAppChromeTheme {
    public init() {}
    public let identifier = "mono"
    public let displayName = String(localized: "Mono High Contrast", bundle: .module)
    public let compactName = "Mono High Contrast"
    public let description = String(localized: "Minimal grayscale, emphasizing content itself", bundle: .module)
    public let iconName = "circle.lefthalf.filled"
    public let iconColor = Color.adaptive(light: "111827", dark: "FFFFFF")
    public let appearanceKind: ThemeAppearanceKind = .dark

    public func accentColors() -> (primary: Color, secondary: Color, tertiary: Color) {
        (
            .adaptive(light: "1D1D1F", dark: "F5F5F7"),
            .adaptive(light: "6E6E73", dark: "A1A1A6"),
            .adaptive(light: "8E8E93", dark: "8E8E93")
        )
    }

    public func atmosphereColors() -> (deep: Color, medium: Color, light: Color) {
        (
            .adaptive(light: "F5F5F7", dark: "0B0B0F"),
            .adaptive(light: "FFFFFF", dark: "151519"),
            .adaptive(light: "EEEEF0", dark: "202027")
        )
    }

    public func glowColors() -> (subtle: Color, medium: Color, intense: Color) {
        let accents = accentColors()
        return (accents.primary.opacity(0.03), accents.secondary.opacity(0.05), accents.tertiary.opacity(0.08))
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
                RadialGradient(colors: [accents.primary.opacity(0.06), Color.clear], center: .topTrailing, startRadius: 0, endRadius: 560)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .ignoresSafeArea()
            .allowsHitTesting(false)
        )
    }
}
