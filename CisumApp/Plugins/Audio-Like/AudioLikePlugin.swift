import Foundation
import MagicKit
import OSLog
import SwiftData
import SwiftUI

actor AudioLikePlugin: SuperPlugin, SuperLog {
    static let emoji = "❤️"
    static let verbose = false
    static var shouldRegister: Bool { true }
    static var order: Int { 3 }

    let title = "音频喜欢管理"
    let description = "负责音频喜欢状态的独立管理和存储"
    let iconName = "heart"

    /// 提供喜欢管理功能的根视图包装器
    @MainActor func addRootView<Content>(@ViewBuilder content: () -> Content) -> AnyView? where Content: View {
        AnyView(AudioLikeRootView { content() })
    }
}

// MARK: Preview

#Preview("App") {
    ContentView()
        .inRootView()
        .withDebugBar()
}
