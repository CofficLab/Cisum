import Foundation
import MagicKit
import OSLog
import SwiftUI

actor BookProgressPlugin: SuperPlugin, SuperLog {
    static let emoji = "📖"
    static let verbose = true
    static var shouldRegister: Bool { true }

    /// 注册顺序设为 5，在 BookPlugin 之后执行
    static var order: Int { 5 }

    let title = "书籍进度管理"
    let description = "负责书籍播放进度的保存和恢复"
    let iconName = "book.closed"
    

    /// 提供进度管理功能的根视图包装器
    @MainActor func addRootView<Content>(@ViewBuilder content: () -> Content) -> AnyView? where Content: View {
        AnyView(BookProgressRootView { content() })
    }
}



// MARK: - Preview

#if os(macOS)
#Preview("App - Large") {
    ContentView()
    .inRootView()
        .frame(width: 600, height: 1000)
}

#Preview("App - Small") {
    ContentView()
    .inRootView()
        .frame(width: 600, height: 600)
}
#endif

#if os(iOS)
#Preview("iPhone") {
    ContentView()
    .inRootView()
}
#endif
