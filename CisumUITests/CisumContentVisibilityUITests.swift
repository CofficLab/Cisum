import XCTest

/// 内容区（音乐库）显隐的端到端回归。
///
/// 背景：iOS 上曾出现「从 TestFlight 装完打开 App，屏幕上只剩一排播放控制
/// 按钮、没有音乐库」的界面。根因是内容区显隐存在两个互不相通的真源
/// （落盘偏好 / 内存态），两者之间只有启动时一条单向通路：
/// - 旧缺陷写坏的落盘值 → 之后每次冷启动都只剩空播放器；
/// - 「更多」按钮只改内存态 → 用户的显式选择重启后丢失；
/// - 两者分叉时按落盘值取反 → 「更多」按钮点了没反应。
///
/// 本用例锁定三条用户可见契约：
/// 1. 启动即见内容区（不再出现「只剩空播放器」）；
/// 2. 「更多」按钮双向可用（收起之后还能展开）；
/// 3. 收起状态跨重启保持一致，并且仍能重新展开（显式选择不被悄悄改写）。
final class CisumContentVisibilityUITests: CisumUITestBase {
    /// 内容区场景标识：音乐仓库 / 有声书仓库（任一存在即代表内容区已渲染）。
    private static let contentSceneIdentifiers = ["cisum.scene.music", "cisum.scene.audiobooks"]

    // MARK: - 启动即见内容区

    /// 回归：启动后必须能看到音乐库（或有声书库）内容区。
    ///
    /// 缺陷态下 `contentArea` 整块不进渲染树，屏幕上只剩播放控制区。
    func testContentAreaIsVisibleOnLaunch() {
        XCTAssertTrue(
            waitForContentArea(in: app),
            "启动后没有任何内容场景（音乐仓库 / 有声书仓库都不存在）——这正是「只剩空播放器」的界面"
        )

        let scene = contentSceneElement(in: app)
        XCTAssertGreaterThan(
            scene.frame.height, 0,
            "内容区存在但高度为 0，等同于没有音乐库"
        )
    }

    // MARK: - 「更多」按钮双向可用

    /// 回归：「更多」按钮必须能收起、也能重新展开内容区。
    ///
    /// 缺陷态下按钮只改内存态：在内存态与落盘态分叉时按落盘值取反，
    /// 用户会得到一个「点了没反应」的按钮。
    func testMoreButtonTogglesContentAreaBothWays() {
        XCTAssertTrue(waitForContentArea(in: app), "启动后没有内容区，无法验证「更多」按钮")

        let more = moreButton(in: app)
        XCTAssertTrue(more.waitForExistence(timeout: 10), "播放控制区缺少「更多」按钮")

        more.click()
        XCTAssertTrue(
            waitForContentAreaToDisappear(in: app),
            "点击「更多」后内容区没有收起"
        )

        // 收起后控制区会重新排版，按钮位置随之变化——必须重新定位，
        // 否则第二次点击会落到旧坐标上，等于「点了没反应」。
        let moreAgain = moreButton(in: app)
        XCTAssertTrue(moreAgain.waitForExistence(timeout: 10), "收起后播放控制区缺少「更多」按钮")
        XCTAssertTrue(moreAgain.isHittable, "收起后「更多」按钮不可点击")
        moreAgain.click()
        XCTAssertTrue(
            waitForContentArea(in: app),
            "再次点击「更多」后内容区没有回来（按钮点了没反应）"
        )
    }

    // MARK: - 收起状态跨重启一致

