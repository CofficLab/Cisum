import Foundation
import MagicKit
import OSLog
import SwiftUI

actor AudioPlayModePlugin: SuperPlugin {
    static var shouldRegister: Bool { true }

    let title = "音频播放模式管理"
    let description = "负责音频播放模式的设置和管理"
    let iconName = "repeat"

    /// 提供播放模式管理功能的根视图包装器
    @MainActor func addRootView<Content>(@ViewBuilder content: () -> Content) -> AnyView? where Content: View {
        AnyView(AudioPlayModeRootView { content() })
    }
}

// MARK: Preview

#Preview("App") {
    ContentView()
        .inRootView()
        .withDebugBar()
}
