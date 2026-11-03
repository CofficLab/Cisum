import Foundation
import KernelCore
import LumiThemePack
import LumiUI
import MagicKit
import ProviderPlugin
import ProviderSettingView
import ProviderTheme
import SwiftUI

/// Cisum-only assembly bridge. Theme definitions, registration, and palette
/// conversion live in the remote Lumi packages; this type only connects them
/// to Cisum's legacy root-view registry and settings contribution protocol.
@MainActor
enum CisumThemeBridge {
    private static var controllers: [ObjectIdentifier: Controller] = [:]

    /// Legacy 主题键。
    ///
    /// 旧版本把选中的主题 ID 直接写进 `UserDefaults.standard`。这里改为
    /// 可注入的偏好存储：生产仍用真实偏好，单元测试可以给它一份独立
    /// suite——既不污染开发者的真实配置，结论也不依赖那台机器上
    /// 之前选过什么主题。
    static let legacyThemeIDKey = "Cisum.SelectedThemeID"

    /// 把旧版保存的主题选择迁移到新的主题 Provider。
    ///
    /// - Parameters:
    ///   - provider: 主题 Provider。
    ///   - preferences: 偏好存储。生产传 ``PreferenceStore/shared``。
    static func migrateLegacySelection(
        in provider: DefaultThemeProviding,
        preferences: PreferenceStore = .shared
    ) {
        guard let legacyID = preferences.defaults.string(forKey: legacyThemeIDKey),
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
            guard let kernel else { return }

            kernel.resolveProvider((any SettingViewProviding).self)?.addEntries([
                SettingEntryItem(
                    id: "appearance",
                    title: String(localized: "Appearance", bundle: .module),
                    systemImage: "paintpalette",
                    order: 2
                ) {
                    ThemeSettingsDetailView(theme: self.provider)
                }
            ])
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
