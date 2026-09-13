import Testing
@testable import PluginThemePaper

@Test func themeIdentityIsStable() {
    let theme = PaperTheme()
    #expect(!theme.identifier.isEmpty)
    #expect(!theme.displayName.isEmpty)
    #expect(!theme.iconName.isEmpty)
}
