import Foundation
import Testing
#if canImport(AppKit)
import AppKit
#endif
@testable import PluginAbout

/// 应用目录的数据契约测试。
///
/// 这些断言守的是「用户点到的链接必须真的存在」——目录里写错一个
/// slug，用户点下去就是 404。
struct CofficAppsTests {
    @Test
    func catalogContainsExpectedApps() {
        let ids = CofficApps.all.map(\.id)
        #expect(ids.contains("lumi"))
        #expect(ids.contains("gitok"))
        #expect(ids.contains("wakey"))
    }

    @Test
    func appIdentifiersAreUnique() {
        let ids = CofficApps.all.map(\.id)
        #expect(Set(ids).count == ids.count)
    }

    @Test
    func everyAppUsesHttpsCofficURL() throws {
        for app in CofficApps.all {
            let url = try #require(URL(string: app.urlString))
            #expect(url.scheme == "https")
            #expect(url.host == "coffic.cn")
        }
    }

    @Test
    func allProductsEntryPointsToCatalogPage() throws {
        let url = try #require(URL(string: CofficApps.allProductsURLString))
        #expect(url.absoluteString == "https://coffic.cn/products")
    }

    /// 每个应用都必须有名字、图标和简介 key——缺一项列表里就会出现空行。
    @Test
    func everyAppHasCompletePresentationData() {
        for app in CofficApps.all {
            #expect(!app.name.isEmpty)
            #expect(!app.systemImage.isEmpty)
            #expect(!app.taglineKey.isEmpty)
        }
    }

    /// 图标名必须是真实存在的 SF Symbol。
    ///
    /// GitOK 曾写成不存在的 `git-branch`，`Image(systemName:)` 不会报错，
    /// 只是把这一行渲染成没有图标的空白——只能靠断言符号可解析来兜住。
    @Test
    func everySystemImageResolvesToRealSymbol() {
        #if canImport(AppKit)
        for app in CofficApps.all {
            #expect(
                NSImage(systemSymbolName: app.systemImage, accessibilityDescription: nil) != nil,
                "\(app.id) 的图标 \(app.systemImage) 不是有效的 SF Symbol"
            )
        }
        #endif
    }

    /// 已下架的产品不应再出现在列表里。
    @Test
    func retiredAppsAreRemoved() {
        let ids = Set(CofficApps.all.map(\.id))
        #expect(!ids.contains("juice-note"))
        #expect(!ids.contains("juice-editor"))
        #expect(!ids.contains("buddy"))
    }

    /// 每个应用的简介都必须在字符串目录里有中文译文，
    /// 否则中文用户会看到英文原句（甚至直接看到 key）。
    @Test
    func everyAppTaglineHasChineseTranslation() throws {
        for app in CofficApps.all {
            let translated = try #require(Self.localizedIn(language: "zh-Hans", app.taglineKey))
            #expect(translated != app.taglineKey)
        }
    }

    /// 区块标题与「全部产品」入口也必须有中文译文。
    @Test
    func sectionStringsHaveChineseTranslation() throws {
        #expect(try #require(Self.localizedIn(language: "zh-Hans", "Our Apps")) == "我们的应用")
        #expect(try #require(Self.localizedIn(language: "zh-Hans", "All Products")) == "全部产品")
    }

    /// 「关于」页新增的法律链接文案也必须有中文译文。
    @Test
    func aboutStringsHaveChineseTranslation() throws {
        #expect(try #require(Self.localizedIn(language: "zh-Hans", "About")) == "关于")
        #expect(try #require(Self.localizedIn(language: "zh-Hans", "About Us")) == "关于我们")
        #expect(try #require(Self.localizedIn(language: "zh-Hans", "Official Website")) == "官方网站")
        #expect(try #require(Self.localizedIn(language: "zh-Hans", "Privacy Policy")) == "隐私政策")
        #expect(try #require(Self.localizedIn(language: "zh-Hans", "Terms of Service")) == "服务条款")
    }

    /// 按编译产物里的 `.lproj` 解析字符串，验证译文确实被打包进去。
    private static func localizedIn(language: String, _ key: String) -> String? {
        guard let path = Bundle.module.path(forResource: language, ofType: "lproj"),
              let languageBundle = Bundle(path: path) else { return nil }
        let value = languageBundle.localizedString(forKey: key, value: "\u{FFFF}", table: "Localizable")
        return value == "\u{FFFF}" ? nil : value
    }
}
