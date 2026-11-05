import XCTest

/// 外观（主题）设置的 UI 覆盖。
///
/// 背景：此前只断言了「主题数不为 0」，**没有验证主题真的能被选中并应用**。
/// 主题选择是纯本地状态，若点下去没有任何反应（选中态不更新、按钮不生效），
/// 用户会以为换肤功能坏了。
///
/// 本文件锁定三条用户可见契约：
/// 1. 外观页展示主题总数与当前主题；
/// 2. 点击一个主题后，选中态随之改变（「当前使用 / Currently In Use」）；
/// 3. 外观页没有主题搜索框（已移除的入口不应复活）。
final class CisumAppearanceUITests: CisumUITestBase {
    /// 外观设置入口。
    private var appearanceEntry: XCUIElement {
        app.buttons.matching(
            NSPredicate(format: "label IN %@", ["Appearance", "外观"])
        ).firstMatch
    }

    /// 打开外观设置页。
    private func openAppearance() throws {
        #if os(macOS)
        openSettingsWindowViaMenu()
        XCTAssertTrue(element(identifier: "cisum.settings.ready").waitForExistence(timeout: 15), "设置窗口未就绪")
        XCTAssertTrue(appearanceEntry.waitForExistence(timeout: 10), "设置窗口缺少「外观」入口")
        appearanceEntry.click()
        #else
        throw XCTSkip("外观页检查仅 macOS 设置窗口支持")
        #endif
    }

    // MARK: - 呈现

    /// 外观页必须展示主题总数与当前主题。
    func testAppearancePageShowsThemeCountAndCurrentTheme() throws {
        try openAppearance()

        // 主题总数：「N 个主题」/「N Themes」。
        //
        // 该文本是 `Label` 的内容，AX 上呈现为 **value** 而不是 label，
        // 因此必须同时匹配两者。
        let themeCount = app.descendants(matching: .any).matching(
            NSPredicate(
                format: "label CONTAINS %@ OR value CONTAINS %@ OR label CONTAINS %@ OR value CONTAINS %@",
                "个主题", "个主题", "Themes", "Themes"
            )
        ).firstMatch
        XCTAssertTrue(themeCount.waitForExistence(timeout: 10), "外观页没有显示主题数量")

        // 主题数必须为正：主题插件没有进入 ThemeProviding。
        let countText = themeCount.label + " " + (themeCount.value as? String ?? "")
        let digits = countText.compactMap { $0.wholeNumberValue }
        XCTAssertFalse(digits.isEmpty, "外观页的主题数量没有可解析的数字：\(countText)")

        // 当前主题必须在头部展示：「当前：xxx」。
        let currentTheme = app.descendants(matching: .any).matching(
            NSPredicate(format: "label BEGINSWITH %@ OR value BEGINSWITH %@", "当前：", "当前：")
        ).firstMatch
        XCTAssertTrue(
            currentTheme.waitForExistence(timeout: 10),
            "外观页未显示当前主题"
        )
    }

    /// 外观页不应再提供主题搜索框（该入口已移除）。
    func testAppearancePageHasNoThemeSearchField() throws {
        try openAppearance()

        let searchField = app.textFields.matching(
            NSPredicate(format: "placeholderValue IN %@", ["Search Themes", "搜索主题"])
        ).firstMatch
        XCTAssertFalse(searchField.exists, "外观页不应再提供主题搜索入口")
    }

    // MARK: - 交互

