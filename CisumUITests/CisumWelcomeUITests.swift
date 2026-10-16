import XCTest

/// 首启存储引导（onboarding）需求规格测试。
///
/// 新用户首次打开 App 时的期望流程：
///
/// 1. [R1] 没有已保存的存储位置 → 全屏引导覆盖主界面，用户必须先完成选择；
///    点击空白区域不可跳过引导。
/// 2. [R2] 引导展示标题、说明与两个选项（iCloud 云盘 / 应用本地存储）；
///    iCloud 不可用时禁用 iCloud 行并给出提示。
/// 3. [R3] 进入引导即展示默认预选（iCloud 可用 → iCloud，否则本地），
///    勾选状态必须真实反映"将被提交的选择"，不允许假勾选。
/// 4. [R4] 点击选项行只切换选择（草稿），不立即关闭引导。
/// 5. [R5] 页面必须提供「继续 / Continue」按钮，点击后提交当前选择。
/// 6. [R6] 提交后引导关闭，主界面就绪（音乐场景可用），且不出现仓库错误弹窗。
/// 7. [R7] 已有有效存储位置的用户启动时不再显示引导。
///
/// 交互模型（已确认）：**默认预选 + 继续按钮直接提交** ——
/// 用户不碰任何选项行时，点「继续」即可用预选完成引导。
final class CisumWelcomeUITests: CisumUITestBase {
    override var additionalLaunchArguments: [String] {
        ["--cisum-ui-testing", "--cisum-ui-testing-reset-storage"]
    }

    private var setupGate: XCUIElement {
        element(identifier: "cisum.welcome.storage.setup")
    }

    private var continueButton: XCUIElement {
        element(identifier: "cisum.welcome.storage.continue")
    }

    private var iCloudOption: XCUIElement {
        element(identifier: "cisum.welcome.storage.option.icloud")
    }

    private var localStorageOption: XCUIElement {
        element(identifier: "cisum.welcome.storage.option.local")
    }

    private var storageChoiceTitle: XCUIElement {
        element(anyLabelOf: ["Choose Your Media Storage", "选择媒体存储位置"])
    }

    private var continueButtonLabel: XCUIElement {
        element(anyLabelOf: ["Continue", "继续"])
    }

    /// [R1][R2][R3] 首启必须展示完整的选择界面：标题、两个选项、继续按钮，
    /// 且点击空白区域不能跳过引导。
    func testFirstLaunchShowsStorageChoiceAndCannotBeSkippedByBackgroundTap() throws {
        XCTAssertTrue(setupGate.waitForExistence(timeout: 10), "首次启动应阻止进入主界面并要求选择存储位置")
        XCTAssertTrue(storageChoiceTitle.waitForExistence(timeout: 5), "欢迎页标题未出现")
        XCTAssertTrue(iCloudOption.exists, "缺少 iCloud 云盘选项")
        XCTAssertTrue(localStorageOption.exists, "缺少应用本地存储选项")
        XCTAssertTrue(
            continueButton.waitForExistence(timeout: 5),
            "R5 违反：引导页缺少「继续」按钮，用户选完后无法进入下一步"
        )

#if os(macOS)
        let window = app.windows.firstMatch
        assertElementFitsWindow(
            storageChoiceTitle,
            window: window,
            description: "欢迎页标题"
        )
        assertElementFitsWindow(
            continueButton,
            window: window,
            description: "「继续」按钮"
        )
#else
        let window = app.windows.firstMatch
        XCTAssertTrue(
            window.frame.insetBy(dx: -2, dy: -2).contains(storageChoiceTitle.frame),
            "欢迎页标题超出屏幕：title=\(storageChoiceTitle.frame), window=\(window.frame)"
        )
#endif

        // [R1] 点击引导页空白区域不应关闭引导。
        let backgroundPoint = setupGate.coordinate(withNormalizedOffset: CGVector(dx: 0.06, dy: 0.30))
        backgroundPoint.tap()
        XCTAssertTrue(
            setupGate.exists,
            "R1 违反：点击引导页空白区域跳过了存储选择"
        )
    }

    /// [R3][R5][R6] 默认预选模型：用户不碰任何选项行，直接点「继续」即可完成引导。
    ///
    /// 这是"用户看着已勾选的 iCloud 却找不到下一步"缺陷的回归测试。
    func testFirstLaunchCompletesWithDefaultSelectionAfterTappingContinue() throws {
        XCTAssertTrue(setupGate.waitForExistence(timeout: 10), "首次启动应阻止进入主界面并要求选择存储位置")
        XCTAssertTrue(
            continueButton.waitForExistence(timeout: 5),
            "R5 违反：引导页缺少「继续」按钮，用户选完后无法进入下一步"
        )

#if os(macOS)
        continueButton.click()
#else
        continueButton.tap()
#endif

        XCTAssertTrue(
            setupGate.waitForNonExistence(timeout: 10),
            "R6 违反：点击「继续」后引导未关闭（默认预选未被提交）"
        )
        XCTAssertTrue(
            element(identifier: "cisum.scene.music").waitForExistence(timeout: 10),
            "完成引导后音乐仓库未就绪"
        )
        XCTAssertFalse(
            element(containing: "音频仓库不可用").exists,
            "配置存储时不应被通用仓库错误弹窗打断"
        )
    }

