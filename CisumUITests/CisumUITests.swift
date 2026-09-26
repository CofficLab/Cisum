//
//  CisumUITests.swift
//  CisumUITests
//
//  Created by Angel on 2026/9/26.
//

import XCTest

/// 用户最先感知的 App 级回归：内核是否完成启动，以及设置入口是否仍可用。
///
/// 页面状态断言只依赖产品明确公开的 accessibility identifier；设置入口则通过
/// 产品固定的 `Settings…` 命令触发，因此中文和英文 Scheme 都可复用这些 smoke test。
/// 启动状态测试在两个平台（macOS / iOS Simulator）上运行；设置入口测试仅适用
/// macOS（iOS 没有菜单栏与独立设置窗口场景），在其他平台显式跳过而非失败。
final class CisumUITests: XCTestCase {
    private var app: XCUIApplication!

    private func element(identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }

    @MainActor
    func testLaunchReachesRootWithoutStartupError() throws {
        XCTAssertTrue(
            element(identifier: "cisum.kernel.ready").waitForExistence(timeout: 15),
            "Cisum did not finish assembling its main UI"
        )
        XCTAssertFalse(
            element(identifier: "cisum.kernel.startup-error").exists,
            "Cisum displayed its startup error screen"
        )
    }

    @MainActor
    func testSettingsCommandOpensDedicatedWindow() throws {
        #if os(macOS)
        XCTAssertTrue(app.windows["Cisum"].waitForExistence(timeout: 10))

        let appMenu = app.menuBars.menuBarItems["Cisum"]
        XCTAssertTrue(appMenu.waitForExistence(timeout: 5), "Cisum's application menu is unavailable")
        appMenu.click()

        let settingsCommand = app.menuItems["Settings…"]
        XCTAssertTrue(settingsCommand.waitForExistence(timeout: 5), "The Settings command is unavailable")
        settingsCommand.click()

        XCTAssertTrue(
            element(identifier: "cisum.settings.ready").waitForExistence(timeout: 10),
            "The Settings command did not open the settings window"
        )
        XCTAssertFalse(element(identifier: "cisum.kernel.startup-error").exists)
        #else
        throw XCTSkip("The Settings menu command is macOS-only")
        #endif
    }

    @MainActor
    func testToolbarSettingsButtonOpensSettingsWindow() throws {
        #if os(macOS)
        XCTAssertTrue(app.windows["Cisum"].waitForExistence(timeout: 10))

        let toolbarButton = element(identifier: "cisum.settings.button")
        XCTAssertTrue(toolbarButton.waitForExistence(timeout: 10), "The toolbar settings button is unavailable")
        toolbarButton.click()

        XCTAssertTrue(
            element(identifier: "cisum.settings.ready").waitForExistence(timeout: 10),
            "The toolbar settings button did not open the settings window"
        )
        XCTAssertFalse(element(identifier: "cisum.kernel.startup-error").exists)
        #else
        throw XCTSkip("The toolbar settings button is macOS-only")
        #endif
    }
}
