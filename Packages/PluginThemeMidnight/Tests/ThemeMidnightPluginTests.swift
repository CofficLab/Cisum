import Testing
@testable import PluginThemeMidnight

@Test func themeIdentityIsStable() {
    let theme = MidnightTheme()
    #expect(!theme.identifier.isEmpty)
    #expect(!theme.displayName.isEmpty)
    #expect(!theme.iconName.isEmpty)
}
