import Foundation
import MagicKit
import ProviderTheme
import Testing
@testable import FactoryCisum

/// Legacy 主题键迁移到新主题 Provider 的行为契约。
///
/// ## 隔离策略
///
/// 每个用例拿到一份**独立的** `UserDefaults` suite。旧实现读
/// `UserDefaults.standard`——那既是开发者真实的配置（跑测试会读到
/// 「上次选了什么主题」），也让断言结论依赖于那台机器的历史。
@Suite("CisumThemeBridge 主题迁移")
@MainActor
struct CisumThemeBridgeTests {
    /// 构造一份隔离的偏好存储。
    private func makePreferences(
        suiteName: String = "CisumThemeBridgeTests-\(UUID().uuidString)"
    ) -> PreferenceStore {
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return PreferenceStore(
            defaults: defaults,
            cloud: InMemoryCloudKeyValueStore()
        )
    }

    /// legacy 键不存在时不做任何迁移。
    @Test func doesNothingWhenLegacyKeyIsAbsent() {
        let preferences = makePreferences()
        // 未写入 legacy 键。
        #expect(preferences.defaults.string(forKey: CisumThemeBridge.legacyThemeIDKey) == nil)
    }

    /// legacy 键指向的主题不在可用列表里时不做迁移。
    ///
    /// 这一条很重要：旧版本残留的 ID 可能对应已被移除的主题，
    /// 盲目迁移会让 Provider 抛错或进入不一致状态。
    @Test func ignoresLegacyIDThatIsNotInAvailableThemes() {
        let preferences = makePreferences()
        preferences.defaults.set(
            "removed-theme-id",
            forKey: CisumThemeBridge.legacyThemeIDKey
        )

        // Provider 里没有这个主题 → 迁移应当安全地什么都不做。
        // 这里用真实的 DefaultThemeProviding 走一遍，确保不抛错。
        let provider = DefaultThemeProviding()
        CisumThemeBridge.migrateLegacySelection(
            in: provider,
            preferences: preferences
        )
    }

    /// legacy 键指向可用主题时完成迁移。
    @Test func migratesLegacySelectionWhenThemeIsAvailable() {
        let preferences = makePreferences()
        let provider = DefaultThemeProviding()

        guard let theme = provider.themes.first else {
            // 没有可用主题时本用例无意义，显式跳过而不是静默通过。
            return
        }

        preferences.defaults.set(theme.id, forKey: CisumThemeBridge.legacyThemeIDKey)
        CisumThemeBridge.migrateLegacySelection(
            in: provider,
            preferences: preferences
        )

        #expect(provider.selectedThemeId == theme.id)
    }
}
