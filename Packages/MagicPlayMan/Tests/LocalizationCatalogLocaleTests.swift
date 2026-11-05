import XCTest
@testable import MagicPlayMan

/// `Localization.catalogLocale` 的语言归一化契约。
///
/// 这层映射决定繁体用户看到哪一份文案，必须满足两点：
/// 1. 映射结果必须是 String Catalog 中**真实存在**的语言 id，
///    否则解析只能靠 Foundation 的 fallback 侥幸命中，且无法区分港台。
/// 2. 香港与台湾必须映射到不同 id，否则两地用户看到同一份用词。
final class LocalizationCatalogLocaleTests: XCTestCase {

    // MARK: - 真实存在的语言 id

    /// Catalog 中实际存在的语言集合（与上游 Lumi 保持一致）。
    private static let catalogLanguages: Set<String> = [
        "en", "zh-Hans", "zh-HK", "zh-TW", "zh-Hant",
    ]

    func testMappedLocaleAlwaysExistsInCatalog() {
        // 只校验中文写法：非中文 locale 原样返回，catalog 不必覆盖每种语言。
        let chineseInputs = [
            "zh_CN", "zh-Hans", "zh-Hans-CN", "zh-SG",
            "zh_HK", "zh-HK", "zh-Hant-HK", "zh-MO",
            "zh_TW", "zh-TW", "zh-Hant-TW",
            "zh-Hant", "zh", "zh-MO",
        ]

        for input in chineseInputs {
            let mapped = Localization.catalogLocale(for: Locale(identifier: input)).identifier
            XCTAssertTrue(
                Self.catalogLanguages.contains(mapped),
                "系统 locale \(input) 映射到 \(mapped)，该语言在 Catalog 中不存在"
            )
        }
    }

    // MARK: - 港台区分

    func testHongKongAndTaiwanMapToDifferentLanguages() {
        let hk = Localization.catalogLocale(for: Locale(identifier: "zh-HK")).identifier
        let tw = Localization.catalogLocale(for: Locale(identifier: "zh-TW")).identifier

        XCTAssertEqual(hk, "zh-HK")
        XCTAssertEqual(tw, "zh-TW")
        XCTAssertNotEqual(hk, tw, "香港与台湾必须映射到不同语言，否则无法区分用词")
    }

    /// 系统的 `zh-Hant-HK` / `zh-Hant-TW` 写法要归一到与 `zh-HK` / `zh-TW` 相同的 id。
    func testTraditionalVariantsNormalizeToRegionalLanguages() {
        XCTAssertEqual(
            Localization.catalogLocale(for: Locale(identifier: "zh-Hant-HK")).identifier,
            "zh-HK"
        )
        XCTAssertEqual(
            Localization.catalogLocale(for: Locale(identifier: "zh-Hant-TW")).identifier,
            "zh-TW"
        )
        XCTAssertEqual(
            Localization.catalogLocale(for: Locale(identifier: "zh_CN")).identifier,
            "zh-Hans"
        )
    }

    /// 通用繁体（无地区）映射到 `zh-Hant`。
    func testGenericTraditionalMapsToHant() {
        XCTAssertEqual(
            Localization.catalogLocale(for: Locale(identifier: "zh-Hant")).identifier,
            "zh-Hant"
        )
        XCTAssertEqual(
            Localization.catalogLocale(for: Locale(identifier: "zh-MO")).identifier,
            "zh-Hant"
        )
    }

    /// 非中文 locale 原样返回，不做改写。
    func testNonChineseLocaleIsUnchanged() {
        for input in ["en_US", "en", "ja", "fr-FR"] {
            XCTAssertEqual(
                Localization.catalogLocale(for: Locale(identifier: input)).identifier,
                Locale(identifier: input).identifier,
                "非中文 locale 不应被改写"
            )
        }
    }

    // MARK: - 回退链