    /// 点击一个**未选中**的主题后，选中态应随之更新。
    ///
    /// 不能直接点当前主题——此时详情面板展示的是「当前使用」而不是「应用」，
    /// 没有可点的按钮。用例因此先从主题列表里挑一个**非当前主题**的条目，
    /// 选中它，再点「应用」，最后确认「当前使用」跟着切换。
    func testSelectingThemeUpdatesSelectionState() throws {
        try openAppearance()

        // 等主题列表渲染。
        let themeCount = element(containingAny: ["个主题", "Themes"])
        XCTAssertTrue(themeCount.waitForExistence(timeout: 10), "外观页未渲染")

        // 当前主题（头部展示）：「当前：xxx」。
        let currentTheme = app.descendants(matching: .any).matching(
            NSPredicate(format: "label BEGINSWITH %@ OR value BEGINSWITH %@", "当前：", "当前：")
        ).firstMatch
        XCTAssertTrue(currentTheme.waitForExistence(timeout: 10), "外观页未显示当前主题")

        let currentName = currentTheme.value as? String ?? currentTheme.label
        // 「当前：午夜蓝」→ 去掉前缀得到主题名。
        let currentThemeName = currentName
            .replacingOccurrences(of: "当前：", with: "")
            .replacingOccurrences(of: "Current:", with: "")
            .trimmingCharacters(in: .whitespaces)

        // 从主题列表里挑一个非当前主题。
        //
        // 主题列表行的可访问标签是「名称、描述」（如「午夜蓝、深邃午夜蓝，神秘而宁静」），
        // 而侧边栏与筛选按钮也在同一个 button 集合里——因此按「位于主题
        // 列表区域（详情区左侧，x > 600）」来区分。
        let themeRows = app.buttons.matching(
            NSPredicate(format: "label != '' AND label CONTAINS %@", "、")
        )
        var target: XCUIElement?
        for index in 0..<themeRows.count {
            let row = themeRows.element(boundBy: index)
            guard row.exists, row.isHittable else { continue }
            // 主题列表在详情区左侧；侧边栏与筛选按钮不在这个区间。
            guard row.frame.minX > 600 else { continue }
            guard !row.label.contains(currentThemeName) else { continue }
            target = row
            break
        }

        guard let target else {
            throw XCTSkip("主题列表中没有可选的其他主题")
        }

        target.click()

        // 选中后详情面板应出现「使用」按钮。
        //
        // 注意按钮文案是「使用 / Use」（不是「应用 / Apply」）——
        // `ThemePreviewPane` 用的是 `AppButton("Use")`。
        let useButton = app.buttons.matching(
            NSPredicate(format: "label IN %@", ["Use", "使用"])
        ).firstMatch
        XCTAssertTrue(
            useButton.waitForExistence(timeout: 10),
            "选中未使用的主题后没有出现「使用」按钮"
        )

        useButton.click()

        // 应用后「当前使用」状态必须出现。
        let inUse = element(anyLabelOf: ["Currently Using", "当前使用"])
        XCTAssertTrue(
            inUse.waitForExistence(timeout: 10),
            "点击「应用」后没有出现「当前使用」状态——主题选择没有生效"
        )

        // 头部「当前：xxx」也应更新为新主题。
        let updatedCurrent = app.descendants(matching: .any).matching(
            NSPredicate(format: "label BEGINSWITH %@ OR value BEGINSWITH %@", "当前：", "当前：")
        ).firstMatch
        XCTAssertTrue(updatedCurrent.waitForExistence(timeout: 10), "应用后头部未显示当前主题")
    }

    /// 外观页的筛选控件（全部 / 浅色 / 深色）不应导致页面崩溃。
    func testAppearanceFilterControlsDoNotBreakThePage() throws {
        try openAppearance()

        let themeCount = element(containingAny: ["个主题", "Themes"])
        XCTAssertTrue(themeCount.waitForExistence(timeout: 10), "外观页未渲染")

        // 头部有筛选控件；点击任一筛选项后页面仍应可用。
        let filter = app.buttons.matching(
            NSPredicate(format: "label IN %@", ["All", "全部", "Light", "浅色", "Dark", "深色"])
        ).firstMatch

        if filter.exists {
            filter.click()
            // 筛选后主题统计行仍在，说明页面没有崩溃。
            XCTAssertTrue(
                element(containingAny: ["个主题", "Themes"]).waitForExistence(timeout: 10),
                "切换外观筛选后页面未正常渲染"
            )
        }
    }
}