    /// 回归：用户主动收起内容区后，重启必须保持收起，并且仍能重新展开。
    ///
    /// 缺陷态下收起不落盘，重启后内容区自己回来了——用户的显式选择被悄悄改写。
    /// 本用例刻意使用**不带 `-UI.ContentViewVisible` 覆盖参数**的 App 实例：
    /// UserDefaults 的参数域优先级高于持久化域，只有不注入该参数，
    /// 落盘偏好才真正参与显隐判定。
    func testCollapsedContentAreaSurvivesRelaunch() {
        let plain = makeAppWithoutVisibilityOverride()
        app.terminate()
        plain.launch()
        waitForKernelReady(in: plain)

        // 把状态归一到「展开」，再收起，保证本用例结束时落盘值确定。
        if !waitForContentArea(in: plain) {
            moreButton(in: plain).click()
            XCTAssertTrue(waitForContentArea(in: plain), "无法把内容区展开到已知状态")
        }
        moreButton(in: plain).click()
        XCTAssertTrue(
            waitForContentAreaToDisappear(in: plain),
            "内容区没有收起，无法验证收起状态是否跨重启保持"
        )

        // 重启：收起状态应当保持一致。
        plain.terminate()
        plain.launch()
        waitForKernelReady(in: plain)
        XCTAssertTrue(
            contentAreaStaysHidden(in: plain),
            "重启后收起状态丢失：用户的显式选择被悄悄改写成展开"
        )

        // 仍可展开：收起态不能是死胡同。
        moreButton(in: plain).click()
        XCTAssertTrue(
            waitForContentArea(in: plain),
            "重启后无法把内容区展开回来——用户被卡在收起态里"
        )
    }

    // MARK: - Helpers

    /// 不带显隐覆盖参数的 App 实例：落盘偏好在此真正生效。
    private func makeAppWithoutVisibilityOverride() -> XCUIApplication {
        let instance = XCUIApplication()
        instance.launchArguments = ["--cisum-ui-testing", "--cisum-ui-testing-storage-local"]
        return instance
    }

    /// 等待内核就绪（供非基类 `app` 实例使用）。
    private func waitForKernelReady(in app: XCUIApplication, timeout: TimeInterval = 20) {
        XCTAssertTrue(
            app.descendants(matching: .any)
                .matching(identifier: "cisum.kernel.ready")
                .firstMatch.waitForExistence(timeout: timeout),
            "Cisum 未在 \(timeout)s 内完成主界面组装"
        )
    }

    /// 内容区场景元素（音乐仓库优先，其次有声书仓库）。
    private func contentSceneElement(in app: XCUIApplication) -> XCUIElement {
        for identifier in Self.contentSceneIdentifiers {
            let element = app.descendants(matching: .any)
                .matching(identifier: identifier).firstMatch
            if element.exists { return element }
        }
        return app.descendants(matching: .any)
            .matching(identifier: Self.contentSceneIdentifiers[0]).firstMatch
    }

    /// 内容区当前是否已渲染。
    private func contentSceneExists(in app: XCUIApplication) -> Bool {
        Self.contentSceneIdentifiers.contains { identifier in
            app.descendants(matching: .any)
                .matching(identifier: identifier).firstMatch.exists
        }
    }

    /// 在超时时间内等待内容区出现。
    private func waitForContentArea(in app: XCUIApplication, timeout: TimeInterval = 15) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if contentSceneExists(in: app) { return true }
            Thread.sleep(forTimeInterval: 0.25)
        }
        return false
    }

    /// 在超时时间内等待内容区消失。
    private func waitForContentAreaToDisappear(in app: XCUIApplication, timeout: TimeInterval = 10) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if !contentSceneExists(in: app) { return true }
            Thread.sleep(forTimeInterval: 0.25)
        }
        return false
    }

    /// 整个观察窗口内内容区始终没有出现。
    ///
    /// 与「等待消失」不同，这里要求**始终**不存在，
    /// 避免把启动瞬间的一帧闪现误判成「已收起」。
    private func contentAreaStaysHidden(in app: XCUIApplication, timeout: TimeInterval = 5) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if contentSceneExists(in: app) { return false }
            Thread.sleep(forTimeInterval: 0.25)
        }
        return true
    }

    /// 播放控制区的「更多」按钮（收起 / 展开内容区）。
    ///
    /// 定位限定在 `cisum.player.controls` 内：工具栏同样可能出现名为 "More"
    /// 的控件，全局匹配会点到错的按钮。
    private func moreButton(in app: XCUIApplication) -> XCUIElement {
        let controls = app.descendants(matching: .any)
            .matching(identifier: "cisum.player.controls").firstMatch
        if controls.exists {
            return controls.buttons.matching(NSPredicate(format: "label == %@", "More")).firstMatch
        }
        return app.buttons.matching(NSPredicate(format: "label == %@", "More")).firstMatch
    }
}
