import CisumUIComponents
import LumiUI
import SwiftUI

public struct CisumTheme: LumiAppChromeTheme {
    public init() {}
    public let identifier = "cisum"
    public let displayName = String(localized: "Cisum", bundle: .module)
    public let compactName = "Cisum"
    public let description = String(localized: "Original sunset gradient color scheme", bundle: .module)
    public let iconName = "sunset.fill"
    public let iconColor = Color.adaptive(light: "FF512F", dark: "FF8A4C")
    public let appearanceKind: ThemeAppearanceKind = .system

    public func accentColors() -> (primary: Color, secondary: Color, tertiary: Color) {
        (
            .adaptive(light: "FF512F", dark: "FF8A4C"),
            .adaptive(light: "F09819", dark: "FBBF24"),
            .adaptive(light: "4A90E2", dark: "60A5FA")
        )
    }

    public func atmosphereColors() -> (deep: Color, medium: Color, light: Color) {
        (
            Color.adaptive(light: "FF512F", dark: "2A0E08").opacity(0.18),
            Color.adaptive(light: "F09819", dark: "3A1C0A").opacity(0.18),
            Color.adaptive(light: "FFFFFF", dark: "5A2A12").opacity(0.34)
        )
    }

    public func glowColors() -> (subtle: Color, medium: Color, intense: Color) {
        let accents = accentColors()
        return (
            accents.primary.opacity(0.12),
            accents.secondary.opacity(0.2),
            accents.tertiary.opacity(0.32)
        )
    }

    public func workspaceTextColor() -> Color {
        .adaptive(light: "1C1C1E", dark: "FFFFFF")
    }

    public func workspaceSecondaryTextColor() -> Color {
        .adaptive(light: "3A2A22", dark: "F5E6DC")
    }

    public func workspaceTertiaryTextColor() -> Color {
        .adaptive(light: "6F5147", dark: "D7B7A5")
    }

    public func makeGlobalBackground(proxy: GeometryProxy) -> AnyView {
        AnyView(
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.adaptive(light: "FF512F", dark: "2A0E08").opacity(0.7),
                    Color.adaptive(light: "F09819", dark: "7C2D12").opacity(0.7),
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
            .background(.ultraThinMaterial)
            .ignoresSafeArea()
        )
    }
}
