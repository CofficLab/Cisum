#if os(iOS)
import ProviderSettingsHost
import SwiftUI

/// 把 `IOSNavigationBarProviding` 的贡献项挂到**导航栈级别**的 toolbar。
///
/// ## 为什么必须挂在栈级别
///
/// SwiftUI 的 `.toolbar` 只对**最近的导航容器**生效：挂在 `NavigationStack`
/// **外面**的 `.toolbar` 会被外层上下文接走（没有外层导航容器时直接不显示），
/// 挂在外面的视图也不会被传递进这条嵌套的导航栈。因此插件贡献的导航栏项
/// （设置齿轮等）必须由**导航栈的所有者**在栈内挂载。
///
/// 本 modifier 只负责「把项挂上去」，取值与变更转发由
/// `IOSNavigationBarItemsBridge` 负责（对齐 GameFactory/BookletMaker 的
/// `TrailingToolbarItemsModifier`）。
@MainActor
struct IOSNavigationBarToolbarModifier: ViewModifier {
    let items: [AnyView]

    func body(content: Content) -> some View {
        if items.isEmpty {
            content
        } else {
            content.toolbar {
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    ToolbarItem(placement: .topBarTrailing) {
                        item
                    }
                }
            }
        }
    }
}
#endif
