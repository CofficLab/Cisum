import SwiftUI

/// 播放控制区的「载入中」插槽。
///
/// 激活时控制区用它**同时替换状态行与进度行**（总高
/// `stateHeight + 18 + 16`），为「正在从 iCloud 载入」这类横幅提供
/// 足够的文字与操作空间，同时不新增高度预算。
///
/// 激活态由插件按播放状态驱动，控制区只负责排布——它不关心横幅里
/// 写了什么，也不关心是载入还是失败。
///
/// 做成可观察对象而非裸视图：装配时 `makeControlView()` 只调用一次，
/// 之后激活态变化必须让控制区重新排布，而不只是换一张图。
@MainActor
public final class ControlLoadingSlot: ObservableObject {
    /// 是否处于载入态。
    @Published public var isActive: Bool

    /// 载入横幅视图。
    public let view: AnyView

    public init(
        view: AnyView,
        isActive: Bool = false
    ) {
        self.view = view
        self.isActive = isActive
    }

    /// 永不激活的空插槽：宿主未注入载入横幅时的占位。
    public static let inactive = ControlLoadingSlot(
        view: AnyView(EmptyView())
    )
}
