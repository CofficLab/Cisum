import Testing
@testable import PluginThemeMono

@Test func themeIdentityIsStable() {
    let theme = MonoTheme()
    #expect(!theme.identifier.isEmpty)
    #expect(!theme.displayName.isEmpty)
    #expect(!theme.iconName.isEmpty)
}
