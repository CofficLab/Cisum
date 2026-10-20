import SwiftUI

/// 播放控制区的「空仓库引导」插槽。
///
/// 仓库为空、且控制区有足够高度时，控制区**顶部**渲染 `guideView`（引导与提示），
/// 播放控件与进度顺势沉到下方——操作与进度靠下，主要区域留给引导。
///
/// 激活与否由插件按业务状态驱动（音乐仓库插件在仓库为空时置 `true`），
/// 控制区只负责结合激活态与可用高度决定是否渲染——它不关心「仓库」是什么，
/// 只提供一个引导位。
///
/// 之所以做成可观察对象而不是裸视图：激活态变化必须让控制区**重新排布**
/// （引导占顶部、控件沉到底部），而不仅仅是换一张图。
@MainActor
public final class ControlGuideSlot: ObservableObject {
    /// 是否处于引导态。
    @Published public var isActive: Bool

    /// 顶部引导视图。
    public let guideView: AnyView

    public init(
        guideView: AnyView,
        isActive: Bool = false
    ) {
        self.guideView = guideView
        self.isActive = isActive
    }

    /// 永不激活的空插槽：宿主未注入引导时的占位。
    public static let inactive = ControlGuideSlot(
        guideView: AnyView(EmptyView())
    )
}
