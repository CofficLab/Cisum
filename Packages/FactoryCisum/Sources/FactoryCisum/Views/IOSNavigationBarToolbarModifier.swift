#if os(iOS)
import ProviderSettingsHost
import SwiftUI

/// 把 `IOSNavigationBarProviding` 的贡献项挂到 iOS 顶部导航栏。
///
/// ## 挂载位置
///
/// 必须挂在 `NavigationStack` **内部的内容**上（即栈的 `content` 闭包里），
/// 不能挂在 `NavigationStack` 自身之后：
///
/// - `NavigationStack { … }.toolbar { … }` —— 项被算到**外层**上下文，不会进入
///   这条栈自己的导航栏，表现为「贡献成功但看不见」；
/// - 挂在栈内内容上 —— 才会被这条栈接管，与栈内其它 `.toolbar` 落在同一条
///   导航栏上。
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
