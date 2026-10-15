import CoreGraphics
import Testing
@testable import PluginRootView

/// 复现并锁定 p4.4.3 iOS「打开后音乐库被隐藏、只剩浮在中央的空播放器」的根因：
/// `CisumRootLayoutView.handleGeometryChange` 里的「窗口变矮就收起副栏」规则本是
/// macOS 桌面行为，却未做平台隔离，导致 iOS 启动/旋转期间根视图瞬时上报的小高度
/// 把内容区永久收起（且无自动恢复路径）。
///
/// 判定被抽成纯函数 `RootContentVisibility.shouldHideContentView(isMacOS:newHeight:dropThreshold:)`，
/// 通过注入平台参数，在本机（macOS CI）即可同时覆盖 iOS / macOS 两条分支。
struct RootContentVisibilityTests {
    private let threshold: CGFloat = 270

    // MARK: - iOS：几何变化绝不自动收起内容区

    @Test("iOS 上极短的瞬时高度不得收起内容区（复现 p4.4.3 空播放器 bug）")
    func iosNeverHidesContentViewOnShortGeometry() {
        #expect(!RootContentVisibility.shouldHideContentView(
            isMacOS: false, newHeight: 0, dropThreshold: threshold
        ))
        #expect(!RootContentVisibility.shouldHideContentView(
            isMacOS: false, newHeight: 100, dropThreshold: threshold
        ))
        // 恰好在旧阈值边界上，iOS 同样不得收起。
        #expect(!RootContentVisibility.shouldHideContentView(
            isMacOS: false, newHeight: threshold, dropThreshold: threshold
        ))
    }

    @Test("iOS 上正常屏幕高度同样保持内容区可见")
    func iosKeepsContentViewAtRegularHeights() {
        #expect(!RootContentVisibility.shouldHideContentView(
            isMacOS: false, newHeight: 844, dropThreshold: threshold
        ))
    }

    // MARK: - macOS：保留既有的「窗口拉矮即收起副栏」响应式行为

    @Test("macOS 上高度低于或等于阈值时收起内容区")
    func macOSHidesContentViewAtOrBelowThreshold() {
        #expect(RootContentVisibility.shouldHideContentView(
            isMacOS: true, newHeight: 200, dropThreshold: threshold
        ))
        #expect(RootContentVisibility.shouldHideContentView(
            isMacOS: true, newHeight: threshold, dropThreshold: threshold
        ))
    }

    @Test("macOS 上高度高于阈值时保持内容区可见")
    func macOSKeepsContentViewAboveThreshold() {
        #expect(!RootContentVisibility.shouldHideContentView(
            isMacOS: true, newHeight: threshold + 1, dropThreshold: threshold
        ))
        #expect(!RootContentVisibility.shouldHideContentView(
            isMacOS: true, newHeight: 900, dropThreshold: threshold
        ))
    }
}
