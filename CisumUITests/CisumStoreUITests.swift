import XCTest

/// 商店（内购 / 订阅）设置的 UI 覆盖。
///
/// 背景：商店页此前**完全没有 UI 测试**——而它是「免费用户撞容量上限后
/// 唯一能付费的入口」。这条链路一旦断裂（入口不见了、按钮点不动、
/// 面板弹不出来），用户就只能干等。
///
/// 本文件锁定三条用户可见契约：
/// 1. 设置窗口里存在「商店」入口，且能点进商店页；
/// 2. 商店页展示当前订阅档位与状态，并提供「购买 / 恢复」两个入口；
/// 3. 点击「购买」能弹出购买面板，「恢复」能弹出恢复面板。
final class CisumStoreUITests: CisumUITestBase {
    /// 商店设置入口（macOS 侧边栏 / iOS 设置列表）。
    private var storeEntry: XCUIElement {
        element(anyLabelOf: ["Store", "商店"])
    }

    /// 「购买」按钮的可访问标签。
    ///
    /// 必须按 **button 类型**匹配：按 `.any` 匹配会先命中同名的说明文字
    /// （StaticText），点击它不会触发任何动作。
    private var purchaseButton: XCUIElement {
        app.buttons.matching(
            NSPredicate(format: "label IN %@", ["In-App Purchase", "应用内购买"])
        ).firstMatch
    }

    /// 「恢复购买」按钮的可访问标签。
    private var restoreButton: XCUIElement {
        app.buttons.matching(
            NSPredicate(format: "label IN %@", ["Restore Purchase", "恢复购买"])
        ).firstMatch
    }

    // MARK: - 入口

    /// 设置窗口必须存在商店入口。
    func testSettingsWindowContainsStoreEntry() throws {
        #if os(macOS)
        openSettingsWindowViaMenu()
        XCTAssertTrue(element(identifier: "cisum.settings.ready").waitForExistence(timeout: 15), "设置窗口未就绪")

        XCTAssertTrue(
            storeEntry.waitForExistence(timeout: 10),
            "设置窗口缺少「商店」入口——用户将无法购买订阅"
        )
        #else
        throw XCTSkip("商店设置入口检查仅 macOS 支持")
        #endif
    }

    /// 点击商店入口后必须进入商店页。
    func testTappingStoreEntryShowsSubscriptionInformation() throws {
        #if os(macOS)
        openSettingsWindowViaMenu()
        XCTAssertTrue(element(identifier: "cisum.settings.ready").waitForExistence(timeout: 15))

        XCTAssertTrue(storeEntry.waitForExistence(timeout: 10), "设置窗口缺少「商店」入口")
        storeEntry.click()

        // 商店页标题区块。
        let subscriptionSection = element(anyLabelOf: [
            "Subscription Information", "订阅信息",
        ])
        XCTAssertTrue(
            subscriptionSection.waitForExistence(timeout: 10),
            "点击「商店」后没有进入商店页"
        )
        #else
        throw XCTSkip("商店页检查仅 macOS 支持")
        #endif
    }

    // MARK: - 内容

    /// 商店页必须展示当前档位与订阅状态。
    func testStorePageShowsTierAndStatus() throws {
        #if os(macOS)
        openSettingsWindowViaMenu()
        XCTAssertTrue(element(identifier: "cisum.settings.ready").waitForExistence(timeout: 15))
        XCTAssertTrue(storeEntry.waitForExistence(timeout: 10))
        storeEntry.click()

        let currentVersion = element(anyLabelOf: ["Current Version", "当前版本"])
        XCTAssertTrue(currentVersion.waitForExistence(timeout: 10), "商店页缺少「当前版本」行")

        let status = element(anyLabelOf: ["Subscription Status", "订阅状态"])
        XCTAssertTrue(status.waitForExistence(timeout: 10), "商店页缺少「订阅状态」行")

        // 状态值：免费用户显示 Free，付费用户显示 Active / Expired。
        let statusValue = element(anyLabelOf: ["Free", "免费版", "Active", "活跃", "Expired", "已过期"])
        XCTAssertTrue(statusValue.waitForExistence(timeout: 10), "商店页未显示订阅状态值")
        #else
        throw XCTSkip("商店页内容检查仅 macOS 支持")
        #endif
    }

