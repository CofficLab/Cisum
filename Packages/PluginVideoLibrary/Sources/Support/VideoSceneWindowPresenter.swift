#if os(macOS)
import AppKit
import SwiftUI

/// 视频场景的 macOS 窗口尺寸：进入时放宽为资料库窗口，离开时还原。
///
/// 视频库是「资料库优先」的三栏布局，音乐播放器的窄窗口放不下；窗口尺寸属于
/// 宿主平台边界，这里只做最小的 AppKit 操作，不触碰任何布局。
@MainActor
final class VideoSceneWindowPresenter {
    static let preferredSize = CGSize(width: 1180, height: 760)

    private var restoredFrame: CGRect?
    private var isActive = false
    private var hasApplied = false

    /// 进入视频场景：记住当前窗口并在窗口可用时放宽。
    func activate() {
        guard !isActive else { return }
        isActive = true
        hasApplied = false
        applyIfPossible()
    }

    /// 离开视频场景：还原进入前的窗口尺寸。
    func deactivate() {
        guard isActive else { return }
        isActive = false
        defer { hasApplied = false }
        guard hasApplied, let restoredFrame, let window = mainWindow() else {
            self.restoredFrame = nil
            return
        }
        self.restoredFrame = nil
        window.setFrame(restoredFrame, display: true)
    }

    /// 视图出现后重试：场景在启动期恢复时窗口可能尚未就绪。
    func retryIfNeeded() {
        guard isActive, !hasApplied else { return }
        applyIfPossible()
    }

    private func applyIfPossible() {
        guard let window = mainWindow() else { return }
        let content = window.contentLayoutRect.size
        guard content.width < Self.preferredSize.width - 1
            || content.height < Self.preferredSize.height - 1 else {
            hasApplied = true
            return
        }
        if restoredFrame == nil {
            restoredFrame = window.frame
        }
        let visible = window.screen?.visibleFrame ?? NSScreen.main?.visibleFrame ?? window.frame
        window.setFrame(Self.targetFrame(current: window.frame, visible: visible, preferred: Self.preferredSize), display: true)
        hasApplied = true
    }

    /// 以窗口左上角为锚点放大，并收进当前屏幕的可见范围。
    nonisolated static func targetFrame(current: CGRect, visible: CGRect, preferred: CGSize) -> CGRect {
        let width = min(preferred.width, visible.width)
        let height = min(preferred.height, visible.height)
        let x = min(max(current.minX, visible.minX), visible.maxX - width)
        let y = max(min(current.maxY - height, visible.maxY - height), visible.minY)
        return CGRect(x: x, y: y, width: width, height: height)
    }

    /// 主内容窗口（排除设置窗口）。
    private func mainWindow() -> NSWindow? {
        NSApplication.shared.windows.first {
            $0.isVisible
                && $0.contentLayoutRect.height > 0
                && $0.identifier?.rawValue != "cisum.settings"
                && $0.title != "设置"
                && $0.title != "Settings"
        } ?? NSApplication.shared.mainWindow
    }
}
#endif
