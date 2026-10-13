import Foundation
import XCTest

/// iCloud 文件自动下载的 UI 行为。
///
/// XCUITest 无法在 CI 中真实制造「占位未下载」的 iCloud 文件（需要机器登录
/// iCloud Drive，且 `brctl` 驱逐后不能被自动同步回来）。因此这里通过启动参数
/// `--cisum-ui-testing-icloud-download=<success|timeout|offline>` 让 App 注入
/// 测试网关（见 `MagicKit.ICloudDownloadControl`）。
///
/// 音频条目经 `--cisum-ui-testing-seed-audio` 直接在 App 沙盒内创建，
/// 不依赖系统文件选择器，因此在 macOS 27 上同样可以运行。
///
/// ⚠️ 已知限制（2026-10 在 macOS 27.0.1 + 本机环境验证）：
/// 1. XCUITest 的点击（tap/click）在本机对 App 内按钮整体不生效（hittable=true
///    但 action 不触发，连设置按钮都打不开设置窗口）——因此依赖「用户点击」的
///    用例目前只能以负向断言覆盖（不进入播放态）。
/// 2. 默认窗口（400x600）下 Hero 下载覆盖层（cisum.player.download.overlay）
///    不渲染（布局条件要求控制区高度 > 450pt），因此对它的「不存在」断言没有
///    判别力，已从用例中移除，避免假通过。
final class CisumICloudDownloadUITests: CisumUITestBase {
    private let seededAudioName = "Cisum-ICloud-Download-Test.wav"

    /// 由 `relaunch(icloudMode:)` 覆盖，默认不带下载模式。
    override var additionalLaunchArguments: [String] {
        super.additionalLaunchArguments + ["--cisum-ui-testing-seed-audio", seededAudioName]
    }

    /// 以指定的下载模式重启 App。
    private func relaunch(icloudMode: String) {
        app.terminate()
        app = XCUIApplication()
        app.launchArguments += additionalLaunchArguments
        app.launchArguments += ["--cisum-ui-testing-icloud-download=\(icloudMode)"]
        app.launch()
        waitForKernelReady()
        try? ensureMusicScene()
    }

