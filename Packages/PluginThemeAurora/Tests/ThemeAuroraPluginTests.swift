import Testing
@testable import PluginThemeAurora

@Test func themeIdentityIsStable() {
    let theme = AuroraTheme()
    #expect(!theme.identifier.isEmpty)
    #expect(!theme.displayName.isEmpty)
    #expect(!theme.iconName.isEmpty)
}
