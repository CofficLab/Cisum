import Foundation
import MagicKit
import SwiftUI

actor AudioWidgetControlPlugin: SuperPlugin {
    nonisolated static let emoji = "🎛️"
    // 确保在应用启动早期加载
    nonisolated static let order = 100
    
    // MARK: - SuperPlugin Requirements

    nonisolated var id: String {
        "AudioWidgetControlPlugin"
    }

    nonisolated var label: String {
        "widgetControl"
    }

    nonisolated var title: String {
        "Widget 控制"
    }

    nonisolated var description: String {
        "响应小组件的播放控制命令"
    }

    nonisolated var iconName: String {
        "command"
    }

    nonisolated static var shouldRegister: Bool {
        true
    }

    // 将控制视图作为背景添加到根视图中，确保其始终存在且能响应通知
    @MainActor func addRootView<Content>(@ViewBuilder content: () -> Content) -> AnyView? where Content: View {
        AnyView(
            content()
                .background(AudioWidgetControlRootView())
        )
    }
}
