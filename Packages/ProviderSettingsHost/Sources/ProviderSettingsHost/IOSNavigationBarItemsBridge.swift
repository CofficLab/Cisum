import Combine
import ProviderToolbar
import SwiftUI

#if os(iOS)
/// iOS 导航栏贡献项的桥接器：把 `IOSNavigationBarProviding` 的可见项转成
/// 可直接挂到导航栈上的 `[AnyView]`。
///
/// 背景：SwiftUI **不会**把**外层**的 `.toolbar` 传递进嵌套的
/// `NavigationStack` —— 业务根视图自己创建的导航栈会另起一套工具栏上下文。
/// 因此宿主 App 想让插件贡献的导航栏项（设置齿轮等）出现在自己那条系统
/// 导航栏上，必须由导航栈的所有者（App 或业务根视图）在**栈级别**挂载。
///
/// 本类型只负责「取值 + 变更转发」，挂载位置由宿主决定。
///
/// ```swift
/// let bridge = IOSNavigationBarItemsBridge(provider: navigationBar)
/// BookletMakerMobileRootView(
///     feature: feature,
///     trailingToolbarItems: bridge.items
/// )
/// ```
@MainActor
public final class IOSNavigationBarItemsBridge: ObservableObject {
    private let provider: any IOSNavigationBarProviding
    private var observation: AnyCancellable?

    public init(provider: any IOSNavigationBarProviding) {
        self.provider = provider
        observation = provider.objectWillChange.sink { [weak self] _ in
            // 只转发变更信号：真正的取值发生在宿主渲染时（此时 provider
            // 的新值已经生效），避免在 `objectWillChange` 阶段读到旧值。
            self?.objectWillChange.send()
        }
    }

    /// 当前可见的导航栏项，按 `order` 升序（相同 order 时按 id 稳定排序）。
    public var items: [AnyView] {
        provider.visibleNavigationBarItems
            .sorted { lhs, rhs in
                lhs.order == rhs.order ? lhs.id < rhs.id : lhs.order < rhs.order
            }
            .map { $0.makeView() }
    }
}
#endif
