import XCTest

/// 音乐库加载中骨架屏的布局回归：骨架行必须完整落在内容区内。
///
/// 背景：`AudioLibrarySkeletonView` 早期把行数写死为 12 行、总高固定
/// `28 + 12 × 60 = 748pt`，且不随窗口高度变化。当内容区（窗口高度减去播放控制区）
/// 小于该高度时，`VStack` 溢出并被上层裁切，表现为列表顶部第一行只剩上半截、
/// 底部最后一行也被切掉——正是首次启动时加载中界面上方「被遮住」的原因。
///
/// 本用例通过 `--cisum-ui-testing-audio-load-delay` 把首屏加载延后，
/// 让骨架屏稳定停留在屏幕上，从而可以断言它的几何。
final class CisumAudioSkeletonLayoutUITests: CisumUITestBase {
    /// 骨架行锚点文案前缀，规则见 `SkeletonRowTestAnchor.rowLabelPrefix`。
    private static let rowLabelPrefix = "cisum.audio.skeleton.row."

    /// 当前骨架实现的固定行数；修复为按高度自适应后行数可能变少，
    /// 测试只统计实际存在的行，不假设一定有 12 行。
    private static let candidateRowCount = 12

    private let seedAudioName = "Cisum-UI-Skeleton-Layout-Test-Tone.wav"

    /// 观测窗口：XCUITest 的可访问性轮询约 0.3-0.5s 一轮，
    /// 留出足够时间在骨架消失前完成多轮几何查询。
    private let loadDelaySeconds = 12

    override var additionalLaunchArguments: [String] {
        super.additionalLaunchArguments + [
            "--cisum-ui-testing-seed-audio", seedAudioName,
            "--cisum-ui-testing-audio-load-delay=\(loadDelaySeconds)",
        ]
    }

    func testLoadingSkeletonStaysInsideMusicLibraryContentArea() throws {
        #if os(macOS)
        app.activate()
        #endif
        try ensureMusicScene()

        let window = mainWindow
        XCTAssertTrue(window.waitForExistence(timeout: 20), "主容器未出现，无法检查骨架屏布局")

        let firstRow = skeletonRow(0)
        XCTAssertTrue(
            firstRow.waitForExistence(timeout: 15),
            "加载中骨架屏未出现：首屏种子音频应让仓库非空，且加载延迟参数应让骨架稳定可见"
        )

        // 内容区的上下边界以「播放控制区底边 → 窗口内容底边」为准。
        // 不能用 `cisum.scene.music` 当参照：骨架期该标识被祖先下发给每一行，
        // `firstMatch` 抓到的是第 0 行本身，用它比对自己没有意义。
        let controls = element(identifier: "cisum.player.controls")
        XCTAssertTrue(controls.waitForExistence(timeout: 10), "播放控制区未出现，无法确定内容区上边界")

        let contentTop = controls.frame.maxY
        let contentBottom = window.frame.maxY
        XCTAssertGreaterThan(contentBottom, contentTop, "窗口内容高度异常：window=\(window.frame), controls=\(controls.frame)")

        // 只统计此刻真实存在的骨架行：骨架改为按高度自适应行数后，
        // 行数会少于 12，测试不应把「不存在的行」当成失败。
        let rows = (0..<Self.candidateRowCount)
            .map { (index: $0, element: skeletonRow($0)) }
            .filter { $0.element.exists }

        XCTAssertFalse(rows.isEmpty, "未能定位到任何骨架行")

        let topMost = try XCTUnwrap(rows.min(by: { $0.element.frame.minY < $1.element.frame.minY }))
        let bottomMost = try XCTUnwrap(rows.max(by: { $0.element.frame.maxY < $1.element.frame.maxY }))

        // 上边界：首行不应被播放控制区盖住（用户看到的「上方被遮住」）。
        XCTAssertGreaterThanOrEqual(
            topMost.element.frame.minY,
            contentTop - 1,
            "骨架屏顶部被播放控制区遮住：首行 index=\(topMost.index), row=\(topMost.element.frame), controls=\(controls.frame)"
        )
        // 下边界：末行不应溢出窗口内容底部（被裁掉）。
        XCTAssertLessThanOrEqual(
            bottomMost.element.frame.maxY,
            contentBottom + 1,
            "骨架屏底部被窗口裁切：末行 index=\(bottomMost.index), row=\(bottomMost.element.frame), window=\(window.frame), visibleRows=\(rows.count)"
        )
    }

    /// 定位第 `index` 行骨架。
    ///
    /// 骨架行的 identifier 会被外层 `cisum.scene.music` 覆盖（macOS 把祖先标识
    /// 下发给后代），因此改用带行号的 accessibility label 定位。
    private func skeletonRow(_ index: Int) -> XCUIElement {
        app.descendants(matching: .any)
            .matching(identifier: Self.rowLabelPrefix + String(index))
            .firstMatch
    }
}