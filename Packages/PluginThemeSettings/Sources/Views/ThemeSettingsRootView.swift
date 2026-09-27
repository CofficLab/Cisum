import CisumUIComponents
import LumiUI
import LumiUI
import SwiftUI

public typealias ThemeSettingsSelectThemeAction = @MainActor (String) -> Void

public struct ThemeSettingsRootView: View {
    private let themes: [LumiUIThemeContribution]
    private let currentThemeId: String
    private let selectTheme: ThemeSettingsSelectThemeAction
    @State private var appearanceFilter: ThemeAppearanceFilter = .all

    private var filteredThemes: [LumiUIThemeContribution] {
        themes.filter { appearanceFilter.matches($0.appearanceKind) }
    }

    public init(
        themes: [LumiUIThemeContribution],
        currentThemeId: String,
        selectTheme: @escaping ThemeSettingsSelectThemeAction
    ) {
        self.themes = themes
        self.currentThemeId = currentThemeId
        self.selectTheme = selectTheme
    }

    public var body: some View {
        AppSettingSection(title: String(localized: "Theme Style", bundle: .module)) {
            Picker("", selection: $appearanceFilter) {
                ForEach(ThemeAppearanceFilter.allCases) { filter in
                    Text(filter.title).tag(filter)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            if filteredThemes.isEmpty {
                AppSettingRow(
                    title: String(localized: "No themes in this category", bundle: .module),
                    description: nil,
                    icon: "line.3.horizontal.decrease.circle",
                    action: {}
                ) {
                    EmptyView()
                }
            }

            ForEach(filteredThemes) { theme in
                let isSelected = currentThemeId == theme.id
                AppSettingRow(
                    title: theme.displayName,
                    description: theme.description,
                    icon: theme.iconName,
                    titleSuffix: {
                        if isSelected {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(theme.iconColor)
                        }
                    },
                    action: {
                        selectTheme(theme.id)
                    }
                ) {
                    ThemeSwatches(theme: theme.chromeTheme)
                        .fixedSize()
                }
            }
        }
    }
}

