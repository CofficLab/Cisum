import XCTest

/// iOS 设置入口：导航栏齿轮必须出现，点击后以 sheet 呈现设置页。
///
/// macOS 侧走独立的设置窗口 Scene（见 `CisumSettingsUITests`），iOS 没有
/// 对应的 `Window` Scene，设置页由齿轮广播通知后以 sheet 呈现 —— 因此
/// iOS 必须有自己的入口断言，不能复用 macOS 的菜单栏路径。
final class CisumIOSSettingsUITests: CisumUITestBase {
    /// 导航栏齿轮必须可见。
    func testNavigationBarGearIsVisible() throws {
        #if os(macOS)
        throw XCTSkip("iOS 导航栏齿轮仅 iOS 适用")
        #else
        let gear = element(identifier: "cisum.settings.button")
        XCTAssertTrue(gear.waitForExistence(timeout: 15), "iOS 导航栏缺少设置齿轮")
        #endif
    }

    /// 点击齿轮后必须弹出设置页，并能看到设置入口列表。
    func testTappingGearPresentsSettingsSheet() throws {
        #if os(macOS)
        throw XCTSkip("iOS 设置 sheet 仅 iOS 适用")
        #else
        let gear = element(identifier: "cisum.settings.button")
        XCTAssertTrue(gear.waitForExistence(timeout: 15), "iOS 导航栏缺少设置齿轮")
        gear.tap()

        // 设置页根列表的标题（Settings / 设置）。
        let settingsTitle = element(anyLabelOf: ["Settings", "设置"])
        XCTAssertTrue(settingsTitle.waitForExistence(timeout: 15), "点击齿轮后没有呈现设置页")

        // 根列表里应至少有一个设置入口。
        let generalEntry = element(anyLabelOf: ["General", "通用"])
        XCTAssertTrue(generalEntry.waitForExistence(timeout: 10), "设置页缺少「通用」入口")
        #endif
    }
}
