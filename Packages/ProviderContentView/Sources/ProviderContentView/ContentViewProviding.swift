import Combine
import SwiftUI

@MainActor
public enum ContentViewProvidingEvent {
    case tabsChanged(ids: [String])
}

@MainActor
public protocol ContentViewProvidingObserverHandle: AnyObject {
    func cancel()
}

/// 内容区 Tab 项。
///
/// 对应 Cisum 内容区的一个可切换页签（由插件通过 `ContentViewProviding` 贡献）。
public struct ContentTabItem: Identifiable {
    public let id: String
    public let title: String
    public let order: Int
    public let content: AnyView

    public init(id: String, title: String, order: Int, content: AnyView) {
        self.id = id
        self.title = title
        self.order = order
        self.content = content
    }
}

/// 主内容视图提供能力协议（对齐 Lumi `ProviderContentView/ContentViewProviding`）。
///
/// 定义「内核 → 主内容区」这一段的最小契约：宿主在启动时把插件贡献的
/// Tab 注入进来（`setTabs(_:)`），RootView 的内容区据此渲染。
///
/// 使用 `AnyView` 而非 `associatedtype`：协议可无泛型约束地作为存在类型
/// （`any ContentViewProviding`）注册进 `CisumKernel` 的 Provider 注册表。
@MainActor
public protocol ContentViewProviding: AnyObject, ObservableObject {
    /// 当前内容区 Tab 列表（按 `order` 升序）。
    var tabs: [ContentTabItem] { get }

    /// 设置内容区 Tab 列表（传空数组表示清空，回退到占位）。
    func setTabs(_ tabs: [ContentTabItem])

    /// 设置内容区的演示模式。演示模式是内容 Provider 的显式输入，
    /// 不通过 SwiftUI 环境向下查找。
    func setDemoMode(_ enabled: Bool)

    /// 返回当前主内容视图；未设置 Tab 时返回占位视图。
    func makeContentView() -> AnyView

    @discardableResult
    func addObserver(_ callback: @escaping (ContentViewProvidingEvent) -> Void) -> any ContentViewProvidingObserverHandle
}

public extension ContentViewProviding {
    func setDemoMode(_ enabled: Bool) {}

    @discardableResult
    func addObserver(_ callback: @escaping (ContentViewProvidingEvent) -> Void) -> any ContentViewProvidingObserverHandle {
        NoopContentViewProvidingObserverHandle()
    }
}

@MainActor
public final class NoopContentViewProvidingObserverHandle: ContentViewProvidingObserverHandle {
    public init() {}
    public func cancel() {}
}
