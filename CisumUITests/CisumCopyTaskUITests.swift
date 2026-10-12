import XCTest

/// 复制任务：状态面板的呈现与消息格式。
/// XCUITest 无法在 macOS 上注入真实的文件拖拽事件，因此这里只验证空闲态。
final class CisumCopyTaskUITests: CisumUITestBase {
    func testCopyStatusPanelIsHiddenWhenIdle() {
        let copyState = element(identifier: "cisum.copy.state")
        XCTAssertFalse(copyState.waitForExistence(timeout: 3), "无复制任务时不应显示复制状态面板")
    }
}