    /// 定位 seed 出来的曲目行。
    private func seededTrack() -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label CONTAINS %@", seededAudioName)).firstMatch
    }

    /// 等待曲目出现在音乐仓库。
    @discardableResult
    private func waitForSeededTrack(timeout: TimeInterval = 20) -> Bool {
        seededTrack().waitForExistence(timeout: timeout)
    }

    /// 播放按钮（identifier 在产品代码中固定为 play.fill）。
    private var playButton: XCUIElement {
        app.buttons.matching(NSPredicate(format: "identifier == %@", "play.fill")).firstMatch
    }

    // MARK: - Tests

    /// 下载态必须有可感知的 UI：标题下方出现下载状态行。
    ///
    /// 启动恢复播放会自动触发一次 iCloud 下载等待（stub timeout 模式 8s），
    /// 这里在窗口期内断言状态行可见。此前默认布局下下载态毫无 UI 呈现
    /// （覆盖层受布局条件限制不渲染），该用例驱动「始终可见的状态行」落地。
    func testDownloadStatusLineVisibleWhileDownloading() throws {
        relaunch(icloudMode: "timeout")
        XCTAssertTrue(waitForSeededTrack(), "seed 音频未出现在音乐仓库")

        let statusLine = element(identifier: "cisum.player.download.status")
        let appeared = statusLine.waitForExistence(timeout: 10)
        XCTAssertTrue(
            appeared,
            "下载等待期间标题下方应显示下载状态行 cisum.player.download.status（当前完全无 UI 呈现）"
        )

        if appeared {
            // SwiftUI Text 在 macOS AX 树中文本可能挂在 value（与 cisum.player.title 一致）
            let text = (statusLine.label.isEmpty ? (statusLine.value as? String ?? "") : statusLine.label)
            XCTAssertFalse(
                text.isEmpty,
                "下载状态行文案不应为空（label=\(statusLine.label) value=\(String(describing: statusLine.value))）"
            )
        }
    }

    /// 下载/加载期间播放按钮必须禁用，避免用户点击后静默无响应。
    func testPlayButtonDisabledWhileDownloading() throws {
        relaunch(icloudMode: "timeout")
        XCTAssertTrue(waitForSeededTrack(), "seed 音频未出现在音乐仓库")

        // 下载窗口（8s）内轮询：按钮应曾处于禁用态
        var sawDisabled = false
        let deadline = Date().addingTimeInterval(10)
        while Date() < deadline {
            if playButton.exists, !playButton.isEnabled {
                sawDisabled = true
                break
            }
            if app.buttons.matching(NSPredicate(format: "identifier == %@", "pause.fill")).firstMatch.exists {
                XCTFail("下载等待期间不应进入播放态")
                return
            }
            Thread.sleep(forTimeInterval: 0.3)
        }

        XCTAssertTrue(
            sawDisabled,
            "iCloud 下载等待期间播放按钮应被禁用（当前始终 enabled，点击后静默无响应）"
        )
    }

    /// 音乐库列表：seed 出的曲目必须出现，并带标题标识。
    ///
    /// 下载进度覆盖层只在「确实正在下载」时渲染，seed 出来的本地文件
    /// 不满足该条件，因此这里只断言曲目与标题。
    func testSeededTrackAppearsInLibrary() throws {
        try ensureMusicScene()
        XCTAssertTrue(waitForSeededTrack(), "seed 音频未出现在音乐仓库")

        let title = element(identifier: "cisum.audio-library.item.title")
        XCTAssertTrue(
            title.waitForExistence(timeout: 10),
            "音乐库列表项缺少标题标识 cisum.audio-library.item.title"
        )
    }

    /// 启动恢复播放会自动触发 iCloud 下载等待（注入 stub 后表现为
    /// 「不进入播放态」且不卡死在 loading）。
    ///
    /// 断言为负向（无 Pause 出现）：无法正向观测下载态 UI（见文件头注释），
    /// 但「超时后仍未进入播放」与「未永久卡住」仍是有效的行为保证。
    func testTimeoutModeDoesNotEnterPlayingOrHang() throws {
        relaunch(icloudMode: "timeout")
        XCTAssertTrue(waitForSeededTrack(), "seed 音频未出现在音乐仓库")

        // 下载等待期间（stub timeout 8s）及结束后，都不应进入播放态。
        // 用 identifier 判定（播放中按钮切换为 pause.fill），避免本地化文案差异。
        let pauseButton = app.buttons.matching(NSPredicate(format: "identifier == %@", "pause.fill")).firstMatch
        XCTAssertFalse(
            pauseButton.waitForExistence(timeout: 12),
            "iCloud 下载超时时不应进入播放态"
        )

        // App 应保持响应（内核就绪状态不丢失，播放器控件仍在）
        XCTAssertTrue(
            playButton.waitForExistence(timeout: 5),
            "下载超时后播放器控件消失（App 卡死或崩溃）"
        )
    }

    /// 离线模式：发起下载立即失败，同样不得进入播放态、App 不得卡死。
    func testOfflineModeDoesNotEnterPlayingOrHang() throws {
        relaunch(icloudMode: "offline")
        XCTAssertTrue(waitForSeededTrack(), "seed 音频未出现在音乐仓库")

        let pauseButton = app.buttons.matching(NSPredicate(format: "identifier == %@", "pause.fill")).firstMatch
        XCTAssertFalse(
            pauseButton.waitForExistence(timeout: 8),
            "离线时不应进入播放态"
        )

        XCTAssertTrue(
            playButton.waitForExistence(timeout: 5),
            "离线失败后播放器控件消失（App 卡死或崩溃）"
        )
    }

    /// 三种下载模式下 App 都必须保持可用（内核就绪、控件在位、音乐库可导航）。
    ///
    /// 这是对「下载流程不会破坏播放器/内核」的回归防护，覆盖 success/timeout/offline。
    func testAppRemainsHealthyAcrossAllDownloadModes() throws {
        for mode in ["success", "timeout", "offline"] {
            relaunch(icloudMode: mode)
            waitForKernelReady()
            XCTAssertTrue(waitForSeededTrack(), "seed 音频未出现在音乐仓库（mode=\(mode)）")

            XCTAssertTrue(
                playButton.waitForExistence(timeout: 5),
                "mode=\(mode) 下播放器控件不可用"
            )
            XCTAssertTrue(
                element(identifier: "cisum.scene.music").exists,
                "mode=\(mode) 下音乐仓库场景丢失"
            )
            XCTAssertFalse(
                element(identifier: "cisum.kernel.startup-error").exists,
                "mode=\(mode) 下内核出现启动错误"
            )
        }
    }
}
