import CisumUIComponents
import LumiUI
import SwiftUI

public struct StudioBlueTheme: LumiAppChromeTheme {
    public init() {}
    public let identifier = "studio-blue"
    public let displayName = String(localized: "Studio Blue", bundle: .module)
    public let compactName = "Studio Blue"
    public let description = String(localized: "Blue-gray studio texture, ideal for focused listening", bundle: .module)
    public let iconName = "waveform"
    public let iconColor = Color.adaptive(light: "007AFF", dark: "5AC8FA")
    public let appearanceKind: ThemeAppearanceKind = .system

    public func accentColors() -> (primary: Color, secondary: Color, tertiary: Color) {
        (
            .adaptive(light: "007AFF", dark: "5AC8FA"),
            .adaptive(light: "30D158", dark: "32D74B"),
            .adaptive(light: "5856D6", dark: "7D7AFF")
        )
    }

    public func atmosphereColors() -> (deep: Color, medium: Color, light: Color) {
        (
            .adaptive(light: "EEF4F8", dark: "071017"),
            .adaptive(light: "FFFFFF", dark: "111B24"),
            .adaptive(light: "DDEAF2", dark: "20303C")
        )
    }

    public func glowColors() -> (subtle: Color, medium: Color, intense: Color) {
        let accents = accentColors()
        return (accents.primary.opacity(0.05), accents.secondary.opacity(0.08), accents.tertiary.opacity(0.11))
    }

    public func workspaceTextColor() -> Color { .adaptive(light: "17202A", dark: "F3F8FC") }
    public func workspaceSecondaryTextColor() -> Color { .adaptive(light: "4B5A67", dark: "A9B8C5") }
    public func workspaceTertiaryTextColor() -> Color { .adaptive(light: "7B8791", dark: "7F8D99") }

    public func makeGlobalBackground(proxy: GeometryProxy) -> AnyView {
        let colors = atmosphereColors()
        let accents = accentColors()
        return AnyView(
            ZStack {
                LinearGradient(colors: [colors.medium, colors.deep, colors.light], startPoint: .top, endPoint: .bottom)
                RadialGradient(colors: [accents.primary.opacity(0.09), Color.clear], center: .topTrailing, startRadius: 0, endRadius: 560)
                RadialGradient(colors: [accents.secondary.opacity(0.05), Color.clear], center: .bottomLeading, startRadius: 0, endRadius: 440)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .ignoresSafeArea()
            .allowsHitTesting(false)
        )
    }
}