    /// 回退链必须与上游 Lumi 的 `variantFallbacks` 一致，
    /// 否则通用繁体会取不到值而直接掉到英文。
    func testVariantFallbacksMatchLumiConvention() {
        XCTAssertEqual(Localization.variantFallbacks(for: "zh-Hant"), ["zh-Hant", "zh-TW", "zh-HK"])
        XCTAssertEqual(Localization.variantFallbacks(for: "zh-TW"), ["zh-TW", "zh-Hant", "zh-HK"])
        XCTAssertEqual(Localization.variantFallbacks(for: "zh-HK"), ["zh-HK", "zh-Hant", "zh-TW"])
        XCTAssertEqual(Localization.variantFallbacks(for: "zh-Hans"), ["zh-Hans"])
        XCTAssertEqual(Localization.variantFallbacks(for: "en"), ["en"])
    }

    /// 每种繁体写法都能通过回退链取到繁体译文，不会掉到英文。
    func testEveryTraditionalVariantResolvesToTraditionalText() throws {
        let key = "Unlike Current Media"
        let strings = try Self.loadStringCatalog()

        func value(_ language: String) throws -> String {
            let entry = try XCTUnwrap(strings[key] as? [String: Any], "缺少键：\(key)")
            let localizations = try XCTUnwrap(entry["localizations"] as? [String: Any])
            let unit = try XCTUnwrap(localizations[language] as? [String: Any], "缺少 \(language) 翻译")
            let stringUnit = try XCTUnwrap(unit["stringUnit"] as? [String: Any])
            return try XCTUnwrap(stringUnit["value"] as? String)
        }

        let simplified = try value("zh-Hans")
        for language in ["zh-Hant", "zh-HK", "zh-TW"] {
            let resolved = try value(language)
            XCTAssertNotEqual(resolved, key, "\(language) 回退成了英文 key")
            XCTAssertNotEqual(resolved, simplified, "\(language) 命中了简体译文")
        }
    }

    /// 回退链能把任意繁体系统写法解析到繁体译文。
    ///
    /// 直接按 catalog 的真实条目走一遍 `variantFallbacks`，
    /// 确认 `zh-Hant-HK` 这类系统写法不会落到英文。
    func testTraditionalVariantsResolveThroughFallbackChain() {
        // 系统写法 → 期望命中的 catalog 语言
        let expectations: [(system: String, catalog: String)] = [
            ("zh-HK", "zh-HK"),
            ("zh-Hant-HK", "zh-HK"),
            ("zh-TW", "zh-TW"),
            ("zh-Hant-TW", "zh-TW"),
            ("zh-Hant", "zh-Hant"),
            ("zh-MO", "zh-Hant"),
        ]

        for (system, expected) in expectations {
            let target = Localization.catalogLocale(for: Locale(identifier: system)).identifier
            XCTAssertEqual(target, expected, "系统 \(system) 应映射到 \(expected)")

            // 回退链第一个候选必须就是目标语言
            let chain = Localization.variantFallbacks(for: target)
            XCTAssertEqual(chain.first, expected, "系统 \(system) 的回退链首项应为 \(expected)")
            XCTAssertTrue(
                chain.contains("zh-HK") || chain.contains("zh-TW"),
                "系统 \(system) 的回退链必须能落到某个地区繁体"
            )
        }
    }

    /// 读取 `Resources/Localizable.xcstrings` 源文件。
    ///
    /// SPM 测试环境的 Bundle 里只有编译产物，取不到源 catalog，
    /// 因此按 `#filePath` 直接定位仓库中的源文件。
    private static func loadStringCatalog() throws -> [String: Any] {
        let packageRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()   // Tests
            .deletingLastPathComponent()   // MagicPlayMan
        let catalogURL = packageRoot
            .appendingPathComponent("Resources")
            .appendingPathComponent("Localizable.xcstrings")

        let data = try Data(contentsOf: catalogURL)
        let json = try JSONSerialization.jsonObject(with: data)
        return try XCTUnwrap(json as? [String: Any])["strings"] as? [String: Any] ?? [:]
    }
}
