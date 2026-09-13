import Testing
@testable import PluginThemeSunset

@Test func themeIdentityIsStable() {
    let theme = SunsetTheme()
    #expect(!theme.identifier.isEmpty)
    #expect(!theme.displayName.isEmpty)
    #expect(!theme.iconName.isEmpty)
}
