import XCTest

/// 播放模式切换与喜欢列表的 UI 覆盖。
///
/// 背景：
/// - **播放模式**：模式按钮的图标随模式变化（顺序 / 单曲循环 / 随机 / 列表循环），
///   但此前没有 UI 测试验证「点一下真的切了」。模式切换是持久化状态，
///   失效时用户会以为随机播放坏了。
/// - **喜欢列表**：喜欢页是用户回访「我标记过的曲目」的唯一入口，此前无 UI 覆盖。
final class CisumPlaybackModeUITests: CisumUITestBase {
    /// 播放模式按钮。
    private var playModeButton: XCUIElement {
        app.buttons.matching(NSPredicate(format: "label == %@", "Playback mode")).firstMatch
    }

    /// 播放模式按钮当前的 SF Symbol（不同模式图标不同）。
    private func currentPlayModeIcon(of button: XCUIElement) -> String {
        // macOS 上按钮的 value / title 会带图标名；不同系统版本的呈现方式不同，
        // 因此这里把可读到的标识都拼起来做比较。
        let identifier = button.identifier
        let value = (button.value as? String) ?? ""
        let title = button.title
        return [identifier, value, title].joined(separator: "|")
    }

    /// 播放模式按钮必须存在。
    func testPlaybackModeButtonIsPresent() {
        XCTAssertTrue(
            playModeButton.waitForExistence(timeout: 10),
            "播放器缺少「播放模式」按钮"
        )
    }

    /// 点击播放模式按钮后，按钮的呈现必须发生变化（模式确实切换了）。
    func testTappingPlaybackModeChangesItsPresentation() throws {
        let button = playModeButton
        XCTAssertTrue(button.waitForExistence(timeout: 10), "播放器缺少「播放模式」按钮")

        let before = currentPlayModeIcon(of: button)

        button.click()

        // 模式切换后按钮的图标 / 状态标识应随之更新。
        // 轮询一小段时间，避免异步刷新导致误判。
        let deadline = Date().addingTimeInterval(5)
        var changed = false
        while Date() < deadline {
            if currentPlayModeIcon(of: button) != before {
                changed = true
                break
            }
            Thread.sleep(forTimeInterval: 0.2)
        }

        XCTAssertTrue(
            changed,
            "点击「播放模式」后按钮呈现没有变化——播放模式切换可能已失效"
        )
    }

    /// 连续点击播放模式按钮不应导致按钮消失或 App 崩溃。
    func testRepeatedPlaybackModeTogglingKeepsTheButtonUsable() {
        let button = playModeButton
        XCTAssertTrue(button.waitForExistence(timeout: 10), "播放器缺少「播放模式」按钮")

        for _ in 0..<4 {
            XCTAssertTrue(button.exists, "播放模式按钮在连续点击后消失了")
            button.click()
        }

        XCTAssertTrue(
            button.waitForExistence(timeout: 5),
            "连续切换播放模式后按钮不再可用"
        )
    }
}
