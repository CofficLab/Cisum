import Foundation
import LumiLocalizationKit

/// PluginSettingView 的运行时本地化。
///
/// 委托 `LumiLocalization` 按插件 bundle 的 Localizable 表查找，
/// 未命中时回退到英文原文，保证 UI 不会空白。
public enum LumiPluginLocalization {
    public static func string(_ key: String, bundle: Bundle, locale: Locale = .current) -> String {
        LumiLocalization.string(key, bundle: bundle, locale: locale)
    }
}
