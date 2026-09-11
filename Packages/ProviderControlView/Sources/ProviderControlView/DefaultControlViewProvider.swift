import SwiftUI

/// 默认 `ControlViewProviding` 实现：返回内置的播放控制区（`ControlView`）。
///
/// 支持外部通过 `setXxxView(_:)` 分别注入控制区各区块视图（封面 / 状态 /
/// 进度 / 操作按钮 / 右侧封面），未注入时不渲染对应播放区块。操作按钮组
/// 由插件通过 `setControlButtonsView(_:)` 提供。
@MainActor
public final class DefaultControlViewProvider: ObservableObject, ControlViewProviding {
    public private(set) var heroView: AnyView?
    public private(set) var stateView: AnyView?
    public private(set) var progressView: AnyView?
    public private(set) var controlButtonsView: AnyView?
    public private(set) var rightAlbumView: AnyView?

    private let stateViews: @MainActor () -> [AnyView]
    private let stateMessage: @MainActor () -> String

    public init(
        stateViews: @escaping @MainActor () -> [AnyView] = { [] },
        stateMessage: @escaping @MainActor () -> String = { "" }
    ) {
        self.stateViews = stateViews
        self.stateMessage = stateMessage
    }

    public func setHeroView(_ view: AnyView?) { heroView = view }
    public func setStateView(_ view: AnyView?) { stateView = view }
    public func setProgressView(_ view: AnyView?) { progressView = view }
    public func setControlButtonsView(_ view: AnyView?) { controlButtonsView = view }
    public func setRightAlbumView(_ view: AnyView?) { rightAlbumView = view }

    public func makeControlView() -> AnyView {
        AnyView(
            ControlView(
                stateViews: stateViews,
                stateMessage: stateMessage,
                heroView: heroView,
                stateView: stateView,
                progressView: progressView,
                controlButtonsView: controlButtonsView,
                rightAlbumView: rightAlbumView
            )
        )
    }
}
