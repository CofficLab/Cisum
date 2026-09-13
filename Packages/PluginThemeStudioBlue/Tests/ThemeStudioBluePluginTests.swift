import Testing
@testable import PluginThemeStudioBlue

@Test func themeIdentityIsStable() {
    let theme = StudioBlueTheme()
    #expect(!theme.identifier.isEmpty)
    #expect(!theme.displayName.isEmpty)
    #expect(!theme.iconName.isEmpty)
}
