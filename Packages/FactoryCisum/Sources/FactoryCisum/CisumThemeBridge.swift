import Foundation
import KernelCore
import LumiThemePack
import LumiUI
import ProviderPlugin
import ProviderTheme
import SwiftUI

/// Cisum-only assembly bridge. Theme definitions, registration, and palette
/// conversion live in the remote Lumi packages; this type only connects them
/// to Cisum's legacy root-view registry and settings contribution protocol.
@MainActor
enum CisumThemeBridge {
    private static var controllers: [ObjectIdentifier: Controller] = [:]

    static func migrateLegacySelection(in provider: DefaultThemeProviding) {
        guard let legacyID = UserDefaults.standard.string(forKey: "Cisum.SelectedThemeID"),
              provider.themes.contains(where: { $0.id == legacyID }) else { return }
        try? provider.selectTheme(id: legacyID)
    }

    static func install(_ provider: DefaultThemeProviding, in kernel: KernelCoreContainer) {
        let controller = Controller(provider: provider, kernel: kernel)
        controllers[ObjectIdentifier(provider)] = controller
    }

    static func remove(_ provider: DefaultThemeProviding) {
        controllers.removeValue(forKey: ObjectIdentifier(provider))
    }

    @MainActor
    private final class Controller {
        private let provider: DefaultThemeProviding
        private weak var kernel: KernelCoreContainer?
        private var observer: (any ThemeProvidingObserverHandle)?

        init(provider: DefaultThemeProviding, kernel: KernelCoreContainer) {
            self.provider = provider
            self.kernel = kernel
            sync()
            observer = provider.addObserver { [weak self] _ in
                self?.sync()
            }
            registerSettingsContribution()
        }

        private func sync() {
            let contributions = provider.themes.map { theme in
                let chrome = LumiPaletteChromeTheme(
                    theme: theme,
                    colorScheme: resolvedColorScheme(for: theme)
                )
                return LumiUIThemeContribution(
                    sortKey: ThemeSortKey(pluginOrder: theme.sortOrder, themeId: theme.id),
                    chromeTheme: chrome,
                    editorThemeId: theme.id
                )
            }

            let registry = LumiUIThemeRegistry.shared
            try? registry.replaceAll(contributions)
            if let selectedID = provider.selectedThemeId {
                try? registry.select(themeId: selectedID)
            }
        }

        private func registerSettingsContribution() {
            guard let kernel,
                  let contributions = kernel.resolveProvider((any PluginContributionProviding).self) else {
                return
            }

            contributions.addSettingNavigationItem(
                ownerPluginID: "com.coffic.cisum.theme-pack",
                PluginSettingNavigationItem(
                    id: "appearance",
                    title: "Appearance",
                    description: "Shared Lumi theme catalog.",
                    iconName: "paintpalette",
                    order: 2,
                    destination: AnyView(ThemeSettingsDetailView(theme: provider))
                )
            )
            contributions.invalidateCaches()
        }

        private func resolvedColorScheme(for theme: ProviderTheme.LumiTheme) -> ColorScheme {
            switch theme.appearanceKind {
            case .dark: .dark
            case .light: .light
            case .system: SystemAppearanceResolver.effectiveColorScheme
            }
        }
    }
}
