import Combine
import SwiftUI

@MainActor
public enum ToolbarProvidingEvent {
    case contentChanged
}

@MainActor
public protocol ToolbarProvidingObserverHandle: AnyObject {
    func cancel()
}

/// 工具栏视图提供能力协议（对齐 Lumi `ProviderToolbar/ToolbarProviding`）。
///
/// 定义「内核 → 窗口工具栏」这一段的最小契约：宿主可选择把整个工具栏视图注入
/// `RootViewProviding`。默认场景切换器已迁移到 `PluginScene`，由插件通过
/// `SuperPlugin.addToolBarButtons()` 贡献；本协议作为可选整体注入契约保留。
///
/// 使用 `AnyView` 而非 `associatedtype`：协议可无泛型约束地作为存在类型
/// （`any ToolbarProviding`）注册进 `KernelCoreContainer` 的 Provider 注册表。
@MainActor
public protocol ToolbarProviding: AnyObject, ObservableObject {
    /// 返回工具栏视图（如场景切换器）。
    func makeToolbarView() -> AnyView

    @discardableResult
    func addObserver(_ callback: @escaping (ToolbarProvidingEvent) -> Void) -> any ToolbarProvidingObserverHandle
}

public extension ToolbarProviding {
    @discardableResult
    func addObserver(_ callback: @escaping (ToolbarProvidingEvent) -> Void) -> any ToolbarProvidingObserverHandle {
        NoopToolbarProvidingObserverHandle()
    }
}

@MainActor
public final class NoopToolbarProvidingObserverHandle: ToolbarProvidingObserverHandle {
    public init() {}
    public func cancel() {}
}