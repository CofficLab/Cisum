import CoreGraphics
import Testing
@testable import PluginAudioDBView

/// 骨架屏行数计算：布局不再溢出内容区的不变量。
///
/// 回归背景：行数曾写死为 12（总高 748pt），在 533pt 的内容区里整体居中溢出，
/// 上移约 101pt，导致顶部几行被播放控制区遮住、底部几行被窗口裁掉。
/// 核心不变量是「骨架总高不得超过可用高度」，这里逐档锁死。
@Suite("AudioLibrarySkeletonView")
struct AudioLibrarySkeletonRowCountTests {
    private static let topInset: CGFloat = 28
    private static let rowHeight: CGFloat = 60
    private static let maximumRowCount = 20

    private static func totalHeight(rowCount: Int) -> CGFloat {
        topInset + CGFloat(rowCount) * rowHeight
    }

    @Test("常见窗口高度下骨架总高不超出可用高度")
    func neverOverflowsAvailableHeight() {
        // 覆盖紧凑窗口、本次回归窗口、加载完成后的高度等真实取值
        let heights: [CGFloat] = [250, 300, 420, 533, 600, 700, 756, 900, 1200]

        for height in heights {
            let rows = AudioLibrarySkeletonView.rowCount(forAvailableHeight: height)
            #expect(
                Self.totalHeight(rowCount: rows) <= height,
                "骨架总高超出可用高度：height=\(height), rows=\(rows)"
            )
        }
    }

    @Test("本次回归窗口的行数从 12 降为 8")
    func regressionWindowRowCount() {
        #expect(AudioLibrarySkeletonView.rowCount(forAvailableHeight: 533) == 8)
    }

    @Test("退化输入至少渲染一行，不崩溃也不返回零")
    func degenerateInputStillRendersOneRow() {
        for height in [CGFloat(0), 1, 10, Self.topInset, Self.topInset + 1] {
            #expect(
                AudioLibrarySkeletonView.rowCount(forAvailableHeight: height) >= 1,
                "退化高度应保留至少一行：height=\(height)"
            )
        }
    }

    @Test("非法与非有限高度退回一行")
    func invalidHeightFallsBackToSingleRow() {
        for height in [CGFloat.nan, .infinity, -.infinity, -100] {
            #expect(AudioLibrarySkeletonView.rowCount(forAvailableHeight: height) == 1)
        }
    }

    @Test("超高窗口下行数封顶，避免无意义绘制")
    func capsRowCountForVeryTallContainer() {
        #expect(
            AudioLibrarySkeletonView.rowCount(forAvailableHeight: 100_000) == Self.maximumRowCount
        )
    }

    @Test("行数随高度单调不减")
    func rowCountIsMonotonic() {
        var previous = 0
        for step in 0...40 {
            let rows = AudioLibrarySkeletonView.rowCount(forAvailableHeight: CGFloat(step) * 30)
            #expect(rows >= previous, "行数不应随高度增加而减少：step=\(step)")
            previous = rows
        }
    }
}