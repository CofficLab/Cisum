import CisumUIComponents
import LumiUI
import Foundation

/// 主题外观筛选（对齐 Lumi `ThemeSettingsDetailView.ThemeAppearanceFilter`）。
enum ThemeAppearanceFilter: String, CaseIterable, Identifiable {
    case all
    case dark
    case light
    case system

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all:
            return String(localized: "All", bundle: .module)
        case .dark:
            return String(localized: "Black", bundle: .module)
        case .light:
            return String(localized: "Light", bundle: .module)
        case .system:
            return String(localized: "System", bundle: .module)
        }
    }

    func matches(_ kind: ThemeAppearanceKind) -> Bool {
        switch self {
        case .all:
            return true
        case .dark:
            return kind == .dark
        case .light:
            return kind == .light
        case .system:
            return kind == .system
        }
    }
}
