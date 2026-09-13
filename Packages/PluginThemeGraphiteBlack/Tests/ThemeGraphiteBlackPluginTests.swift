import Testing
@testable import PluginThemeGraphiteBlack

@Test func themeIdentityIsStable() {
    let theme = GraphiteBlackTheme()
    #expect(!theme.identifier.isEmpty)
    #expect(!theme.displayName.isEmpty)
    #expect(!theme.iconName.isEmpty)
}
