import Foundation
import MagicKit
import OSLog
import SwiftUI

actor AudioProgressPlugin: SuperPlugin, SuperLog {
    static let emoji = "💾"
    static let verbose = true
    static var shouldRegister: Bool { true }

    /// 注册顺序设为 0，确保在 AudioPlugin (order: 1) 之前执行
    /// 内核会按顺序应用插件，进度管理先于音频功能
    static var order: Int { 0 }

    let title = "音频进度管理"
    let description = "负责音频播放进度的保存和恢复"
    let iconName = "waveform"

    /// 只有当当前插件是音频插件时才提供进度管理
    @MainActor func addRootView<Content>(@ViewBuilder content: () -> Content) -> AnyView? where Content: View {
        AnyView(AudioProgressRootView { content() })
    }
}

// MARK: - Preview

#Preview("App - Large") {
    ContentView()
        .inRootView()
        .withDebugBar()
}