    /// 商店页必须提供购买与恢复两个入口。
    func testStorePageOffersPurchaseAndRestoreActions() throws {
        #if os(macOS)
        openSettingsWindowViaMenu()
        XCTAssertTrue(element(identifier: "cisum.settings.ready").waitForExistence(timeout: 15))
        XCTAssertTrue(storeEntry.waitForExistence(timeout: 10))
        storeEntry.click()

        XCTAssertTrue(
            purchaseButton.waitForExistence(timeout: 10),
            "商店页缺少「购买」入口——用户无法完成购买"
        )
        XCTAssertTrue(
            restoreButton.waitForExistence(timeout: 10),
            "商店页缺少「恢复购买」入口——换设备后用户无法恢复权益"
        )
        #else
        throw XCTSkip("商店页动作检查仅 macOS 支持")
        #endif
    }

    // MARK: - 交互

    /// 点击「购买」应弹出购买面板。
    func testPurchaseActionPresentsSheet() throws {
        #if os(macOS)
        openSettingsWindowViaMenu()
        XCTAssertTrue(element(identifier: "cisum.settings.ready").waitForExistence(timeout: 15))
        XCTAssertTrue(storeEntry.waitForExistence(timeout: 10))
        storeEntry.click()

        XCTAssertTrue(purchaseButton.waitForExistence(timeout: 10), "商店页缺少「购买」入口")
        purchaseButton.click()

        // 购买面板以 sheet 形式呈现。
        let sheet = app.sheets.firstMatch
        let sheetWindow = app.windows.matching(
            NSPredicate(format: "identifier CONTAINS[c] %@ OR label CONTAINS[c] %@", "Purchase", "购买")
        ).firstMatch

        XCTAssertTrue(
            sheet.waitForExistence(timeout: 10) || sheetWindow.waitForExistence(timeout: 2),
            "点击「购买」后没有弹出购买面板"
        )
        #else
        throw XCTSkip("购买面板检查仅 macOS 支持")
        #endif
    }

    /// 点击「恢复购买」应弹出恢复面板。
    func testRestoreActionPresentsSheet() throws {
        #if os(macOS)
        openSettingsWindowViaMenu()
        XCTAssertTrue(element(identifier: "cisum.settings.ready").waitForExistence(timeout: 15))
        XCTAssertTrue(storeEntry.waitForExistence(timeout: 10))
        storeEntry.click()

        XCTAssertTrue(restoreButton.waitForExistence(timeout: 10), "商店页缺少「恢复购买」入口")
        restoreButton.click()

        let sheet = app.sheets.firstMatch
        let restoreWindow = app.windows.matching(
            NSPredicate(format: "identifier CONTAINS[c] %@ OR label CONTAINS[c] %@", "Restore", "恢复")
        ).firstMatch

        XCTAssertTrue(
            sheet.waitForExistence(timeout: 10) || restoreWindow.waitForExistence(timeout: 2),
            "点击「恢复购买」后没有弹出恢复面板"
        )
        #else
        throw XCTSkip("恢复面板检查仅 macOS 支持")
        #endif
    }

    /// 关闭设置窗口后商店状态不得残留（面板不应留在主窗口上）。
    ///
    /// 购买面板是**模态 sheet**：它会挡住设置窗口的关闭按钮，
    /// 因此必须先关掉面板再关设置窗口。
    func testClosingSettingsWindowLeavesNoPurchasePanelBehind() throws {
        #if os(macOS)
        openSettingsWindowViaMenu()
        XCTAssertTrue(element(identifier: "cisum.settings.ready").waitForExistence(timeout: 15))
        XCTAssertTrue(storeEntry.waitForExistence(timeout: 10))
        storeEntry.click()

        XCTAssertTrue(purchaseButton.waitForExistence(timeout: 10))
        purchaseButton.click()
        XCTAssertTrue(app.sheets.firstMatch.waitForExistence(timeout: 10), "购买面板未弹出")

        // 先关闭购买面板（模态 sheet 会挡住设置窗口的关闭按钮）。
        let sheetClose = app.buttons.matching(
            NSPredicate(format: "label IN %@", ["Close", "关闭"])
        ).firstMatch
        if sheetClose.exists {
            sheetClose.click()
            XCTAssertTrue(
                app.sheets.firstMatch.waitForNonExistence(timeout: 10),
                "点击关闭后购买面板没有消失"
            )
        }

        closeSettingsWindow()

        // 设置窗口关闭后，主窗口不应残留任何 sheet。
        XCTAssertFalse(
            app.sheets.firstMatch.exists,
            "关闭设置窗口后购买面板仍残留在主窗口上"
        )
        #else
        throw XCTSkip("设置窗口关闭检查仅 macOS 支持")
        #endif
    }
}
