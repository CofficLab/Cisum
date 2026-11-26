import Foundation
import Testing
@testable import PluginVideoLibrary

#if os(macOS)
/// 视频场景窗口尺寸换算的行为测试。
struct VideoSceneWindowPresenterTests {
    @Test("以左上角为锚点放宽到偏好尺寸")
    func anchorsTopLeadingCorner() {
        let frame = VideoSceneWindowPresenter.targetFrame(
            current: CGRect(x: 100, y: 300, width: 400, height: 600),
            visible: CGRect(x: 0, y: 0, width: 1920, height: 1055),
            preferred: CGSize(width: 1180, height: 760)
        )
        #expect(frame.origin == CGPoint(x: 100, y: 300 + 600 - 760))
        #expect(frame.size == CGSize(width: 1180, height: 760))
    }

    @Test("偏好尺寸超出屏幕时收进可见范围")
    func clampsToVisibleFrame() {
        let frame = VideoSceneWindowPresenter.targetFrame(
            current: CGRect(x: 1500, y: 400, width: 400, height: 600),
            visible: CGRect(x: 0, y: 0, width: 1280, height: 700),
            preferred: CGSize(width: 1180, height: 760)
        )
        #expect(frame.size == CGSize(width: 1180, height: 700))
        #expect(frame.maxX <= 1280)
        #expect(frame.minY >= 0)
        #expect(frame.maxY <= 700)
    }
}
#endif