    /// [R4][R5] 点击选项行只切换选择、不关闭引导；必须再点「继续」才提交。
    func testFirstLaunchPersistsChosenLocalOnlyAfterTappingContinue() throws {
        XCTAssertTrue(setupGate.waitForExistence(timeout: 10), "首次启动应阻止进入主界面并要求选择存储位置")
        XCTAssertTrue(
            continueButton.waitForExistence(timeout: 5),
            "R5 违反：引导页缺少「继续」按钮，用户选完后无法进入下一步"
        )

#if os(macOS)
        localStorageOption.click()
#else
        localStorageOption.tap()
#endif

        let stillGating = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == true"),
            object: setupGate
        )
        XCTAssertEqual(
            XCTWaiter.wait(for: [stillGating], timeout: 1.5),
            .completed,
            "R4 违反：点击选项行立即提交并关闭了引导，用户还没点「继续」"
        )
        XCTAssertTrue(
            continueButton.exists,
            "R5 违反：切换选择后「继续」按钮消失"
        )

#if os(macOS)
        continueButton.click()
#else
        continueButton.tap()
#endif

        XCTAssertTrue(
            setupGate.waitForNonExistence(timeout: 10),
            "R6 违反：点击「继续」后引导未关闭"
        )
        XCTAssertTrue(
            element(identifier: "cisum.scene.music").waitForExistence(timeout: 10),
            "完成引导后音乐仓库未就绪"
        )
        XCTAssertFalse(
            element(containing: "音频仓库不可用").exists,
            "配置存储时不应被通用仓库错误弹窗打断"
        )
    }

    /// [R8] 选择媒体存储位置界面**不应出现顶部工具栏**。
    ///
    /// 复现的缺陷：引导（`cisum.welcome.storage.setup`）只是覆盖在根视图之上的
    /// overlay，而顶部工具栏由内层 `CisumRootLayoutView.toolbar` 无条件贡献，
    /// 于是首启选择存储位置时窗口顶部依然挂着设置按钮、场景切换器等功能入口。
    ///
    /// 分两层断言：
    /// 1. 具体的工具栏功能入口（设置按钮 / 场景切换器）不应存在；
    /// 2. 整个工具栏不应留下任何可交互控件。
    func testStorageSetupScreenHidesTopToolbar() throws {
        XCTAssertTrue(setupGate.waitForExistence(timeout: 10), "首次启动应展示存储引导")

        let knownToolbarEntries: [(String, String)] = [
            ("cisum.settings.button", "设置按钮"),
            ("cisum.scene.switcher", "场景切换器"),
        ]
        var leakedEntries: [String] = []
        for (identifier, name) in knownToolbarEntries {
            if element(identifier: identifier).exists {
                leakedEntries.append("\(name)(\(identifier))")
            }
        }
        XCTAssertTrue(
            leakedEntries.isEmpty,
            "选择媒体存储位置时不应显示顶部工具栏，但工具栏入口仍然可见：\(leakedEntries.joined(separator: ", "))"
        )

#if os(macOS)
        let window = app.windows["Cisum"]
        XCTAssertTrue(window.waitForExistence(timeout: 5), "主窗口未出现")

        let controls = interactiveToolbarControls(in: window)
        XCTAssertTrue(
            controls.isEmpty,
            "选择媒体存储位置时顶部工具栏不应有任何控件，但发现 \(controls.count) 个：\(controls.joined(separator: " | "))"
        )
#else
        // iOS 没有 NSToolbar，等价约束是：引导为全屏覆盖层，
        // 主界面的工具栏/导航入口既不可见也不可命中。
        let sceneSwitcher = element(identifier: "cisum.scene.switcher")
        if sceneSwitcher.exists {
            sceneSwitcher.tap()
            XCTAssertFalse(
                element(identifier: "cisum.scene.option.music").waitForExistence(timeout: 2),
                "选择媒体存储位置时场景切换器仍可点击，用户能在未配置存储前切换场景"
            )
        }
        XCTAssertFalse(
            element(identifier: "cisum.kernel.startup-error").exists,
            "选择媒体存储位置时不应出现启动错误屏"
        )
#endif
    }

    /// [R7] 引导文案必须中英文都存在（本地化不缺失）。
    func testFirstLaunchCopyIsLocalized() throws {
        XCTAssertTrue(setupGate.waitForExistence(timeout: 10), "首次启动应阻止进入主界面并要求选择存储位置")
        XCTAssertTrue(
            element(containingAny: [
                "Choose where Cisum stores your music and audiobooks",
                "选择 Cisum 存储音乐和有声书的位置",
            ]).exists,
            "欢迎页缺少存储位置说明文案（中/英）"
        )
        XCTAssertTrue(
            continueButtonLabel.exists,
            "「继续 / Continue」按钮文案缺失"
        )
    }
}

final class CisumConfiguredWelcomeUITests: CisumUITestBase {
    func testExistingStorageSkipsWelcomeGuide() {
        XCTAssertFalse(element(identifier: "cisum.welcome.storage.setup").waitForExistence(timeout: 2), "已有有效存储位置时不应重复展示首次启动引导")
    }

    /// 已有存储位置（引导不展示）时，工具栏必须正常存在。
    ///
    /// 抑制工具栏容易，**恢复才是容易出错的一侧**：一旦引导关闭时没有归还
    /// 工具栏，它会永久消失。本用例从「引导压根不展示」的入口验证恢复路径，
    /// 不依赖点击「继续」——该交互当前受另一个已知缺陷（提交后引导不关闭）阻塞。
    func testToolbarIsPresentWhenWelcomeGuideIsNotShown() {
        XCTAssertTrue(
            element(identifier: "cisum.settings.button").waitForExistence(timeout: 15),
            "引导未展示时设置按钮应可见：工具栏被错误地永久隐藏了"
        )
        XCTAssertTrue(
            element(identifier: "cisum.scene.switcher").waitForExistence(timeout: 10),
            "引导未展示时场景切换器应可见：工具栏被错误地永久隐藏了"
        )
    }
}
