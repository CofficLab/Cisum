import Combine
import Foundation
import LumiUI
import MagicKit
import ProviderTheme

@MainActor
final class ThemeSettingsViewModel: ObservableObject, SuperLog {
    nonisolated static let verbose = false

    @Published private(set) var themes: [LumiUIThemeContribution] = []
    @Published private(set) var currentThemeID = ""

    private weak var themeProvider: (any ThemeProviding)?

    init(themeProvider: (any ThemeProviding)?) {
        self.themeProvider = themeProvider
        refresh()
    }

    func updateThemeProvider(_ provider: (any ThemeProviding)?) {
        themeProvider = provider
        refresh()
    }

    func selectTheme(_ themeID: String) {
        themeProvider?.selectTheme(themeID)
    }

    func handleProviderChanged() {
        refresh()
    }

    private func refresh() {
        themes = themeProvider?.allThemeContributions ?? []
        currentThemeID = themeProvider?.selectedThemeID ?? ""
    }
}
