import Foundation
import MagicKit
import OSLog
import SwiftUI

actor AudioDownloadPlugin: SuperPlugin, SuperLog {
    static let emoji = "⬇️"
    static let verbose = true
    static var shouldRegister: Bool { true }

    /// 注册顺序设为 2，在 AudioPlugin (order: 1) 之后执行
    static var order: Int { 2 }

    let title = "音频下载管理"
    let description = "负责音频文件的自动下载"
    let iconName = "icloud.and.arrow.down"

    /// 只有当当前插件是音频插件时才提供下载管理
    @MainActor func addRootView<Content>(@ViewBuilder content: () -> Content) -> AnyView? where Content: View {
        AnyView(AudioDownloadRootView { content() })
    }
}

// MARK: Preview

#Preview("App") {
    ContentView()
        .inRootView()
        .withDebugBar()
}
