import CisumUIComponents
import LumiUI
import SwiftUI

public struct DaylightSilverTheme: LumiAppChromeTheme {
    public init() {}
    public let identifier = "daylight-silver"
    public let displayName = String(localized: "Daylight Silver", bundle: .module)
    public let compactName = "Daylight Silver"
    public let description = String(localized: "Silver-white light gray interface, ideal for daytime office", bundle: .module)
    public let iconName = "sun.max.fill"
    public let iconColor = Color.adaptive(light: "0A84FF", dark: "64D2FF")
    public let appearanceKind: ThemeAppearanceKind = .light

    public func accentColors() -> (primary: Color, secondary: Color, tertiary: Color) {
        (
            .adaptive(light: "0A84FF", dark: "64D2FF"),
            .adaptive(light: "5E5CE6", dark: "7D7AFF"),
            .adaptive(light: "8E8E93", dark: "AEAEB2")
        )
    }

    public func atmosphereColors() -> (deep: Color, medium: Color, light: Color) {
        (
            .adaptive(light: "F2F3F5", dark: "101114"),
            .adaptive(light: "FFFFFF", dark: "1C1D21"),
            .adaptive(light: "E8ECF2", dark: "2B2D33")
        )
    }

    public func glowColors() -> (subtle: Color, medium: Color, intense: Color) {
        let accents = accentColors()
        return (accents.primary.opacity(0.05), accents.secondary.opacity(0.08), accents.tertiary.opacity(0.10))
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
                RadialGradient(colors: [accents.primary.opacity(0.08), Color.clear], center: .topTrailing, startRadius: 0, endRadius: 540)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .ignoresSafeArea()
            .allowsHitTesting(false)
        )
    }
}
