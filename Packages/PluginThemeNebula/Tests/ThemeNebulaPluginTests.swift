import Testing
@testable import PluginThemeNebula

@Test func themeIdentityIsStable() {
    let theme = NebulaTheme()
    #expect(!theme.identifier.isEmpty)
    #expect(!theme.displayName.isEmpty)
    #expect(!theme.iconName.isEmpty)
}
