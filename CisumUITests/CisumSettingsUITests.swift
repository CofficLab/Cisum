import XCTest

/// 设置窗口：入口呈现、侧边栏导航与各设置页内容。
final class CisumSettingsUITests: CisumUITestBase {
    func testSettingsWindowShowsSidebarEntries() throws {
        #if os(macOS)
        openSettingsWindowViaMenu()
        XCTAssertTrue(element(identifier: "cisum.settings.ready").waitForExistence(timeout: 15), "设置窗口未就绪")
        let generalEntry = element(anyLabelOf: ["General", "通用"])
        XCTAssertTrue(generalEntry.waitForExistence(timeout: 5), "设置窗口缺少「通用」入口")
        #else
        throw XCTSkip("设置窗口仅 macOS 支持")
        #endif
    }

    func testSettingsStorageEntryShowsRepositoryInfo() throws {
        #if os(macOS)
        openSettingsWindowViaMenu()
        XCTAssertTrue(element(identifier: "cisum.settings.ready").waitForExistence(timeout: 15))
        let storageEntry = element(anyLabelOf: ["Storage Settings", "存储设置", "音乐仓库"])
        XCTAssertTrue(storageEntry.waitForExistence(timeout: 5), "设置窗口缺少存储设置入口")
        storageEntry.click()

        XCTAssertTrue(element(identifier: "cisum.settings.storage.location").waitForExistence(timeout: 5), "存储设置页缺少「媒体存储位置」区块")
        XCTAssertTrue(element(identifier: "cisum.settings.storage.icloud").exists, "缺少 iCloud 存储选项")
        XCTAssertTrue(element(identifier: "cisum.settings.storage.local").exists, "缺少本地存储选项")
        #else
        throw XCTSkip("设置窗口仅 macOS 支持")
        #endif
    }

    func testAppearanceSettingsShowsAvailableThemes() throws {
        #if os(macOS)
        openSettingsWindowViaMenu()
        XCTAssertTrue(element(identifier: "cisum.settings.ready").waitForExistence(timeout: 15))
        let appearanceEntry = element(anyLabelOf: ["Appearance", "外观"])
        XCTAssertTrue(appearanceEntry.waitForExistence(timeout: 5), "设置窗口缺少外观设置入口")
        appearanceEntry.click()

        let themeCount = element(containingAny: ["themes", "主题"])
        XCTAssertTrue(themeCount.waitForExistence(timeout: 10), "外观页没有显示主题数量")
        XCTAssertFalse(element(anyLabelOf: ["0 themes", "0 个主题"]).exists, "外观页主题数为 0，主题插件贡献没有进入 ThemeProviding")
        let themeSearch = app.textFields.matching(NSPredicate(format: "placeholderValue IN %@", ["Search Themes", "搜索主题"])).firstMatch
        XCTAssertTrue(themeSearch.waitForExistence(timeout: 5), "外观页没有主题搜索入口")
        XCTAssertTrue(element(anyLabelOf: ["Use This Theme", "使用此主题", "Currently In Use", "当前使用", "目前使用"]).waitForExistence(timeout: 5), "外观页没有显示选中主题的应用状态")
        #else
        throw XCTSkip("外观设置窗口仅 macOS 支持")
        #endif
    }
}
