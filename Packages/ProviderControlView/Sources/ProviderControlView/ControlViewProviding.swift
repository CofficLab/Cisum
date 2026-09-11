import SwiftUI

@MainActor
public enum ControlViewProvidingEvent {
    case viewInvalidated
}

@MainActor
public protocol ControlViewProvidingObserverHandle: AnyObject {
    func cancel()
}

/// 播放控制区提供能力协议（对齐 Lumi 各区域独立 Provider 的范式）。
///
/// 定义「内核 → 根布局顶部播放控制区」这一段的最小契约：宿主在装配时
/// 通过内核解析 `ControlViewProviding`，拿到播放控制视图后注入根布局。
/// 该区域是根视图中的一小块，独立成 Provider 便于替换与解耦。
///
/// 控制区由多个区块组成（封面 / 状态 / 进度 / 操作按钮 / 右侧封面），
/// 各区块可分别通过 `setXxxView(_:)` 由外部注入自定义视图；未注入时
/// 回退到内置默认实现。
@MainActor
public protocol ControlViewProviding: AnyObject, ObservableObject {
    /// 返回顶部播放控制区视图。
    func makeControlView() -> AnyView

    /// 注入封面/标题区视图（传 `nil` 使用默认 `HeroView`）。
    func setHeroView(_ view: AnyView?)

    /// 注入状态提示区视图（传 `nil` 使用默认 `StateView`）。
    func setStateView(_ view: AnyView?)

    /// 注入进度区视图（传 `nil` 使用默认播放器进度条）。
    func setProgressView(_ view: AnyView?)

    /// 注入操作按钮区视图（未注入时不渲染该区块；默认由插件提供）。
    func setControlButtonsView(_ view: AnyView?)

    /// 注入右侧封面区视图（传 `nil` 不渲染右侧专辑区）。
    func setRightAlbumView(_ view: AnyView?)

    /// 设置播放控制区的演示模式。
    func setDemoMode(_ enabled: Bool)

    @discardableResult
    func addObserver(_ callback: @escaping (ControlViewProvidingEvent) -> Void) -> any ControlViewProvidingObserverHandle
}

public extension ControlViewProviding {
    func setDemoMode(_ enabled: Bool) {}
    func setHeroView(_ view: AnyView?) {}
    func setStateView(_ view: AnyView?) {}
    func setProgressView(_ view: AnyView?) {}
    func setControlButtonsView(_ view: AnyView?) {}
    func setRightAlbumView(_ view: AnyView?) {}
    @discardableResult
    func addObserver(_ callback: @escaping (ControlViewProvidingEvent) -> Void) -> any ControlViewProvidingObserverHandle {
        NoopControlViewProvidingObserverHandle()
    }
}

@MainActor
public final class NoopControlViewProvidingObserverHandle: ControlViewProvidingObserverHandle {
    public init() {}
    public func cancel() {}
}
